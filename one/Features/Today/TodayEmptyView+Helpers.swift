//
//  TodayEmptyView+Helpers.swift
//  one
//
//  Helpers extracted from TodayEmptyView in Faz 3.1 (2026-04-26):
//  - timeGreetingText (greeting by hour)
//  - reveal (animate + scroll to section)
//  - selectSong, resetAll (state mutations)
//

import SwiftUI

extension TodayEmptyView {

    // MARK: - Helpers

    var timeGreetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<10:  return NSLocalizedString("today.morningGreeting", comment: "")
        case 10..<14: return NSLocalizedString("today.midDayGreeting", comment: "")
        case 14..<19: return NSLocalizedString("today.afternoonGreeting", comment: "")
        case 19..<23: return NSLocalizedString("today.eveningGreeting", comment: "")
        default:      return NSLocalizedString("today.nightGreeting", comment: "")
        }
    }

    /// Bölümü aç ve scroll yap
    func reveal(_ id: String, proxy: ScrollViewProxy, action: @escaping () -> Void) {
        withAnimation(ONEAnimation.panelSpring) { action() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    func selectSong(_ song: SongResult) {
        ONEHaptics.feelingSelected()
        withAnimation(ONEAnimation.panelSpring) {
            selectedSong = song
            searchText   = ""
            vm.searchResults = []
            currentStep  = .selecting
        }
        withAnimation(ONEAnimation.panelSpring.delay(0.2)) {
            showPhotoRow = true
        }
    }

    func resetAll() {
        ONEHaptics.moodSelected()
        withAnimation(ONEAnimation.panelSpring) {
            selectedSong    = nil
            selectedMood    = nil
            photoImage      = nil
            dailyNote       = ""
            sharePhoto      = false
            searchText      = ""
            showPhotoRow    = false
            showMoodSection    = false
            showNoteSection    = false
            showSaveButton     = false
            currentStep     = .search
            photoZoomScale     = 1.0
            photoLastZoomScale = 1.0
            photoDismissOffset = 0
            photoPanOffset     = .zero
            photoLastPanOffset = .zero
        }
    }
}
