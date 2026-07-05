import SwiftUI
import SwiftData

@main
struct HourTrackerApp: App {
    /// Contenedor SwiftData con todos los modelos de la app.
    /// `isStoredInMemoryOnly: false` => persistencia local en disco.
    let container: ModelContainer = {
        let schema = Schema([
            Client.self,
            Project.self,
            TimeEntry.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
