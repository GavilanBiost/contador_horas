import SwiftUI
import SwiftData

/// Pantalla de inicio: resumen de la semana actual de un vistazo.
struct DashboardView: View {
    @Query private var entries: [TimeEntry]
    @Query private var settings: [AppSettings]

    @State private var showingNewEntry = false

    private var weekInterval: DateInterval { Date().interval(of: .week) }
    private var weekEntries: [TimeEntry] { HoursCalculator.entries(entries, in: weekInterval) }
    private var assigned: Double { settings.first?.totalWeeklyHours ?? 0 }
    private var worked: Double { HoursCalculator.total(weekEntries) }
    private var progress: HoursCalculator.Progress { HoursCalculator.progress(assigned: assigned, worked: worked) }

    private var clientBreakdown: [HoursBreakdown] { HoursCalculator.byClient(weekEntries) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    ProgressRing(progress: progress, tint: .accentColor)
                        .frame(width: 190, height: 190)
                        .padding(.vertical, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SummaryCard(title: "Asignadas", value: Formatters.hours(assigned), systemImage: "target", tint: .blue)
                        SummaryCard(title: "Trabajadas", value: Formatters.hours(worked), systemImage: "clock.fill", tint: .orange)
                        SummaryCard(title: "Restantes", value: Formatters.hours(progress.remaining), systemImage: "hourglass", tint: .green)
                        SummaryCard(
                            title: progress.isOver ? "Exceso" : "Progreso",
                            value: progress.isOver ? "+\(Formatters.hours(progress.overflow))" : "\(Int(progress.fraction * 100)) %",
                            systemImage: progress.isOver ? "exclamationmark.triangle.fill" : "chart.bar.fill",
                            tint: progress.isOver ? .red : .purple
                        )
                    }

                    breakdownSection

                    Button {
                        showingNewEntry = true
                    } label: {
                        Label("Registrar horas", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Inicio")
            .sheet(isPresented: $showingNewEntry) {
                TimeEntryFormView()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Semana actual")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(weekInterval.shortRangeLabel)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Por cliente / departamento")
                .font(.headline)
            if clientBreakdown.isEmpty {
                Text("Aún no has registrado horas esta semana.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(clientBreakdown) { item in
                    BreakdownRow(item: item, maxHours: clientBreakdown.first?.hours ?? 1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
