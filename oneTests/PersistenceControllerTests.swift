//
//  PersistenceControllerTests.swift
//  oneTests
//
//  Tests for PersistenceController — CRUD operations, pattern analysis, Color hex conversion.
//

import Testing
import SwiftUI
import CoreData
@testable import OneDailyBatuhan

// MARK: - PersistenceController Tests

struct PersistenceControllerTests {

    // MARK: - Helpers

    /// Create a fresh in-memory PersistenceController for each test.
    private func makePersistence() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    /// Test fixture'ı.
    ///
    /// Eskiden `pc.saveDailySong(song:mood:platform:)` çağrılıyordu; o metot
    /// ve aldığı `Song` / `Mood` yapıları üründen çıktı (tek çağıranı yoktu,
    /// **upsert** semantiği v3'ün çoklu-an modeliyle çelişiyordu). Testlerin
    /// asıl konusu yazma değil **okuma/analiz** tarafı — `fetchDailySong`,
    /// `fetchDailySongsForMonth`, `analyzeSongPatterns` — ve onların hepsi
    /// duruyor. O yüzden dosya silinmedi, yalnız fixture bugünkü yazma
    /// API'sine (`insertNewMoment`) bağlandı.
    @discardableResult
    private func insert(
        _ pc: PersistenceController,
        date: Date,
        name: String = "Strobe",
        artist: String = "deadmau5",
        note: String = "",
        moodWord: String = "odaklı",
        moodHex: String = "#2B4CF0",
        scope: MomentScope = .private,
        context: NSManagedObjectContext
    ) -> DailySong {
        let item = pc.insertNewMoment(
            for: date,
            moodColorHex: moodHex,
            moodWord: moodWord,
            note: note,
            songName: name,
            songArtist: artist,
            scope: scope,
            context: context
        )
        try? context.save()
        return item
    }

    // MARK: - Save & Fetch Single

    @Test("Save and fetch a daily song for a specific date")
    func testSaveAndFetchDailySong() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        insert(pc, date: today, note: "Test note", context: context)

