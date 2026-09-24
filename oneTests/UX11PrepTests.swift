//
//  UX11PrepTests.swift
//  oneTests
//
//  UX-11 öncesi motor tarafı: ekranların view data'sının istediği ama
//  motorda eksik olan okuma yüzeyleri (05 › UX-11, UX_istekleri.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct UX11PrepTests {

    struct Rig {
        let clock: TestClock
        let container: NSPersistentContainer
        let content: ContentRepository
        let journal: JournalStore
        let mood: MoodStore
        let day: DayStore
        let exposure: ExposureStore
        let profile: ProfileStore
    }

    static func rig(_ iso: String = "2026-09-23T06:00:00Z") -> Rig {
        let clock = TestClock(iso)
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("u-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "u-\(UUID())")!)
        return Rig(clock: clock, container: container, content: content,
                   journal: JournalStore(context: ctx, clock: clock), mood: MoodStore(context: ctx, clock: clock),
                   day: DayStore(context: ctx, clock: clock), exposure: ExposureStore(context: ctx, clock: clock),
                   profile: ProfileStore(cloud: MemoryKeyValueStore(), local: MemoryKeyValueStore()))
    }

    // MARK: - Check-in dilimi ve kalıcı yankı

    @Test("Check-in dilimi bağlı girdinin türünden: sabah, akşam, günlük")
    func checkInSlot() throws {
        let r = Self.rig()
        let morning = try r.journal.create(EntryDraft(kind: .morning))
        let evening = try r.journal.create(EntryDraft(kind: .evening))
        #expect(try r.mood.log(score: 3, source: .checkIn, linkedTo: morning.id).slot == .morning)
        #expect(try r.mood.log(score: 3, source: .checkIn, linkedTo: evening.id).slot == .evening)
        #expect(try r.mood.log(score: 3, source: .checkIn).slot == .daily)
        #expect(try r.mood.logs(on: r.clock.today).map(\.slot) == [.morning, .evening, .daily])
    }

    @Test("Yankı check-in'e saklanır: yeniden açılışta ve 14 gün kuralı işledikten sonra da aynı cümle")
    func echoPersisted() throws {
        let r = Self.rig()
        let echoes = EchoEngine(content: r.content, exposure: r.exposure, profile: r.profile, clock: r.clock, mood: r.mood)
        let checkIn = try r.mood.log(score: 2, emotionIDs: ["kaygi.gergin"], source: .checkIn)
        let first = try #require(echoes.echo(for: checkIn))
        let reloaded = try #require(try r.mood.logs(on: r.clock.today).first)
        #expect(reloaded.echoID == first.id)
        #expect(echoes.echo(for: reloaded)?.id == first.id)
        #expect(echoes.echoText(reloaded.echoID) == first.text)
    }
}
