//
//  MomentWriter.swift
//  one
//
//  Bir "an"ı diske yazan **tek** yol.
//
//  Kayıt yalnızca Core Data satırı değil: analitik, bildirim yeniden
//  planlama, widget verisi ve Echo önbelleği aynı anda güncellenmeli.
//  Bu iş `TodayViewModel.saveV3Entry` içinde gömülüydü ve o metot
//  `@MainActor` bir ViewModel'e bağlı — App Intents (Siri, kısayol,
//  Control Center) uygulamayı hiç açmadan kaydedebilmeli, elinde ViewModel
//  yok.
//
//  Mantığı buraya taşıdım. `saveV3Entry` artık buraya delege ediyor ve
//  üstüne yalnız kendi published state'ini tazeliyor. Böylece iki yazma
//  yolu değil, tek yol var — yan etkilerden biri unutulamaz.
//

import UIKit
import CoreData

enum MomentWriter {

    /// Bir v3 anı yazar — şarkılı ya da şarkısız, bugüne ya da geçmiş bir güne.
    ///
    /// Şarkılı kayıt eskiden legacy `saveEntry`'ye dallanıyordu ve o yol iki
    /// şeyi bozuyordu: **upsert** semantiği günün diğer anlarını eziyordu, ve
    /// `entryDate` parametresi hiç okunmadığı için Arşiv'den geçmiş bir güne
    /// eklenen şarkılı an **bugüne** yazılıyordu. Şarkı artık burada, çok-an
    /// yolunun içinde.
    ///
    /// - Returns: yazma başarılıysa `true`.
    @discardableResult
    static func write(
        mood: V3Mood,
        note: String = "",
        photo: UIImage? = nil,
        song: SongResult? = nil,
        scope: MomentScope = .private,
        entryDate: Date? = nil,
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let normalized = calendar.startOfDay(for: entryDate ?? Date())
        /// Geçmiş bir güne yazıyor muyuz? Yan etkilerin bir kısmı "bugün"
        /// kavramına bağlı (widget, bildirim planı, Echo önbelleği) ve geçmiş
        /// gün için yanlış olur — 3 gün önceki renk bugünün widget'ına düşemez.
        let isBackfill = normalized < today
        let photoData = photo.flatMap(ONEPhotoEncoder.encode)

        let item = PersistenceController.shared.insertNewMoment(
            for: normalized,
            moodColorHex: mood.hex,
            moodWord: mood.label.lowercased(),
            note: note,
            songName: song?.name,
            songArtist: song?.artist,
            photoData: photoData,
            scope: scope,
            context: context
        )
        // Şarkı yoksa placeholder — eski ekranlar boş göstermek yerine bunları okur.
        item.songName   = song?.name ?? ""
        item.artistName = song?.artist ?? ""
        item.genre      = song?.genre ?? ""
        item.emoji      = "🎵"
        item.moodLabel  = mood.label.lowercased()
        // "Apple Music" yazımı legacy `saveEntry` ile birebir aynı olmalı —
        // arşiv ve Echo bu string'e göre kaynak ayırıyor.
        item.platform   = song == nil ? "None" : "Apple Music"
        if let song {
            item.artworkURL = song.artworkURLString
            item.spotifyURL = song.spotifyURL?.absoluteString
        }

        do {
            try context.save()
        } catch {
            ErrorHandler.shared.handle(error, context: "MomentWriter.write")
            return false
        }

        applySideEffects(mood: mood, note: note, song: song, isBackfill: isBackfill)
        if isBackfill {
            let daysAgo = calendar.dateComponents([.day], from: normalized, to: today).day ?? 0
            AppAnalytics.shared.track(.entryBackfilled(daysAgo: daysAgo))
        }
        return true
    }

    /// Kaydın diske inmesi dışındaki her şey.
    ///
    /// Ayrı tutuluyor çünkü sırası önemli: analitik önce (kullanıcı niyeti),
    /// bildirim sonra (bugün kayıt var → bugünün hatırlatması iptal), widget
    /// en sonda (okuyacağı veri artık yerinde).
    ///
    /// `isBackfill` olduğunda **yalnız analitik** çalışır. Geriye kalan her şey
    /// "bugün" kavramına bağlı: geçmiş bir günün rengi bugünün widget'ına
    /// düşemez, bugünün hatırlatmasını iptal edemez ve Echo önbelleğini
    /// ezemez. Bu ayrımı silinen legacy `backfillEntry` de yapıyordu — telafi
    /// girişi sessiz olmalı.
    private static func applySideEffects(
        mood: V3Mood,
        note: String,
        song: SongResult?,
        isBackfill: Bool
    ) {
        // v3 mood'unun **kendi** rawValue'su gönderiliyor.
        //
        // Eskiden `bridgedMood.rawValue` idi, yani legacy 12-mood uzayı. Köprü
        // kayıplı olduğu için analitik yanlış ölçüyordu: "coşkulu" seçen
        // kullanıcı `nostaljik`, "odaklı" seçen `derin` olarak kaydediliyordu.
        // Dokuz duygu artık kendi adıyla raporlanıyor.
        //
        // NOT: Bu bir taksonomi değişikliği — geçmiş kayıtlar eski adlarıyla
        // duruyor, dashboard'da iki dönem yan yana görünecek.
        AppAnalytics.shared.track(.moodSelected(mood: mood.rawValue))
        if !note.isEmpty {
            AppAnalytics.shared.track(.noteAdded(length: note.count))
        }

        // Buradan aşağısı "bugün"e yazıyor — geçmiş gün girişinde atlanır.
        guard !isBackfill else {
            // Arşivin kendini tazelemesi için sinyal yine de gitmeli.
            NotificationCenter.default.post(name: .init("todaySongSaved"), object: nil)
            return
        }

        TodayViewModel.writeCachedEchoMood(hex: mood.hex, label: mood.label.lowercased())

        NotificationOrchestrator.shared.onSongSaved(
            moodLabel: mood.label.lowercased(),
            moodColorHex: mood.hex
        )
        V3ReminderScheduler.reschedule(yesterdayMood: mood)

        WidgetDataWriter.writeTodayEntry(
            songName: song?.name ?? "",
            artistName: song?.artist ?? "",
            moodLabel: mood.label.lowercased(),
            moodColorHex: mood.hex,
            note: note.isEmpty ? nil : note,
            entryCount: 1
        )

        NotificationCenter.default.post(name: .init("todaySongSaved"), object: nil)
    }
}
