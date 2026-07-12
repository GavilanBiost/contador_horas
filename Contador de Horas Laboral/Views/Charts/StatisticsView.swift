import SwiftUI
import SwiftData
import Charts

private enum Dimension: CaseIterable, Identifiable {
    case client, project
    var id: Self { self }
}

struct StatisticsView: View {
    @Query private var entries: [TimeEntry]
    @Environment(LanguageManager.self) private var lang

    @State private var dimension: Dimension = .client
    @State private var period: Period = .week
    @State private var periodOffset = 0

    private var referenceDate: Date { Date().adding(periodOffset, period) }
    private var interval: DateInterval { referenceDate.interval(of: period) }
    private var periodEntries: [TimeEntry] { HoursCalculator.entries(entries, in: interval) }

    private var breakdown: [HoursBreakdown] {
        switch dimension {
        case .client:  return HoursCalculator.byClient(periodEntries)
        case .project: return HoursCalculator.byProject(periodEntries)
        }
    }

    private var dimensionLabel: String {
        switch dimension {
        case .client:  return lang["stats.client"]
        case .project: return lang["stats.project"]
        }
    }

    private var periodLabel: String {
        switch period {
        case .week:  return lang.shortRange(interval)
        case .month: return lang.monthYear(interval.start)
        case .year:  return "\(Calendar.app.component(.year, from: interval.start))"
        }
    }

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
                    Picker(lang["period.picker"], selection: $period) {
                        Text(lang["period.week"]).tag(Period.week)
                        Text(lang["period.month"]).tag(Period.month)
                        Text(lang["period.year"]).tag(Period.year)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: period) { _, _ in
                        withAnimation { periodOffset = 0 }
                    }

                    periodNavigator

                    if periodEntries.isEmpty {
                        EmptyStateView(
                            systemImage: "chart.pie",
                            title: lang["stats.no_data"],
                            message: lang["stats.no_data_message"]
                        )
                        .frame(height: 260)
                    } else {
                        ChartCard(title: "\(lang["stats.hours_by"]) \(dimensionLabel.lowercased())") {
                            HoursBarChart(data: breakdown)
                        }
                    }

                    ChartCard(title: lang["stats.evolution"]) {
                        EvolutionChart(points: evolution)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lang["tab.charts"])
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(Dimension.allCases) { dim in
                            let label = dim == .client ? lang["stats.client"] : lang["stats.project"]
                            Button {
                                dimension = dim
                            } label: {
                                if dimension == dim {
                                    Label(label, systemImage: "checkmark")
                                } else {
                                    Text(label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(dimensionLabel)
                                .font(.subheadline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    private var periodNavigator: some View {
        HStack {
            Button { withAnimation { periodOffset -= 1 } } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(periodLabel).font(.headline)
                if periodOffset < 0 {
                    Button(lang["stats.current_period"]) { withAnimation { periodOffset = 0 } }
                        .font(.caption)
                } else {
                    Text(lang["stats.current_period"])
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
        .environment(LanguageManager())
}
