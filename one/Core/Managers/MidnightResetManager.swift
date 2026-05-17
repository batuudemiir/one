//
//  MidnightResetManager.swift
//  one
//
//  Manages midnight reset of Circle photo sharing
//

import Foundation
import CoreData
import BackgroundTasks
import Combine

class MidnightResetManager {
    static let shared = MidnightResetManager()
    
    private let taskIdentifier = "com.batu.ones.midnightReset"
    
    private init() {}
    
    // MARK: - Background Task Registration
    
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleMidnightReset(task: refreshTask)
        }
    }
    
    // MARK: - Schedule Next Reset
    
    func scheduleMidnightReset() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        
        // Calculate next midnight
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let now = Date()
        if let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now)!) {
            request.earliestBeginDate = midnight
            
            do {
                try BGTaskScheduler.shared.submit(request)
                ONELogger.success("Midnight reset scheduled for: \(midnight)", category: .calendar)
            } catch let error as NSError {
                // Error code 1 = BGTaskSchedulerErrorCodeUnavailable (simulator or not configured)
                if error.code == 1 {
                    ONELogger.info("Background tasks unavailable (simulator or not configured)", category: .calendar)
                } else {
                    ONELogger.error("Failed to schedule midnight reset: \(error)", category: .calendar)
                }
            }
        }
    }
    
    // MARK: - Handle Reset

    private func handleMidnightReset(task: BGAppRefreshTask) {
        // Schedule next reset
        scheduleMidnightReset()

        // Perform reset
        let context = PersistenceController.shared.container.newBackgroundContext()

        task.expirationHandler = {
            context.reset()
        }

        context.perform {
            self.resetExpiredShares(context: context)
            self.scheduleStreakNotificationsIfNeeded()

            // Ayın son günüyse ay-sonu özet bildirimi planla
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            if let lastDayOfMonth = cal.date(
                byAdding: .day, value: -1,
                to: cal.date(byAdding: .month, value: 1,
                             to: cal.date(from: cal.dateComponents([.year, .month], from: today))!)!
            ), cal.isDate(today, inSameDayAs: lastDayOfMonth) {
                NotificationManager.shared.scheduleMonthEndNotification()
            }

            // Subscription sağlamlık kontrolü — Apple belirli koşullarda CKSubscription'ları
            // silebiliyor; gece yarısı sıfırlamasında eksik olanları yeniden kayıt et.
            CloudKitManager.shared.verifySubscriptions()

            // Lock Screen widget'ı günlük sıfırla (yeni gün = yeni seçim)
            WidgetDataWriter.clear()

            // Gece yarısında tüm Live Activity'leri kapat
            if #available(iOS 16.1, *) {
                Task {
                    await LiveActivityManager.shared.endAllActivities()
                }
            }

            do {
                try context.save()
                task.setTaskCompleted(success: true)
                ONELogger.success("Midnight reset completed successfully", category: .calendar)
            } catch {
                ONELogger.error("Midnight reset failed: \(error)", category: .calendar)
                task.setTaskCompleted(success: false)
            }

            // Cache invalidation main thread'de — property mutation thread safety için
            DispatchQueue.main.async {
                CloudKitManager.shared.invalidateCircleCache()
                CloudKitManager.shared.invalidateWeeklyCircleCache()
            }
        }
    }

    // MARK: - Streak & Discovery Notifications

    private func scheduleStreakNotificationsIfNeeded() {
        let context  = PersistenceController.shared.container.viewContext
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayEntry     = PersistenceController.shared.fetchDailySong(for: today, context: context)
        let yesterdayEntry = PersistenceController.shared.fetchDailySong(for: yesterday, context: context)

        if todayEntry == nil, yesterdayEntry != nil {
            // Streak tehlikede — ardışık gün sayısını hesapla
            let streak = calculateStreakCount(context: context, upTo: yesterday)
            if streak > 1 {
                NotificationManager.shared.scheduleStreakWarning(streakDays: streak)
            }
        } else {
            NotificationManager.shared.cancelStreakWarning()
        }

        // Milestone kutlama — bugün kayıt yapıldıysa güncel streak'i hesapla.
        if todayEntry != nil {
            let currentStreak = calculateStreakCount(context: context, upTo: today)
            StreakMilestoneScheduler.evaluate(streak: currentStreak)
        }

        NotificationOrchestrator.shared.onMidnight()
    }

    private func calculateStreakCount(context: NSManagedObjectContext, upTo date: Date) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDay = calendar.startOfDay(for: date)
        while true {
            guard PersistenceController.shared.fetchDailySong(for: checkDay, context: context) != nil else { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }
        return streak
    }
    
    // MARK: - Reset Logic
    
    func resetExpiredShares(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<DailySong> = DailySong.fetchRequest()
        
        // Find all songs with active sharing that have expired
        let now = Date()
        fetchRequest.predicate = NSPredicate(
            format: "isSharedWithCircle == YES AND shareExpiresAt != nil AND shareExpiresAt <= %@",
            now as NSDate
        )
        
        do {
            let expiredSongs = try context.fetch(fetchRequest)
            
            for song in expiredSongs {
                // Reset sharing status (keep photo)
                song.isSharedWithCircle = false
                song.shareExpiresAt = nil
                
                ONELogger.debug("Reset sharing for song: \(song.songName ?? "Unknown") on \(song.date ?? Date())", category: .calendar)
            }
            
            ONELogger.success("Reset \(expiredSongs.count) expired shares", category: .calendar)
            
        } catch {
            ONELogger.error("Error fetching expired shares: \(error)", category: .calendar)
        }
    }
    
    // MARK: - Manual Reset (for testing)
    
    func manualReset() {
        let context = PersistenceController.shared.container.viewContext
        resetExpiredShares(context: context)
        
        do {
            try context.save()
            ONELogger.success("Manual reset completed", category: .calendar)
        } catch {
            ONELogger.error("Manual reset failed: \(error)", category: .calendar)
        }
    }
}
