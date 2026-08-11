import SwiftUI
import CoreData

extension TodayViewModel {

    /// v3 akışının bekliyorum: song opsiyonel. Var olan `saveEntry` song'u zorunlu
    /// tuttuğu için burada ince bir sarmalayıcı — song yoksa DailySong'a yalnızca
    /// mood/note/photo yazıp Core Data'ya commit ediyor.
    ///
    /// Not: existing saveEntry'nin tüm yan etkileri (streak, badge, orchestrator,
    /// widget) yalnızca song varken çalışıyor. Song'suz kayıtta minimum kritik
    /// yan etkileri burada replikliyoruz — bildirim yeniden kurulumu ve
    /// UI hydrate'i dahil.
    @MainActor
    func saveV3Entry(
        mood: V3Mood,
        note: String,
        photo: UIImage?,
        song: SongResult?,
        scope: MomentScope = .private,
        entryDate: Date? = nil
    ) {
        // v3: her `saveV3Entry` yeni bir "an" eklemeli — o gün mevcut kayıt
        // olsa bile üzerine yazma. Legacy `saveEntry` (song varken çalışan)
        // hâlâ upsert; song'lu akış Faz 3'te de tek-an. Multi-moment yolu
        // song'suz akıştan geçiyor.
        if let song {
            let feeling = FeelingType(rawValue: mood.bridgedMood.rawValue)
            let moodOption = MoodOption(
                key: mood.rawValue,
                color: mood.color,
                label: mood.label.lowercased(),
                meaning: mood.bridgedMood.meaning
            )
            saveEntry(
                song: song,
                mood: moodOption,
                feeling: feeling,
                photo: photo,
                note: note,
                sharePhoto: scope == .friends
            )
            return
        }

        // v3 çok-an write path — Persistence.insertNewMoment daima yeni satır
        // ekler, entryIndex auto atanır.
        let normalized = Calendar.current.startOfDay(for: entryDate ?? Date())
        let photoData = photo?.jpegData(compressionQuality: 0.75)

        let item = PersistenceController.shared.insertNewMoment(
            for: normalized,
            moodColorHex: mood.hex,
            moodWord: mood.label.lowercased(),
            note: note,
            songName: nil,
            songArtist: nil,
            photoData: photoData,
            scope: scope,
            context: self.context
        )
        // Placeholder alanlar — eski ekranlar boş göstermek yerine bunları okur.
        item.songName   = ""
        item.artistName = ""
        item.genre      = ""
        item.emoji      = "🎵"
        item.moodLabel  = mood.label.lowercased()
        item.platform   = "None"

        do {
            try self.context.save()
        } catch {
            ErrorHandler.shared.handle(error, context: "saveV3Entry")
            return
        }

        // Şarkısız çok-an yol entrySaved tetiklemiyor; mood/not sinyalini
        // burada yakala ki günlük mood dağılımı tüm kayıtları kapsasın.
        // bridgedMood.rawValue → saveEntry (MoodOption.key) ve onboarding ile
        // aynı ONEMood key uzayı; dashboard'da tek mood dağılımı çıkar.
        AppAnalytics.shared.track(.moodSelected(mood: mood.bridgedMood.rawValue))
        if !note.isEmpty {
            AppAnalytics.shared.track(.noteAdded(length: note.count))
        }

        Self.writeCachedEchoMood(hex: mood.hex, label: mood.label.lowercased())

        // Bildirimi tazele — bugün kayıt tamam, bugün için pending iptal edilir.
        NotificationOrchestrator.shared.onSongSaved(
            moodLabel: mood.label.lowercased(),
            moodColorHex: mood.hex
        )
        V3ReminderScheduler.reschedule(yesterdayMood: mood)

        WidgetDataWriter.writeTodayEntry(
            songName: "",
            artistName: "",
            moodLabel: mood.label.lowercased(),
            moodColorHex: mood.hex,
            note: note.isEmpty ? nil : note,
            entryCount: 1
        )

        NotificationCenter.default.post(name: .init("todaySongSaved"), object: nil)

        // vm'nin published state'ini yenile — bir sonraki render'da Kaydedildi
        // ekranı, son 7 gün şeridi ve streak count doğru veriyle gelir.
        reloadAfterV3Save()
    }
}
