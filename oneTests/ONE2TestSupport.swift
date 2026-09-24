//
//  ONE2TestSupport.swift
//  oneTests
//
//  ONE 2.0 depo testleri için bellekte SQLite store ve ayarlanabilir saat.
//

import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
enum ONE2TestStack {
    /// Uygulamanın kendi container'ının kullandığı model örneği. Ayrı bir
    /// `NSManagedObjectModel(contentsOf:)` kopyası `DailySong`, `EntryMO` gibi
    /// sınıfları ikinci kez sahiplenir; paralel koşan testlerde
    /// `DailySong(context:)` hangi entity'yi kullanacağını bilemez ve Core Data
    /// istisna fırlatır ("Failed to find a unique match…").
    static let model: NSManagedObjectModel = PersistenceController(inMemory: true).container.managedObjectModel

    /// `/dev/null` URL'li SQLite: gerçek SQLite davranışı, diske yazmadan.
    static func makeContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "one", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        precondition(loadError == nil, "\(String(describing: loadError))")
        return container
    }
}

/// Testte ileri sarılabilen saat.
final class TestClock: AppClock, @unchecked Sendable {
    var now: Date
    let calendar: Calendar

    init(_ iso: String, timeZone: String = "Europe/Istanbul") {
        now = ISO8601DateFormatter().date(from: iso)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZone)!
        calendar = cal
    }

    func advance(hours: Double) { now = now.addingTimeInterval(hours * 3600) }
}
