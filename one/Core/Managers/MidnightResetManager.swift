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

        // BGAppRefreshTask sistem tarafından cold-start ile de çağrılabiliyor;
        // o durumda `loadPersistentStores` henüz uçuşta olabilir ve fetch'ler
        // boş dönerdi. isReady'yi bekle, sonra normal işi başlat.
        Task { @MainActor in
            for await ready in PersistenceController.shared.$isReady.values where ready {
                break
            }
            self.runReset(task: task, context: context)
        }
    }

    private func runReset(task: BGAppRefreshTask, context: NSManagedObjectContext) {
        context.perform {
            self.resetExpiredShares(context: context)

            // v4: ay-sonu push'u kaldırıldı. Aylık portrenin tek sahibi
            // `MonthlyPortraitScheduler` (ayın 1'i 11:00) — ayın son günü
            // 20:00'de ikinci bir bildirim aynı şeyi iki kez duyuruyordu.

            // Subscription sağlamlık kontrolü — Apple belirli koşullarda CKSubscription'ları
            // silebiliyor; gece yarısı sıfırlamasında eksik olanları yeniden kayıt et.
            CloudKitManager.shared.verifySubscriptions()

            // Lock Screen widget'ı günlük sıfırla (yeni gün = yeni seçim)
            WidgetDataWriter.clear()

            // Günlük şarkı önerisi cache'ini temizle — sabah taze öneriler yüklensin
            UserDefaults.standard.removeObject(forKey: "recommendedSongsCache_v1")
            UserDefaults.standard.removeObject(forKey: "recommendedSongsCacheDate_v1")

            // Gece yarısında tüm Live Activity'leri kapat
            if #available(iOS 16.1, *) {
                Task {
                    await LiveActivityManager.shared.endAllActivities()
                }
            }

            let saved: Bool
            do {
                try context.save()
                saved = true
                ONELogger.success("Midnight reset completed successfully", category: .calendar)
            } catch {
                saved = false
                ONELogger.error("Midnight reset failed: \(error)", category: .calendar)
            }

            // Buradan sonrası ana aktörde.
            //
            // `setTaskCompleted` buraya indi: BGTask tamamlandı denince
            // sistem uygulamayı askıya alabiliyor. Bildirim planlaması ondan
            // sonraya kalsaydı hiç kurulmayabilirdi.
            //
            // Cache invalidation zaten main gerektiriyordu (property mutation).
            Task { @MainActor in
                NotificationOrchestrator.shared.onMidnight()
                CloudKitManager.shared.invalidateCircleCache()
                CloudKitManager.shared.invalidateWeeklyCircleCache()
                task.setTaskCompleted(success: saved)
            }
        }
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
