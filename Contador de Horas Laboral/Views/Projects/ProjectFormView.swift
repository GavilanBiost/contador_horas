import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang

    @Query(sort: \Client.name) private var clients: [Client]

    var project: Project?

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var colorHex = Palette.colors[1]
    @State private var weeklyHours: Double = 0
    @State private var selectedClientIDs: Set<PersistentIdentifier> = []

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang["projects.name"]) {
                    TextField(lang["projects.placeholder"], text: $name)
                }

                Section {
                    if clients.isEmpty {
                        Text(lang["projects.create_client_first"])
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(clients) { client in
                            clientRow(client)
                        }
                    }
                } header: {
                    Text(lang["projects.clients_section"])
                } footer: {
                    if !selectedClientIDs.isEmpty {
                        Text("\(lang["projects.selected"]) \(selectedClientIDs.count)")
                    }
                }

                Section(lang["projects.description"]) {
                    TextField(lang["projects.description_hint"], text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(lang["projects.weekly_hours"]) {
                    Stepper(value: $weeklyHours, in: 0...168, step: 1) {
                        HStack {
                            Text(lang["projects.per_week"])
                            Spacer()
                            Text(weeklyHours == 0 ? lang["whours.no_assigned"] : Formatters.hours(weeklyHours))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(lang["projects.color"]) {
                    ColorSelector(selectedHex: $colorHex)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle(project == nil ? lang["projects.new"] : lang["projects.edit"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang["projects.cancel"]) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang["projects.save"], action: save).disabled(!isValid)
                }
            }
            .onAppear {
                if let project {
                    name = project.name
                    descriptionText = project.projectDescription
                    colorHex = project.colorHex
                    weeklyHours = project.weeklyHours
                    selectedClientIDs = Set(project.clients.map { $0.persistentModelID })
                }
            }
        }
    }

    private func clientRow(_ client: Client) -> some View {
        let isSelected = selectedClientIDs.contains(client.persistentModelID)
        return Button {
            if isSelected {
                selectedClientIDs.remove(client.persistentModelID)
            } else {
                selectedClientIDs.insert(client.persistentModelID)
            }
        } label: {
            HStack(spacing: 12) {
                ColorDot(hex: client.colorHex, size: 14)
                Text(client.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let selected = clients.filter { selectedClientIDs.contains($0.persistentModelID) }
        if let project {
            project.name = name
            project.projectDescription = descriptionText
            project.colorHex = colorHex
            project.weeklyHours = weeklyHours
            project.clients = selected
        } else {
            context.insert(Project(
                name: name,
                projectDescription: descriptionText,
                colorHex: colorHex,
                weeklyHours: weeklyHours,
                clients: selected
            ))
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    ProjectFormView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(LanguageManager())
}