        let fetched = pc.fetchDailySong(for: today, context: context)
        #expect(fetched != nil)
        #expect(fetched?.songName == "Strobe")
        #expect(fetched?.artistName == "deadmau5")
        #expect(fetched?.genre == "Electronic")
        #expect(fetched?.moodWord == "Derin")
        #expect(fetched?.dailyNote == "Test note")
        #expect(fetched?.platform == "Spotify")
    }

    @Test("Fetch returns nil for a date with no entry")
    func testFetchReturnsNilForMissingDate() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let randomDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let fetched = pc.fetchDailySong(for: randomDate, context: context)
        #expect(fetched == nil)
    }

    // MARK: - Aynı güne çoklu an

    /// Bu test eskiden **tersini** doğruluyordu: "aynı güne ikinci kayıt
    /// üzerine yazar, tek satır kalır". O upsert semantiği v2'nin
    /// günde-tek-şarkı modelinden geliyordu ve v3'te bir hataya dönüştü —
    /// kullanıcı günde birden çok an bırakabiliyor, upsert öncekileri
    /// siliyordu. Yazma yolu (`insertNewMoment`) artık ekliyor ve her ana
    /// gün içinde bir `entryIndex` veriyor.
    @Test("Aynı güne ikinci an ekleniyor, öncekini ezmiyor")
    func testSecondMomentSameDayAppends() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        insert(pc, date: today, name: "Song A", note: "First", moodWord: "odaklı", context: context)
        insert(pc, date: today, name: "Song B", note: "Second", moodWord: "huzurlu", context: context)

        let all = pc.fetchAllDailySongs(context: context)
        #expect(all.count == 2, "ikinci an öncekini ezmemeli")

        let moments = pc.fetchMoments(for: today, context: context)
        #expect(moments.count == 2)
        #expect(Set(moments.map { $0.entryIndex }) == [0, 1], "her anın kendi sırası olmalı")
    }

    // MARK: - Fetch All

    @Test("fetchAllDailySongs returns all entries sorted by date descending")
    func testFetchAllDailySongs() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        let day1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let day3 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!

        insert(pc, date: day1, name: "A", context: context)
        insert(pc, date: day2, name: "B", context: context)
        insert(pc, date: day3, name: "C", context: context)

        let all = pc.fetchAllDailySongs(context: context)
        #expect(all.count == 3)

        // Should be sorted descending (newest first)
        #expect(all[0].songName == "C")
        #expect(all[1].songName == "B")
        #expect(all[2].songName == "A")
    }

    @Test("fetchAllDailySongs returns empty array when no entries exist")
    func testFetchAllDailySongsEmpty() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        let all = pc.fetchAllDailySongs(context: context)
        #expect(all.isEmpty)
    }

    // MARK: - Fetch Monthly

    @Test("fetchDailySongsForMonth returns only songs in the requested month")
    func testFetchDailySongsForMonth() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        // January entries
        let jan1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let jan2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 20))!
        // February entry
        let feb1 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!

        insert(pc, date: jan1, name: "Jan A", context: context)
        insert(pc, date: jan2, name: "Jan B", context: context)
        insert(pc, date: feb1, name: "Feb A", context: context)

        let janSongs = pc.fetchDailySongsForMonth(year: 2026, month: 1, context: context)
        #expect(janSongs.count == 2)

        let febSongs = pc.fetchDailySongsForMonth(year: 2026, month: 2, context: context)
        #expect(febSongs.count == 1)
        #expect(febSongs.first?.songName == "Feb A")
    }

    @Test("fetchDailySongsForMonth returns empty for month with no entries")
    func testFetchMonthEmpty() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        let songs = pc.fetchDailySongsForMonth(year: 2026, month: 6, context: context)
        #expect(songs.isEmpty)
    }

    @Test("fetchDailySongsForMonth is sorted ascending")
    func testFetchMonthlySorted() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let calendar = Calendar.current

        let d15 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        let d5 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5))!
        let d25 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 25))!

        insert(pc, date: d15, name: "Mid", context: context)
        insert(pc, date: d5, name: "Early", context: context)
        insert(pc, date: d25, name: "Late", context: context)

        let songs = pc.fetchDailySongsForMonth(year: 2026, month: 3, context: context)
        #expect(songs.count == 3)
        #expect(songs[0].songName == "Early")
        #expect(songs[1].songName == "Mid")
        #expect(songs[2].songName == "Late")
    }

    // Şarkı tekrarı analizi testleri kaldırıldı (7 test).
    //
    // Konuları — `analyzeSongPatterns`, `getMostFrequentSong`,
    // `SongPattern.dateString` — üründen çıktı. Üretimde tek çağıranları
    // yoktu; zincir kendi içinde dönüyor, dışarıdan yalnız bu testler
    // tutuyordu. Yani testler ölü kodu kullanılıyor gibi gösteriyordu.
    //
    // Ekrana çıkan "en sık çalınan şarkılar" hesabı
    // `MonthlySummaryViewModel` içinde ve kendi testleriyle geliyor.

    // MARK: - Paylaşım kapsamı

    /// Eski test "foto yoksa paylaşma" kuralını doğruluyordu. O kural v3'te
    /// **kasıtlı olarak kalktı**: bir an fotoğrafsız da paylaşılabiliyor,
    /// Çevre renk noktasını gösteriyor. Yerine kapsamın kaydedildiğini
    /// doğruluyoruz — `scope` yazma yolunun tek paylaşım anahtarı.
    @Test("scope .friends paylaşım bayraklarını açıyor")
    func testScopeFriendsMarksShared() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        insert(pc, date: today, scope: .friends, context: context)

        let fetched = pc.fetchDailySong(for: today, context: context)
        #expect(fetched?.isSharedWithCircle == true)
        #expect(fetched?.shareWithCircle == true)
    }

    @Test("scope .private paylaşım bayraklarını kapalı bırakıyor")
    func testScopePrivateStaysUnshared() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        insert(pc, date: today, scope: .private, context: context)

        let fetched = pc.fetchDailySong(for: today, context: context)
        #expect(fetched?.isSharedWithCircle == false)
    }

    // MARK: - Note Trimming

    @Test("Not kaydedilirken baştaki/sondaki boşluk kırpılıyor")
    func testNoteTrimming() {
        let pc = makePersistence()
        let context = pc.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        insert(pc, date: today, note: "  hello world  \n", context: context)

        let fetched = pc.fetchDailySong(for: today, context: context)
        #expect(fetched?.dailyNote == "hello world")
    }

    // MARK: - Color.toHex() Extension

    @Test("Color.toHex returns valid hex string")
    func testColorToHex() {
        let red = Color.red.toHex()
        // Red should be close to #FF0000
        #expect(red.hasPrefix("#"))
        #expect(red.count == 7)
    }

    @Test("Color.toHex round-trip with known hex")
    func testColorToHexRoundTrip() {
        let originalHex = "#5B8DEF"
        let color = Color(hex: originalHex)
        let resultHex = color.toHex()

        // Parse both hexes to compare RGB values with tolerance
        let originalR = Int(originalHex.dropFirst().prefix(2), radix: 16) ?? 0
        let originalG = Int(originalHex.dropFirst(3).prefix(2), radix: 16) ?? 0
        let originalB = Int(originalHex.dropFirst(5).prefix(2), radix: 16) ?? 0

        let resultClean = String(resultHex.dropFirst())
        let resultR = Int(resultClean.prefix(2), radix: 16) ?? 0
        let resultG = Int(resultClean.dropFirst(2).prefix(2), radix: 16) ?? 0
        let resultB = Int(resultClean.dropFirst(4).prefix(2), radix: 16) ?? 0

        #expect(abs(originalR - resultR) <= 1)
        #expect(abs(originalG - resultG) <= 1)
        #expect(abs(originalB - resultB) <= 1)
    }

    // MARK: - Date Normalization

    @Test("Tarih gün başına normalize ediliyor")
    func testDateNormalization() {
        let pc = makePersistence()
        let context = pc.container.viewContext

        // Create date at 15:30
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 1
        comps.hour = 15
        comps.minute = 30
        let afternoonDate = Calendar.current.date(from: comps)!

        insert(pc, date: afternoonDate, context: context)

        // Should be fetchable using any time on that day
        let morning = Calendar.current.startOfDay(for: afternoonDate)
        let fetched = pc.fetchDailySong(for: morning, context: context)
        #expect(fetched != nil)

        // The stored date should be start of day
        let storedDate = fetched?.date
        let startOfDay = Calendar.current.startOfDay(for: afternoonDate)
        #expect(storedDate == startOfDay)
    }
}
