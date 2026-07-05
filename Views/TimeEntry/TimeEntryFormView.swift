import SwiftUI
import SwiftData

/// Formulario para crear o editar un registro de horas.
/// Si se le pasa un `entry`, funciona en modo edición.
struct TimeEntryFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Project.name) private var projects: [Project]

    /// Registro a editar (nil = creación).
    var entry: TimeEntry?

    @State private var date: Date = .now
    @State private var hours: Double = 1
    @State private var comment: String = ""
    @State private var selectedClient: Client?
    @State private var selectedProject: Project?

    /// Proyectos filtrados por el cliente seleccionado.
    private var availableProjects: [Project] {
        guard let selectedClient else { return projects }
        return projects.filter { $0.client?.persistentModelID == selectedClient.persistentModelID }
    }

    private var isValid: Bool { hours > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fecha") {
                    DatePicker("Día", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "es_ES"))
                }

                Section("Horas trabajadas") {
                    Stepper(value: $hours, in: 0...24, step: 0.25) {
                        HStack {
                            Text("Horas")
                            Spacer()
                            Text(Formatters.hours(hours))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("Cliente / Departamento") {
                    if clients.isEmpty {
                        Text("Crea primero un cliente en Ajustes.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Cliente", selection: $selectedClient) {
                            Text("Sin asignar").tag(Client?.none)
                            ForEach(clients) { client in
                                Text(client.name).tag(Client?.some(client))
                            }
                        }
                        .onChange(of: selectedClient) { _, _ in
                            // Si el proyecto ya no pertenece al cliente, se limpia.
                            if let p = selectedProject, p.client?.persistentModelID != selectedClient?.persistentModelID {
                                selectedProject = nil
                            }
                        }
                    }
                }

                Section("Proyecto") {
                    Picker("Proyecto", selection: $selectedProject) {
                        Text("Sin proyecto").tag(Project?.none)
                        ForEach(availableProjects) { project in
                            Text(project.name).tag(Project?.some(project))
                        }
                    }
                }

                Section("Comentario (opcional)") {
                    TextField("Notas sobre el trabajo…", text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(entry == nil ? "Nuevo registro" : "Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).disabled(!isValid)
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    private func loadIfEditing() {
        guard let entry else { return }
        date = entry.date
        hours = entry.hours
        comment = entry.comment
        selectedClient = entry.client
        selectedProject = entry.project
    }

    private func save() {
        if let entry {
            entry.date = date
            entry.hours = hours
            entry.comment = comment
            entry.client = selectedClient
            entry.project = selectedProject
        } else {
            let new = TimeEntry(
                date: date,
                hours: hours,
                comment: comment,
                client: selectedClient ?? selectedProject?.client,
                project: selectedProject
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    TimeEntryFormView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
