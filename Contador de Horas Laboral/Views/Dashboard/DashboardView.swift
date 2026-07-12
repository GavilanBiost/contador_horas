import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var entries: [TimeEntry]
    @Query private var settings: [AppSettings]
    @Query(sort: \Client.name) private var clients: [Client]

    @Environment(TimerManager.self) private var timerManager
    @Environment(LanguageManager.self) private var lang
    @State private var showingNewEntry = false

    private var weekInterval: DateInterval { Date().interval(of: .week) }
    private var weekEntries: [TimeEntry] { HoursCalculator.entries(entries, in: weekInterval) }
    private var assigned: Double { settings.first?.totalWeeklyHours ?? 0 }
    private var worked: Double { HoursCalculator.total(weekEntries) }
    private var progress: HoursCalculator.Progress { HoursCalculator.progress(assigned: assigned, worked: worked) }
    private var clientBreakdown: [HoursBreakdown] { HoursCalculator.byClient(weekEntries) }

    var body: some View {
        @Bindable var manager = timerManager
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timerCard
                    header

                    ProgressRing(progress: progress, tint: .accentColor)
                        .frame(width: 190, height: 190)
                        .padding(.vertical, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SummaryCard(title: lang["dash.assigned"], value: Formatters.hours(assigned), systemImage: "target", tint: .blue)
                        SummaryCard(title: lang["dash.worked"], value: Formatters.hours(worked), systemImage: "clock.fill", tint: .orange)
                        SummaryCard(title: lang["dash.remaining"], value: Formatters.hours(progress.remaining), systemImage: "hourglass", tint: .green)
                        SummaryCard(
                            title: progress.isOver ? lang["dash.excess"] : lang["dash.progress"],
                            value: progress.isOver ? "+\(Formatters.hours(progress.overflow))" : "\(Int(progress.fraction * 100)) %",
                            systemImage: progress.isOver ? "exclamationmark.triangle.fill" : "chart.bar.fill",
                            tint: progress.isOver ? .red : .purple
                        )
                    }

                    breakdownSection

                    Button {
                        showingNewEntry = true
                    } label: {
                        Label(lang["dash.record_hours"], systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(lang["tab.home"])
            .sheet(isPresented: $showingNewEntry) {
                TimeEntryFormView()
            }
            .sheet(isPresented: $manager.showingSaveTimer) {
                TimeEntryFormView(
                    initialHours: timerManager.timerDisplayed / 3600,
                    onSave: { timerManager.resetTimer() }
                )
            }
        }
    }

    // MARK: – Timer card

    private var timerCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(lang["dash.timer"])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if timerManager.timerRunning {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                    }
                    Text(timerManager.timerDisplayed > 0 || timerManager.timerRunning
                         ? timerManager.formatTimer()
                         : "--:--")
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            Spacer()

            if timerManager.timerRunning {
                Button { timerManager.pauseTimer() } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if timerManager.timerDisplayed > 0 {
                Button { timerManager.resetTimer() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button { timerManager.startTimer() } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.bordered)

                Button(lang["dash.save"]) { timerManager.showingSaveTimer = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Button { timerManager.startTimer() } label: {
                    Label(lang["dash.start"], systemImage: "play.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.default, value: timerManager.timerRunning)
        .animation(.default, value: timerManager.timerDisplayed > 0)
    }

    // MARK: – Header

    private var header: some View {
        VStack(spacing: 4) {
            Text(lang["dash.current_week"])
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(lang.shortRange(weekInterval))
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – Breakdown

    @ViewBuilder
    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang["dash.by_client"])
                .font(.headline)
            if clientBreakdown.isEmpty {
                Text(lang["dash.no_hours"])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(clientBreakdown) { item in
                    ClientProgressRow(
                        item: item,
                        assigned: clients.first { $0.name == item.name }?.weeklyHours ?? 0,
                        maxHours: clientBreakdown.first?.hours ?? 1
                    )
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
        .environment(TimerManager())
        .environment(LanguageManager())
}
