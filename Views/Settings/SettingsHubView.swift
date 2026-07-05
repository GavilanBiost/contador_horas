import SwiftUI
import SwiftData

/// Pantalla de ajustes: punto de entrada a la gestión de clientes,
/// proyectos y configuración de horas semanales.
struct SettingsHubView: View {
    @Query private var clients: [Client]
    @Query private var projects: [Project]

    var body: some View {
        NavigationStack {
            List {
                Section("Organización") {
                    NavigationLink {
                        ClientListView()
                    } label: {
                        Label("Clientes / Departamentos", systemImage: "person.2.fill")
                            .badge(clients.count)
                    }
                    NavigationLink {
                        ProjectListView()
                    } label: {
                        Label("Proyectos", systemImage: "folder.fill")
                            .badge(projects.count)
                    }
                }

                Section("Horas") {
                    NavigationLink {
                        WeeklyHoursSettingsView()
                    } label: {
                        Label("Horas semanales", systemImage: "calendar.badge.clock")
                    }
                }

                Section {
                    LabeledContent("Versión", value: "1.0")
                } footer: {
                    Text("Tus datos se guardan únicamente en este dispositivo.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

#Preview {
    SettingsHubView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
