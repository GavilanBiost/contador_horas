import SwiftUI
import SwiftData
import StoreKit

struct SettingsHubView: View {
    @Query private var clients: [Client]
    @Query private var projects: [Project]
    @Query(sort: [SortDescriptor(\TimeEntry.date, order: .reverse)]) private var allEntries: [TimeEntry]

    @Environment(\.requestReview) private var requestReview
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        NavigationStack {
            List {
                Section(lang["settings.organization"]) {
                    NavigationLink {
                        ClientListView()
                    } label: {
                        Label(lang["settings.clients"], systemImage: "person.2.fill")
                            .badge(clients.count)
                    }
                    NavigationLink {
                        ProjectListView()
                    } label: {
                        Label(lang["settings.projects"], systemImage: "folder.fill")
                            .badge(projects.count)
                    }
                }

                Section(lang["settings.hours_section"]) {
                    NavigationLink {
                        WeeklyHoursSettingsView()
                    } label: {
                        Label(lang["settings.weekly_hours"], systemImage: "calendar.badge.clock")
                    }
                }

                Section(lang["settings.language_section"]) {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        Label(lang["settings.language"], systemImage: "globe")
                    }
                }

                Section(lang["settings.data"]) {
                    ShareLink(
                        item: csvExportURL,
                        preview: SharePreview(
                            "\(Self.filenameDateFormatter.string(from: Date()))_horas.csv",
                            image: Image(systemName: "tablecells")
                        )
                    ) {
                        Label(lang["settings.export"], systemImage: "arrow.up.doc.fill")
                    }
                }

                Section(lang["settings.support"]) {
                    Button {
                        requestReview()
                    } label: {
                        Label(lang["settings.rate"], systemImage: "star.fill")
                    }
                    Link(destination: URL(string: "mailto:?subject=Sugerencia%20para%20Contador%20de%20Horas")!) {
                        Label(lang["settings.suggest"], systemImage: "envelope.fill")
                    }
                }

                Section {
                    LabeledContent(lang["settings.version"], value: "1.2")
                } footer: {
                    Text(lang["settings.privacy"])
                }
            }
            .navigationTitle(lang["tab.settings"])
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
        .environment(LanguageManager())
}
