//
//  StoreBackupTests.swift
//  oneTests
//
//  Açılamayan store silinmez, kenara taşınır (MIGRATION.md §4). iCloud'u
//  kapalı kullanıcı için tek kurtarma yolu bu yedek.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct StoreBackupTests {

    private func makeSandbox() throws -> (store: URL, root: URL) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreBackupTests-\(UUID().uuidString)", isDirectory: true)
        let storeDir = base.appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        return (storeDir.appendingPathComponent("one.sqlite"),
                base.appendingPathComponent("StoreBackups", isDirectory: true))
    }

    private func touch(_ url: URL, _ text: String = "x") throws {
        try Data(text.utf8).write(to: url)
    }

    @Test("Store, yan dosyalar ve harici veri klasörü yedeğe taşınır")
    func movesAllStoreFiles() throws {
        let (store, root) = try makeSandbox()
        let dir = store.deletingLastPathComponent()
        try touch(store, "db")
        try touch(URL(fileURLWithPath: store.path + "-wal"))
        try touch(URL(fileURLWithPath: store.path + "-shm"))
        let support = dir.appendingPathComponent(".one_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try touch(support.appendingPathComponent("photo-1"), "jpeg")

        let folder = try #require(try StoreBackup.moveAside(storeURL: store, root: root))

        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: store.path))
        #expect(!fm.fileExists(atPath: store.path + "-wal"))
        #expect(!fm.fileExists(atPath: dir.appendingPathComponent(".one_SUPPORT").path))
        #expect(try String(contentsOf: folder.appendingPathComponent("one.sqlite"), encoding: .utf8) == "db")
        #expect(fm.fileExists(atPath: folder.appendingPathComponent("one.sqlite-shm").path))
        #expect(try String(contentsOf: folder.appendingPathComponent(".one_SUPPORT/_EXTERNAL_DATA/photo-1"), encoding: .utf8) == "jpeg")
    }

    @Test("Taşınacak dosya yoksa nil döner, klasör açılmaz")
    func nothingToMove() throws {
        let (store, root) = try makeSandbox()
        #expect(try StoreBackup.moveAside(storeURL: store, root: root) == nil)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test("Yalnız en yeni iki yedek kalır")
    func prunesOldBackups() throws {
        let (store, root) = try makeSandbox()
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        for i in 0..<4 {
            try touch(store, "db\(i)")
            try StoreBackup.moveAside(storeURL: store, root: root, now: base.addingTimeInterval(Double(i) * 60))
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        #expect(names == [
            StoreBackup.stamp(base.addingTimeInterval(120)),
            StoreBackup.stamp(base.addingTimeInterval(180))
        ])
    }

    @Test("Zaman damgası dosya adına uygun ve sıralanabilir")
    func stampShape() {
        let date = Date(timeIntervalSince1970: 0)
        #expect(StoreBackup.stamp(date) == "1970-01-01T00-00-00Z")
        #expect(StoreBackup.stamp(date) < StoreBackup.stamp(date.addingTimeInterval(1)))
    }
}
