import SwiftUI
import SwiftData

@main
struct HourTrackerApp: App {
    let container: ModelContainer = {
        let schema = Schema([Client.self, Project.self, TimeEntry.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Cambio de schema incompatible con el store existente → borra y recrea.
            let storeDir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let exts = ["sqlite", "sqlite-wal", "sqlite-shm"]
            if let files = try? FileManager.default.contentsOfDirectory(
                at: storeDir, includingPropertiesForKeys: nil
            ) {
                files
                    .filter { exts.contains($0.pathExtension) }
                    .forEach { try? FileManager.default.removeItem(at: $0) }
            }
            return try! ModelContainer(for: schema, configurations: [config])
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
