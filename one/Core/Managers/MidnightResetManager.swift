//
//  MidnightResetManager.swift
//  one
//
//  Manages midnight reset of Circle photo sharing
//

import Foundation
import CoreData
import BackgroundTasks

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
            // Clean up if task expires
            context.reset()
        }
        
        context.perform {
            self.resetExpiredShares(context: context)
            
            do {
                try context.save()
                task.setTaskCompleted(success: true)
                ONELogger.success("Midnight reset completed successfully", category: .calendar)
            } catch {
                ONELogger.error("Midnight reset failed: \(error)", category: .calendar)
                task.setTaskCompleted(success: false)
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
