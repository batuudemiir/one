//
//  SaveMomentIntent.swift
//  one
//
//  "Bir renk seç" eylemini uygulamanın dışına taşıyan intent'ler.
//
//  ONE'ın çekirdek eylemi tek adımlık: bir duygu seç, kaydedildi. Bu, App
//  Intents için neredeyse ideal bir şekil — kullanıcı uygulamayı hiç
//  açmadan Siri'ye, Kısayollar'a, Kilit Ekranı'na veya Aksiyon Düğmesi'ne
//  bağlayabiliyor.
//
//  Kayıt `MomentWriter` üzerinden gidiyor: uygulamadan kaydetmekle buradan
//  kaydetmek arasında hiçbir fark yok — aynı analitik, aynı bildirim
//  yeniden planlaması, aynı widget tazelemesi.
//

import AppIntents
import SwiftUI
import CoreData

// MARK: - Duygu kaydet

@available(iOS 16.0, *)
struct SaveMomentIntent: AppIntent {

    static var title: LocalizedStringResource = "An kaydet"

    static var description = IntentDescription(
        "Seçtiğin duyguyu bugünün arşivine ekler.",
        categoryName: "An"
    )

    /// Uygulamayı açmadan çalışır — asıl kazanç bu. Kullanıcı Siri'ye
    /// söylüyor, an kaydediliyor, ekran hiç değişmiyor.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Duygu")
    var mood: V3Mood

    /// Opsiyonel not. Kısayol kurarken boş bırakılabilir; Siri sormaz.
    @Parameter(title: "Not", default: "")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$mood) olarak kaydet") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ok = MomentWriter.write(mood: mood, note: note)
        guard ok else {
            throw MomentIntentError.saveFailed
        }
        ONEHaptics.songSaved()
        return .result(
            dialog: IntentDialog("Kaydedildi.")
        )
    }
}

// MARK: - An akışını aç

@available(iOS 16.0, *)
struct OpenMomentEntryIntent: AppIntent {

    static var title: LocalizedStringResource = "Yeni an ekle"

    static var description = IntentDescription(
        "ONE'ı açar ve renk seçimiyle başlar.",
        categoryName: "An"
    )

    /// Bu intent bilinçli olarak uygulamayı açıyor: kullanıcı burada
    /// duyguyu henüz seçmemiş, seçim ekranı gerekiyor.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Kabuk bu bildirimi zaten dinliyor (deep link ve widget yolu ile
        // aynı) — intent için ayrı bir yönlendirme mekanizması eklemiyoruz.
        LaunchIntent.shared.setPendingMoodPickerRequest()
        NotificationCenter.default.post(name: .init("switchToTodayTab"), object: nil)
        return .result()
    }
}

// MARK: - Bugünü sor

@available(iOS 16.0, *)
struct TodayMoodQueryIntent: AppIntent {

    static var title: LocalizedStringResource = "Bugün ne hissettim?"

    static var description = IntentDescription(
        "Bugün kaydettiğin anları özetler.",
        categoryName: "Arşiv"
    )

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let today = Calendar.current.startOfDay(for: Date())
        let moments = PersistenceController.shared.fetchMoments(
            for: today,
            context: PersistenceController.shared.container.viewContext
        )

        guard !moments.isEmpty else {
            return .result(dialog: IntentDialog("Bugün için henüz bir an yok."))
        }

        let labels = moments
            .compactMap { V3Mood.fromHex($0.moodColorHex)?.label.lowercased() }
        guard !labels.isEmpty else {
            return .result(dialog: IntentDialog("Bugün \(moments.count) an var."))
        }

        // "huzurlu, odaklı ve enerjik" — son bağlaç dile göre değişmesin diye
        // katalogdan gelen bir birleştirici kullanmıyoruz; virgül yeterli ve
        // Siri bunu doğal okuyor.
        let summary = labels.joined(separator: ", ")
        return .result(dialog: IntentDialog("Bugün: \(summary)."))
    }
}

// MARK: - Hata

@available(iOS 16.0, *)
enum MomentIntentError: Error, CustomLocalizedStringResourceConvertible {
    case saveFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .saveFailed:
            return "An kaydedilemedi."
        }
    }
}
