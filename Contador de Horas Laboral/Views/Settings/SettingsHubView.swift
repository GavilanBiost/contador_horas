import SwiftUI
import SwiftData
import StoreKit

/// Pantalla de ajustes: punto de entrada a la gestión de clientes,
/// proyectos y configuración de horas semanales.
struct SettingsHubView: View {
    @Query private var clients: [Client]
    @Query private var projects: [Project]
    @Query(sort: [SortDescriptor(\TimeEntry.date, order: .reverse)]) private var allEntries: [TimeEntry]

    @Environment(\.requestReview) private var requestReview

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

                Section("Datos") {
                    ShareLink(
                        item: csvExportURL,
                        preview: SharePreview(
                            "\(Self.filenameDateFormatter.string(from: Date()))_horas.csv",
                            image: Image(systemName: "tablecells")
                        )
                    ) {
                        Label("Exportar registros (CSV)", systemImage: "arrow.up.doc.fill")
                    }
                }

                Section("Soporte") {
                    Button {
                        requestReview()
                    } label: {
                        Label("Valorar la app", systemImage: "star.fill")
                    }
                    Link(destination: URL(string: "mailto:?subject=Sugerencia%20para%20Contador%20de%20Horas")!) {
                        Label("Enviar sugerencia", systemImage: "envelope.fill")
                    }
                }

                Section {
                    LabeledContent("Versión", value: "1.2")
                } footer: {
                    Text("Tus datos se guardan únicamente en este dispositivo.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }

    // MARK: – CSV export

    private var csvExportURL: URL {
        let datePart = Self.filenameDateFormatter.string(from: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(datePart)_horas.csv")
        try? buildCSV().write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static let filenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func buildCSV() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var lines = ["Fecha,Cliente,Proyecto,Horas,Minutos,Comentario"]
        for entry in allEntries {
            let fecha = df.string(from: entry.date)
            let cliente = csvEscape(entry.client?.name ?? "")
            let proyecto = csvEscape(entry.project?.name ?? "")
            let totalMin = Int((entry.hours * 60).rounded())
            let horas = totalMin / 60
            let minutos = totalMin % 60
            let comentario = csvEscape(entry.comment)
            lines.append("\(fecha),\(cliente),\(proyecto),\(horas),\(minutos),\(comentario)")
        }
        return lines.joined(separator: "\n")
    }

    /// Envuelve el campo en comillas dobles y escapa comillas internas.
    private func csvEscape(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\"", with: "\"\"")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }
}

#Preview {
    SettingsHubView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
