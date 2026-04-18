//
//  CalendarManager.swift
//  one
//
//  Created for Calendar Integration
//

import Foundation
import EventKit
import SwiftUI
import Combine

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            isAuthorized = (status == .fullAccess)
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            isAuthorized = (status == .authorized)
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
                return granted
            }
        } catch {
            ONELogger.debug("Calendar access error: \(error)", category: .calendar)
            return false
        }
    }
    
    // MARK: - Event Management
    
    func createDailySongEvent(
        date: Date,
        songName: String,
        artistName: String,
        moodWord: String,
        note: String?
    ) async -> Bool {
        guard isAuthorized else {
            ONELogger.debug("Calendar not authorized", category: .calendar)
            return false
        }
        
        // Check if event already exists for this date
        if await eventExistsForDate(date) {
            ONELogger.debug("Event already exists for this date", category: .calendar)
            return await updateDailySongEvent(date: date, songName: songName, artistName: artistName, moodWord: moodWord, note: note)
        }
        
        let event = EKEvent(eventStore: eventStore)
        
        // Set event details
        event.title = "🎵 \(songName)"
        let noteLine = (note?.isEmpty == false) ? "\nNot: \(note ?? "")" : ""
        event.notes = """
        Sanatçı: \(artistName)
        Ruh Hali: \(moodWord)
        \(noteLine)

        ONE ile kaydedildi
        """

        // Set all-day event for the selected date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        event.startDate = startOfDay
        event.endDate = endOfDay
        event.isAllDay = true
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            ONELogger.debug("Calendar event created successfully", category: .calendar)
            return true
        } catch {
            ONELogger.debug("Error saving calendar event: \(error)", category: .calendar)
            return false
        }
    }
    
    func updateDailySongEvent(
        date: Date,
        songName: String,
        artistName: String,
        moodWord: String,
        note: String?
    ) async -> Bool {
        guard isAuthorized else { return false }
        
        guard let event = await getEventForDate(date) else {
            return await createDailySongEvent(date: date, songName: songName, artistName: artistName, moodWord: moodWord, note: note)
        }
        
        event.title = "🎵 \(songName)"
        let noteLine = (note?.isEmpty == false) ? "\nNot: \(note ?? "")" : ""
        event.notes = """
        Sanatçı: \(artistName)
        Ruh Hali: \(moodWord)
        \(noteLine)

        ONE ile kaydedildi
        """
        
        do {
            try eventStore.save(event, span: .thisEvent)
            ONELogger.debug("Calendar event updated successfully", category: .calendar)
            return true
        } catch {
            ONELogger.debug("Error updating calendar event: \(error)", category: .calendar)
            return false
        }
    }
    
    func deleteDailySongEvent(date: Date) async -> Bool {
        guard isAuthorized else { return false }
        
        guard let event = await getEventForDate(date) else {
            ONELogger.debug("No event found for this date", category: .calendar)
            return false
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            ONELogger.debug("Calendar event deleted successfully", category: .calendar)
            return true
        } catch {
            ONELogger.debug("Error deleting calendar event: \(error)", category: .calendar)
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func eventExistsForDate(_ date: Date) async -> Bool {
        return await getEventForDate(date) != nil
    }
    
    private func getEventForDate(_ date: Date) async -> EKEvent? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Find event created by ONE app
        return events.first { event in
            event.title.hasPrefix("🎵") && event.notes?.contains("ONE ile kaydedildi") == true
        }
    }
    
    func getDailySongEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.filter { event in
            event.title.hasPrefix("🎵") && event.notes?.contains("ONE ile kaydedildi") == true
        }
    }
}
