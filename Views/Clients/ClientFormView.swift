import SwiftUI
import SwiftData

/// Formulario para crear o editar un cliente / departamento.
struct ClientFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var client: Client?

    @State private var name = ""
    @State private var colorHex = Palette.defaultHex
    @State private var weeklyHours: Double = 0

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Ej. Cliente Acme / Marketing", text: $name)
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
            .navigationTitle(client == nil ? "Nuevo cliente" : "Editar cliente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).disabled(!isValid)
                }
            }
            .onAppear {
                if let client {
                    name = client.name
                    colorHex = client.colorHex
                    weeklyHours = client.weeklyHours
                }
            }
        }
    }

    private func save() {
        if let client {
            client.name = name
            client.colorHex = colorHex
            client.weeklyHours = weeklyHours
        } else {
            context.insert(Client(name: name, colorHex: colorHex, weeklyHours: weeklyHours))
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    ClientFormView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
