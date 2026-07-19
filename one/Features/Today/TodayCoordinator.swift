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
    weak var vm: TodayViewModel?

    init(vm: TodayViewModel? = nil) {
        self.vm = vm
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
        vm.saveRitualEntry(draft: draft)
    }
}
