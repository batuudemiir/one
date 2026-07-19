//
//  TodayCoordinator.swift
//  one
//

import SwiftUI
import Combine

// MARK: - DraftEntry

struct DraftEntry {
    var song: SongResult?
    /// Foto ve not artık ritüelin parçası değil — kaydettikten sonra
    /// `TodayViewModel.attachPhotoAndNote` ile opsiyonel olarak ekleniyor.
    /// Alanlar duruyor çünkü `saveEntry` imzası bunları taşıyor.
    var photoData: Data?
    var mood: ONEMood?
    var feeling: String = ""
    /// Varsayılan açık: sosyal katman retention'ı taşıyor (Solo D30 %0),
    /// opt-in'e bağlı bırakılamaz.
    var shareToCircle: Bool = true
    var createdAt: Date = Date()
}

// MARK: - RitualStep

/// İki zorunlu adım. Sıra önemli: mood önce (ekranın sorusu bu), şarkı son.
/// Şarkı en yüksek rawValue olduğu için `next()` oradan otomatik `commit()` eder.
enum RitualStep: Int, CaseIterable {
    case mood = 0, song = 1
}

final class TodayCoordinator: ObservableObject {
    @Published var step: RitualStep = .mood
    @Published var draft = DraftEntry()
    /// Faz 3 — ritüel geçmiş bir günü telafi etmek için açıldıysa o gün.
    /// nil = normal "bugün" akışı.
    @Published var backfillDate: Date? = nil
    weak var vm: TodayViewModel?

    var isBackfill: Bool { backfillDate != nil }

    init(vm: TodayViewModel? = nil) {
        self.vm = vm
    }

    /// Ritüeli geçmiş bir gün için baştan başlatır.
    func startBackfill(for date: Date) {
        draft = DraftEntry()
        backfillDate = date
        step = .mood
    }

    /// Telafi modundan çıkar, normal bugün akışına döner.
    func cancelBackfill() {
        draft = DraftEntry()
        backfillDate = nil
        step = .mood
    }

    func next() {
        guard let nextStep = RitualStep(rawValue: step.rawValue + 1) else {
            commit()
            return
        }
        ONEHaptics.feelingSelected()
        withAnimation(.easeOut(duration: 0.22)) { step = nextStep }
    }

    func back() {
        guard let prevStep = RitualStep(rawValue: step.rawValue - 1) else { return }
        ONEHaptics.feelingSelected()
        withAnimation(.easeOut(duration: 0.18)) { step = prevStep }
    }

    func jumpTo(_ target: RitualStep) {
        ONEHaptics.feelingSelected()
        withAnimation(.easeOut(duration: 0.2)) { step = target }
    }

    func commit() {
        guard let vm else { return }
        ONEHaptics.songSaved()
        SongPreviewPlayer.shared.stop()

        if let date = backfillDate {
            guard let song = draft.song, let mood = draft.mood else { return }
            let moodOption = MoodOption.all.first { $0.key == mood.rawValue } ?? MoodOption.all[4]
            vm.backfillEntry(song: song, mood: moodOption, on: date, note: draft.feeling)
            cancelBackfill()
            return
        }

        vm.saveRitualEntry(draft: draft)
    }
}
