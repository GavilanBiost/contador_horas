import SwiftUI
import SwiftData

struct WeeklyHoursSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(LanguageManager.self) private var lang
    @Query private var settings: [AppSettings]
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Project.name) private var projects: [Project]

    private var total: Double { settings.first?.totalWeeklyHours ?? 0 }
    private var dailyTargetHours: Double { settings.first?.dailyHoursTarget ?? 0.0 }
    private var assignedToClients: Double { clients.reduce(0) { $0 + $1.weeklyHours } }
    private var remainingToAssign: Double { max(total - assignedToClients, 0) }
    private var overAssigned: Bool { assignedToClients > total }

    var body: some View {
        Form {
            Section(lang["whours.total"]) {
                Stepper(value: totalBinding, in: 0...168, step: 1) {
                    HStack {
                        Text(lang["whours.per_week"])
                        Spacer()
                        Text(Formatters.hours(total))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Stepper(value: dailyTargetBinding, in: 0...24, step: 0.5) {
                    HStack {
                        Text(lang["whours.daily"])
                        Spacer()
                        Text(dailyTargetHours == 0
                            ? (total > 0 ? "\(lang["whours.auto"]) (\(Formatters.hours(total / 5)))" : lang["whours.auto"])
                            : Formatters.hours(dailyTargetHours))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(lang["whours.daily"])
            } footer: {
                Text(lang["whours.footer"])
            }

            Section(lang["whours.distribution"]) {
                LabeledContent(lang["whours.assigned"], value: Formatters.hours(assignedToClients))
                LabeledContent(lang["whours.available"]) {
                    Text(Formatters.hours(remainingToAssign))
                        .foregroundStyle(overAssigned ? .red : .green)
                }
                if overAssigned {
                    Label(lang["whours.overassigned"], systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if !clients.isEmpty {
                Section(lang["whours.by_client"]) {
                    ForEach(clients) { client in
                        ClientHoursRow(client: client)
                    }
                }
            }
        }
        .navigationTitle(lang["whours.title"])
        .navigationBarTitleDisplayMode(.inline)
    }

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

    private var dailyTargetBinding: Binding<Double> {
        Binding(
            get: { settings.first?.dailyHoursTarget ?? 0.0 },
            set: { newValue in
                let stored: Double? = newValue == 0 ? nil : newValue
                if let s = settings.first {
                    s.dailyHoursTarget = stored
                } else {
                    context.insert(AppSettings(dailyHoursTarget: stored))
                }
                try? context.save()
            }
        )
    }
}

private struct ClientHoursRow: View {
    @Environment(\.modelContext) private var context
    @Environment(LanguageManager.self) private var lang
    @Bindable var client: Client

    var body: some View {
        Stepper(value: $client.weeklyHours, in: 0...168, step: 1) {
            HStack {
                ColorDot(hex: client.colorHex)
                Text(client.name)
                    .lineLimit(1)
                Spacer()
                Text(client.weeklyHours == 0 ? lang["whours.no_assigned"] : Formatters.hours(client.weeklyHours))
                    .foregroundStyle(client.weeklyHours == 0 ? .tertiary : .secondary)
                    .font(.body.weight(.semibold))
            }
        }
        .onChange(of: client.weeklyHours) { _, _ in
            try? context.save()
        }
    }
}

#Preview {
    NavigationStack { WeeklyHoursSettingsView() }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(LanguageManager())
}
