import SwiftUI
import SwiftData

/// Configuración del presupuesto de horas semanales.
/// Muestra cuántas horas hay asignadas a clientes/proyectos y cuántas
/// quedan disponibles del total semanal.
struct WeeklyHoursSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Project.name) private var projects: [Project]

    private var total: Double { settings.first?.totalWeeklyHours ?? 0 }

    /// Suma de horas asignadas a clientes (presupuesto repartido).
    private var assignedToClients: Double { clients.reduce(0) { $0 + $1.weeklyHours } }
    private var remainingToAssign: Double { max(total - assignedToClients, 0) }
    private var overAssigned: Bool { assignedToClients > total }

    var body: some View {
        Form {
            Section("Total semanal") {
                Stepper(value: totalBinding, in: 0...168, step: 1) {
                    HStack {
                        Text("Horas/semana")
                        Spacer()
                        Text(Formatters.hours(total))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Reparto del presupuesto") {
                LabeledContent("Asignadas a clientes", value: Formatters.hours(assignedToClients))
                LabeledContent("Disponibles") {
                    Text(Formatters.hours(remainingToAssign))
                        .foregroundStyle(overAssigned ? .red : .green)
                }
                if overAssigned {
                    Label("Has asignado más horas de las disponibles.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if !clients.isEmpty {
                Section("Por cliente / departamento") {
                    ForEach(clients) { client in
                        HStack {
                            ColorDot(hex: client.colorHex)
                            Text(client.name)
                            Spacer()
                            Text(client.weeklyHours == 0 ? "—" : Formatters.hours(client.weeklyHours))
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Edita las horas de cada cliente desde Ajustes › Clientes.")
                }
            }
        }
        .navigationTitle("Horas semanales")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Binding que escribe directamente en el AppSettings persistido.
    private var totalBinding: Binding<Double> {
        Binding(
            get: { settings.first?.totalWeeklyHours ?? 0 },
            set: { newValue in
                if let s = settings.first {
                    s.totalWeeklyHours = newValue
                } else {
                    context.insert(AppSettings(totalWeeklyHours: newValue))
                }
                try? context.save()
            }
        )
    }
}

#Preview {
    NavigationStack { WeeklyHoursSettingsView() }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
