import SwiftUI
import SwiftData

/// Vista semanal: permite navegar entre semanas y ver el desglose
/// por cliente y por proyecto, además del progreso frente a lo asignado.
struct WeekView: View {
    @Query private var entries: [TimeEntry]
    @Query private var settings: [AppSettings]

    /// Desplazamiento en semanas respecto a la actual (0 = esta semana).
    @State private var weekOffset = 0

    private var referenceDate: Date { Date().adding(weekOffset, .week) }
    private var interval: DateInterval { referenceDate.interval(of: .week) }
    private var weekEntries: [TimeEntry] { HoursCalculator.entries(entries, in: interval) }

    private var assigned: Double { settings.first?.totalWeeklyHours ?? 0 }
    private var worked: Double { HoursCalculator.total(weekEntries) }
    private var progress: HoursCalculator.Progress { HoursCalculator.progress(assigned: assigned, worked: worked) }

    private var byClient: [HoursBreakdown] { HoursCalculator.byClient(weekEntries) }
    private var byProject: [HoursBreakdown] { HoursCalculator.byProject(weekEntries) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weekNavigator

                    HoursProgressBar(progress: progress)
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SummaryCard(title: "Asignadas", value: Formatters.hours(assigned), tint: .blue)
                        SummaryCard(title: "Trabajadas", value: Formatters.hours(worked), tint: .orange)
                        SummaryCard(title: "Restantes", value: Formatters.hours(progress.remaining), tint: .green)
                    }

                    breakdownCard(title: "Por cliente / departamento", items: byClient)
                    breakdownCard(title: "Por proyecto", items: byProject)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Semana")
        }
    }

    private var weekNavigator: some View {
        HStack {
            Button { withAnimation { weekOffset -= 1 } } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(interval.shortRangeLabel)
                    .font(.headline)
                if weekOffset == 0 {
                    Text("Esta semana").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Volver a hoy") { withAnimation { weekOffset = 0 } }
                        .font(.caption)
                }
            }
            Spacer()
            Button { withAnimation { weekOffset += 1 } } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func breakdownCard(title: String, items: [HoursBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if items.isEmpty {
                Text("Sin registros en esta semana.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    BreakdownRow(item: item, maxHours: items.first?.hours ?? 1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    WeekView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
