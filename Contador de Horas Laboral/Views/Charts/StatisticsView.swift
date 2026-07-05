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
/// Permite elegir dimensión (cliente/proyecto) y navegar entre periodos pasados.
struct StatisticsView: View {
    @Query private var entries: [TimeEntry]

    @State private var dimension: Dimension = .client
    @State private var period: Period = .week
    @State private var periodOffset = 0

    // MARK: Datos derivados

    private var referenceDate: Date { Date().adding(periodOffset, period) }
    private var interval: DateInterval { referenceDate.interval(of: period) }
    private var periodEntries: [TimeEntry] { HoursCalculator.entries(entries, in: interval) }

    private var breakdown: [HoursBreakdown] {
        switch dimension {
        case .client:  return HoursCalculator.byClient(periodEntries)
        case .project: return HoursCalculator.byProject(periodEntries)
        }
    }

    private var periodLabel: String {
        switch period {
        case .week:  return interval.shortRangeLabel
        case .month: return Formatters.monthYear.string(from: interval.start).capitalized
        case .year:  return "\(Calendar.app.component(.year, from: interval.start))"
        }
    }

    /// Evolución: últimos N periodos desde hoy (independiente del offset).
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
                    .onChange(of: period) { _, _ in
                        withAnimation { periodOffset = 0 }
                    }

                    periodNavigator

                    if periodEntries.isEmpty {
                        EmptyStateView(
                            systemImage: "chart.pie",
                            title: "Sin datos",
                            message: "No hay registros en este periodo."
                        )
                        .frame(height: 260)
                    } else {
                        ChartCard(title: "Horas por \(dimension.rawValue.lowercased())") {
                            HoursBarChart(data: breakdown)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(Dimension.allCases) { dim in
                            Button {
                                dimension = dim
                            } label: {
                                if dimension == dim {
                                    Label(dim.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(dim.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(dimension.rawValue)
                                .font(.subheadline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    // MARK: – Period navigator

    private var periodNavigator: some View {
        HStack {
            Button { withAnimation { periodOffset -= 1 } } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(periodLabel).font(.headline)
                if periodOffset < 0 {
                    Button("Periodo actual") { withAnimation { periodOffset = 0 } }
                        .font(.caption)
                } else {
                    Text("Periodo actual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { withAnimation { periodOffset += 1 } } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
            .disabled(periodOffset >= 0)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
