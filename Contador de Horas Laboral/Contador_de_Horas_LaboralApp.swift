//
//  Contador_de_Horas_LaboralApp.swift
//  Contador de Horas Laboral
//
//  Created by Jesús García Gavilán on 21/06/2026.
//

import SwiftUI
import SwiftData

@main
struct Contador_de_Horas_LaboralApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
