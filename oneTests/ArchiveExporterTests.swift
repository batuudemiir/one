//
//  ArchiveExporterTests.swift
//  oneTests
//
//  Dışa aktarma duruş ilke 4'ün kod karşılığı: arşivin sahibi kullanıcı.
//  Dosyanın **okunabilir ve eksiksiz** olması bu yüzden bir davranış, bir
//  detay değil.
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

struct ArchiveExporterTests {

    @Test("Dosya adı ISO tarihli ve .json")
    func fileNameShape() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 8
        let date = Calendar.current.date(from: comps)!
        #expect(ArchiveExporter.fileName(now: date) == "ONE-arsiv-2026-09-08.json")
    }

    /// Dosya adı cihazın takvimine göre değişmemeli: en_US_POSIX sabit.
    @Test("Dosya adı yerel ayardan etkilenmez")
    func fileNameIsLocaleIndependent() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 5
        let date = Calendar.current.date(from: comps)!
        #expect(ArchiveExporter.fileName(now: date).contains("2026-01-05"))
    }

    @Test("Boş arşiv geçerli JSON üretir")
    func emptyArchiveIsValidJSON() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let url = try ArchiveExporter.writeArchive(context: context)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["app"] as? String == "ONE")
        #expect(json?["schema"] as? Int == 1)
        #expect(json?["momentCount"] as? Int == 0)
        #expect((json?["moments"] as? [Any])?.isEmpty == true)
    }

    @Test("Yazılan an dosyada çıkar")
    func writtenMomentAppears() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let today = Calendar.current.startOfDay(for: Date())

        _ = controller.insertNewMoment(
            for: today,
            moodColorHex: "#00B58C",
            moodWord: "huzurlu",
            note: "iki satır",
            songName: "Sen Ağlama",
            songArtist: "Sezen Aksu",
            photoData: nil,
            scope: .private,
            context: context
        )
        try context.save()

        let url = try ArchiveExporter.writeArchive(context: context)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let moments = json?["moments"] as? [[String: Any]] ?? []
        #expect(moments.count == 1)
        #expect(moments.first?["song"] as? String == "Sen Ağlama")
        #expect(moments.first?["note"] as? String == "iki satır")
        #expect(moments.first?["hasPhoto"] as? Bool == false)
    }
}
