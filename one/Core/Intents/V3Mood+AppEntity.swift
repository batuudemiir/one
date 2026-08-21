//
//  V3Mood+AppEntity.swift
//  one
//
//  `V3Mood`'un App Intents karşılığı.
//
//  Siri ve Kısayollar'ın bir duyguyu parametre olarak sunabilmesi için
//  `AppEnum` gerekiyor. Etiketler doğrudan mevcut lokalizasyon
//  katalogundan (`mood.v3.<case>.label`) geliyor — dokuz duygu zaten
//  dokuz dile çevrili, kısayol arayüzü de aynı çeviriyi kullanıyor.
//

import AppIntents

// `nonisolated` zorunlu: hedefte `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
// açık, yani bu extension'ın uyumu da varsayılan olarak main actor'a izole
// olurdu. `AppEnum` ise `Sendable` bir `Self` istiyor — Siri ve Kısayollar
// bu tipi kendi süreçlerinden, main actor dışından okuyor.
@available(iOS 16.0, *)
nonisolated extension V3Mood: AppEnum {

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("intent.mood.type", defaultValue: "Duygu")
        )
    }

    /// Her case'in görünen adı yine katalogdan (`mood.v3.<case>.label`) —
    /// kodda ikinci bir Türkçe kopya yok, dokuz dil aynı anahtarı okuyor.
    ///
    /// Neden döngü değil de düz sözlük: `appintentsmetadataprocessor` bu
    /// değeri **derleme zamanında** okuyup metadata'ya gömüyor. Hesaplanan
    /// ya da dinamik bir gövde ("must be static, have a compile-time
    /// constant value") kabul edilmiyor ve tüm hedef AppIntents'e kapanıyor.
    /// Anahtarların literal olması da aynı sebeple zorunlu — interpolasyon
    /// çıkarıcı tarafından çözülemiyor.
    static let caseDisplayRepresentations: [V3Mood: DisplayRepresentation] = [
        .atesli:  DisplayRepresentation(title: LocalizedStringResource("mood.v3.atesli.label")),
        .coskulu: DisplayRepresentation(title: LocalizedStringResource("mood.v3.coskulu.label")),
        .gergin:  DisplayRepresentation(title: LocalizedStringResource("mood.v3.gergin.label")),
        .mutlu:   DisplayRepresentation(title: LocalizedStringResource("mood.v3.mutlu.label")),
        .enerjik: DisplayRepresentation(title: LocalizedStringResource("mood.v3.enerjik.label")),
        .odakli:  DisplayRepresentation(title: LocalizedStringResource("mood.v3.odakli.label")),
        .huzurlu: DisplayRepresentation(title: LocalizedStringResource("mood.v3.huzurlu.label")),
        .huzunlu: DisplayRepresentation(title: LocalizedStringResource("mood.v3.huzunlu.label")),
        .yorgun:  DisplayRepresentation(title: LocalizedStringResource("mood.v3.yorgun.label"))
    ]
}
