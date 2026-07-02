import SwiftUI
import SwiftData

// MARK: - Schema V1
// AppSettings anidado sin dailyHoursTarget — estructura original del store.
// Swift resuelve 'AppSettings.self' dentro de este enum al tipo anidado,
// por lo que genera la entidad "AppSettings" con un hash distinto al de V2.

enum HourTrackerSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Client.self, Project.self, TimeEntry.self, AppSettings.self]
    }

    @Model
    final class AppSettings {
        var totalWeeklyHours: Double
        init(totalWeeklyHours: Double = 40) {
            self.totalWeeklyHours = totalWeeklyHours
        }
    }
}

// MARK: - Schema V2
// Referencia al AppSettings global (con dailyHoursTarget: Double?).

enum HourTrackerSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Client.self, Project.self, TimeEntry.self, AppSettings.self]
    }
}

// MARK: - Migration plan

enum HourTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HourTrackerSchemaV1.self, HourTrackerSchemaV2.self]
    }
    static var stages: [MigrationStage] { [migrateV1toV2] }
    // Lightweight: añade la columna nullable dailyHoursTarget (nil en filas existentes).
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: HourTrackerSchemaV1.self,
        toVersion: HourTrackerSchemaV2.self
    )
}

// MARK: - App

@main
struct HourTrackerApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            Client.self,
            Project.self,
            TimeEntry.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: HourTrackerMigrationPlan.self,
                configurations: [config]
            )
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
