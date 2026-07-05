import SwiftUI
import SwiftData
import Charts

/// Dimensión de análisis: por cliente o por proyecto.
private enum Dimension: String, CaseIterable, Identifiable {
    case client = "Cliente"
    case project = "Proyecto"
    var id: String { rawValue }
}

/// Pantalla de gráficos y estadísticas.
/// Permite elegir dimensión (cliente/proyecto) y periodo (semana/mes/año).
struct StatisticsView: View {
    @Query private var entries: [TimeEntry]
    @Query private var settings: [AppSettings]

    @State private var dimension: Dimension = .client
    @State private var period: Period = .week

    // MARK: Datos derivados

    private var interval: DateInterval { Date().interval(of: period) }
    private var periodEntries: [TimeEntry] { HoursCalculator.entries(entries, in: interval) }

    private var breakdown: [HoursBreakdown] {
        switch dimension {
        case .client:  return HoursCalculator.byClient(periodEntries)
        case .project: return HoursCalculator.byProject(periodEntries)
        }
    }

    /// Horas asignadas para el periodo (escaladas desde el total semanal).
    private var assignedForPeriod: Double {
        let weekly = settings.first?.totalWeeklyHours ?? 0
        switch period {
        case .week:  return weekly
        case .month: return weekly * 4.345   // ~semanas por mes
        case .year:  return weekly * 52
        }
    }

    private var workedForPeriod: Double { HoursCalculator.total(periodEntries) }

    /// Evolución: últimos N periodos.
    private var evolution: [EvolutionPoint] {
        let count: Int = switch period {
        case .week: 8
        case .month: 6
        case .year: 4
        }
        return HoursCalculator.evolution(entries, period: period, count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Periodo", selection: $period) {
                        ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Picker("Dimensión", selection: $dimension) {
                        ForEach(Dimension.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if periodEntries.isEmpty {
                        EmptyStateView(
                            systemImage: "chart.pie",
                            title: "Sin datos",
                            message: "Registra horas para ver tus estadísticas en este periodo."
                        )
                        .frame(height: 320)
                    } else {
                        ChartCard(title: "Reparto por \(dimension.rawValue.lowercased())") {
                            HoursPieChart(data: breakdown)
                        }

                        ChartCard(title: "Horas por \(dimension.rawValue.lowercased())") {
                            HoursBarChart(data: breakdown)
                        }

                        ChartCard(title: "Asignadas vs. trabajadas") {
                            AssignedVsWorkedChart(assigned: assignedForPeriod, worked: workedForPeriod)
                            Text("Periodo: \(period.rawValue.lowercased())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ChartCard(title: "Evolución de horas trabajadas") {
                        EvolutionChart(points: evolution)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Gráficos")
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
