import SwiftUI
import SwiftData

/// Formulario para crear o editar un proyecto y asignarlo a un cliente.
struct ProjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Client.name) private var clients: [Client]

    var project: Project?

    @State private var name = ""
    @State private var descriptionText = ""
    @State private var colorHex = Palette.colors[1]
    @State private var weeklyHours: Double = 0
    @State private var selectedClient: Client?

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej. Rediseño web", text: $name)
                }
                Section("Cliente / Departamento") {
                    Picker("Cliente", selection: $selectedClient) {
                        Text("Sin asignar").tag(Client?.none)
                        ForEach(clients) { Text($0.name).tag(Client?.some($0)) }
                    }
                }
                Section("Descripción (opcional)") {
                    TextField("Detalles del proyecto…", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Horas semanales asignadas") {
                    Stepper(value: $weeklyHours, in: 0...168, step: 1) {
                        HStack {
                            Text("Horas/semana")
                            Spacer()
                            Text(weeklyHours == 0 ? "Sin asignar" : Formatters.hours(weeklyHours))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Color identificativo") {
                    ColorSelector(selectedHex: $colorHex)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle(project == nil ? "Nuevo proyecto" : "Editar proyecto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).disabled(!isValid)
                }
            }
            .onAppear {
                if let project {
                    name = project.name
                    descriptionText = project.projectDescription
                    colorHex = project.colorHex
                    weeklyHours = project.weeklyHours
                    selectedClient = project.client
                } else {
                    selectedClient = clients.first
                }
            }
        }
    }

    private func save() {
        if let project {
            project.name = name
            project.projectDescription = descriptionText
            project.colorHex = colorHex
            project.weeklyHours = weeklyHours
            project.client = selectedClient
        } else {
            context.insert(Project(
                name: name,
                projectDescription: descriptionText,
                colorHex: colorHex,
                weeklyHours: weeklyHours,
                client: selectedClient
            ))
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    ProjectFormView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
