//
//  ONEAppShortcuts.swift
//  one
//
//  Siri fraze'leri ve Kısayollar galerisi girdileri.
//
//  `AppShortcutsProvider` uygulamayı kurulduğu anda Kısayollar'da
//  görünür kılıyor — kullanıcının hiçbir şey ayarlaması gerekmiyor.
//  Fraze'ler `${applicationName}` içermek zorunda; Siri uygulamayı bu
//  sözcükten tanıyor.
//
//  Not: fraze'ler `AppShortcutPhrase` içinde **derleme zamanında** sabit
//  olmak zorunda, `NSLocalizedString` çalışmıyor. Yerelleştirme için
//  `AppShortcuts.strings` kullanılıyor (Localizable.strings değil).
//

import AppIntents

@available(iOS 16.0, *)
struct ONEAppShortcuts: AppShortcutsProvider {

    /// Kısayollar galerisindeki kutu rengi — marka vurgusu `kor`a en yakın
    /// sistem tonu.
    static var shortcutTileColor: ShortcutTileColor { .orange }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveMomentIntent(),
            phrases: [
                "\(.applicationName) ile an kaydet",
                "\(.applicationName) bugün nasılım",
                "Save a moment in \(.applicationName)"
            ],
            shortTitle: "An kaydet",
            systemImageName: "circle.dotted"
        )

        AppShortcut(
            intent: OpenMomentEntryIntent(),
            phrases: [
                "\(.applicationName) aç ve renk seç",
                "New moment in \(.applicationName)"
            ],
            shortTitle: "Yeni an",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: TodayMoodQueryIntent(),
            phrases: [
                "\(.applicationName) bugün ne hissettim",
                "What did I feel today in \(.applicationName)"
            ],
            shortTitle: "Bugünü sor",
            systemImageName: "square.grid.3x3"
        )
    }
}
