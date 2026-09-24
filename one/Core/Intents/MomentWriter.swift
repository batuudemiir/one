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

    /// Bir v3 anı yazar — şarkılı ya da şarkısız. **Her zaman bugüne.**
    ///
    /// `entryDate` parametresi vardı ve Arşiv'den geçmiş bir güne yazmayı
    /// mümkün kılıyordu. Duruş ilke 3 gereği kaldırıldı: boşluk kalıcıdır,
    /// arşiv doğru olduğu için değerli, tamamlandığı için değil. Yazma yolunda
    /// tarih parametresi bulunması, ileride bir çağrı yerinin geriye dönük
    /// girişi sessizce geri getirmesi demekti.
    ///
    /// - Returns: yazma başarılıysa `true`.
    @discardableResult
    static func write(
        mood: V3Mood,
        note: String = "",
        photo: UIImage? = nil,
        song: SongResult? = nil,
        scope: MomentScope = .private,
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) -> Bool {
        let calendar = Calendar.current
        let normalized = calendar.startOfDay(for: Date())
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

        applySideEffects(mood: mood, note: note, context: context)
        return true
    }

    /// Kaydın diske inmesi dışındaki her şey.
    ///
    /// Ayrı tutuluyor çünkü sırası önemli: analitik önce (kullanıcı niyeti),
    /// bildirim sonra (bugün kayıt var → bugünün hatırlatması iptal), widget
    /// en sonda (okuyacağı veri artık yerinde).
    ///
    /// `song` parametresi kalktı: tek kullanıcısı elle yazılan widget
    /// çağrısıydı, o da `refreshTodaySurfaces`'a taşındı — orası şarkıyı
    /// diskten okuyor.
    ///
    private static func applySideEffects(
        mood: V3Mood,
        note: String,
        context: NSManagedObjectContext
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

        NotificationOrchestrator.shared.onSongSaved(
            moodLabel: mood.label.lowercased(),
            moodColorHex: mood.hex
        )
        V3ReminderScheduler.reschedule(yesterdayMood: mood)

        // Widget, Echo önbelleği ve arşiv sinyali `refreshTodaySurfaces`'tan.
        //
        // Burada elle yazılıyordu ve iki şeyi yanlış yapıyordu:
        //  • `entryCount: 1` sabitti — v3 günde çoklu an destekliyor, yani
        //    kullanıcının beşinci anı da widget'a "1 an" diye düşüyordu.
        //  • yalnız *yeni yazılanı* biliyordu; günün gerçek son anı bu
        //    olmayabilir (geçmiş güne değil ama aynı güne daha geç saatli
        //    bir an eklenmişse).
        //
        // Tek bir yer diski okuyup türetilmiş durumu hesaplıyor; oluşturma da
        // silme de aynı kapıdan geçiyor.
        refreshTodaySurfaces(context: context)
    }

    /// Bugünden **türetilen** yüzeyleri diskteki gerçek duruma göre yeniden
    /// yazar: widget, Echo önbelleği, arşiv tazeleme sinyali.
    ///
    /// Neden ayrı bir giriş noktası: `write` yalnızca *oluşturma* yolu.
    /// Silme (`clearToday`, `clearEntry`) ve güncelleme (`attachPhotoAndNote`)
    /// bu tipten geçmiyordu ve yan etkilerin hiçbirini çalıştırmıyordu —
    /// yani kullanıcı bir anı sildiğinde **widget o anı göstermeye devam
    /// ediyordu**, gece yarısı sıfırlaması gelene kadar. Aynı şey Echo
    /// önbelleği için de geçerliydi.
    ///
    /// `write`'ın yaptığı gibi "ne yazdığımı biliyorum" varsayımıyla değil,
    /// **diski okuyarak** çalışıyor. Böylece ne olduğu (ekleme / silme /
    /// düzenleme) önemli değil; sonuç her hâlükârda doğru ve çağrı
    /// idempotent.
    /// - Parameter notify: `todaySongSaved` atılsın mı.
    ///
    ///   **Yerel** yazma/silme için `true`: ekranlar o bildirimle tazeleniyor.
    ///
    ///   **Uzak** (CloudKit reconcile) için `false`. Uzak yol zaten
    ///   `.momentsDidChangeRemotely` atıyor ve ekranlar ona *görüntülenen ayı
    ///   koruyarak* tepki veriyor. `todaySongSaved`'i oradan da atmak
    ///   `ArchiveView`'ın `loadDataAsync()` dalını tetikliyordu — o dal yıl/ayı
    ///   `Date()`'ten sabit alıyor, yani geçmiş bir ayı gezen kullanıcı her
    ///   uzak senkronda bu aya fırlatılıyordu. (`ArchiveView`'ın
    ///   `.momentsDidChangeRemotely` dalı tam bunu önlemek için
    ///   `loadDataAsync` kullanmıyor; bildirim arka kapıdan aynı çağrıyı
    ///   getiriyordu.) Ayrıca `V3CircleView` o bildirimde
    ///   `loadFriends(force:)` çağırıyor — her uzak değişiklikte cache TTL'ini
    ///   atlayan zorunlu bir CloudKit sorgusu demekti.
    static func refreshTodaySurfaces(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        notify: Bool = true
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let moments = PersistenceController.shared
            .fetchMoments(for: today, context: context)
            .filter { !$0.passed }

        // Widget ve Echo günün **son** anını gösteriyor.
        guard let latest = moments.max(by: { $0.time < $1.time }) else {
            // Bugün hiç an kalmadı — türetilmiş her şey temizlenmeli.
            WidgetDataWriter.clear()
            TodayViewModel.clearCachedEchoMood()
            if notify { NotificationCenter.default.post(name: .init("todaySongSaved"), object: nil) }
            return
        }

        let label = V3Mood.closest(toHex: latest.moodColorHex)?.label.lowercased() ?? ""
        TodayViewModel.writeCachedEchoMood(hex: latest.moodColorHex, label: label)
        WidgetDataWriter.writeTodayEntry(
            songName: latest.songName ?? "",
            artistName: latest.songArtist ?? "",
            moodLabel: label,
            moodColorHex: latest.moodColorHex,
            note: latest.note,
            entryCount: moments.count
        )
        if notify { NotificationCenter.default.post(name: .init("todaySongSaved"), object: nil) }
    }
}
