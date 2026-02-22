//
//  oneApp.swift
//  one
//
//  Created by Batu Demir on 23.02.2026.
//

import SwiftUI
import CoreData

@main
struct oneApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
