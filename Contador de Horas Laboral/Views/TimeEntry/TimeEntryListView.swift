import SwiftUI
import SwiftData

struct TimeEntryListView: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerManager.self) private var timerManager
    @Environment(LanguageManager.self) private var lang

    @Query(sort: [SortDescriptor(\TimeEntry.date, order: .reverse),
                  SortDescriptor(\TimeEntry.createdAt, order: .reverse)]) private var entries: [TimeEntry]
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showingNewEntry = false
    @State private var editingEntry: TimeEntry?
    @State private var filterClient: Client?
    @State private var filterProject: Project?

    private var twoWeekInterval: DateInterval {
        let thisWeek = Date().interval(of: .week)
        let prevWeek = Date().adding(-1, .week).interval(of: .week)
        return DateInterval(start: prevWeek.start, end: thisWeek.end)
    }

    private var filtered: [TimeEntry] {
        var result = HoursCalculator.entries(entries, in: twoWeekInterval)
        result = HoursCalculator.filter(result, client: filterClient)
        result = HoursCalculator.filter(result, project: filterProject)
        return result
    }

    private var grouped: [(day: Date, items: [TimeEntry])] {
        let dict = Dictionary(grouping: filtered) { $0.date.startOfDay() }
        return dict.map { (day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        @Bindable var manager = timerManager
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyStateView(
                        systemImage: "clock.badge.questionmark",
                        title: lang["entries.empty_title"],
                        message: lang["entries.empty_message"],
                        actionTitle: lang["entries.record"],
                        action: { showingNewEntry = true }
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.day) { group in
                            Section {
                                ForEach(group.items) { entry in
                                    EntryRow(entry: entry)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingEntry = entry }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                context.delete(entry)
                                                try? context.save()
                                            } label: {
                                                Label(lang["entries.delete"], systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                HStack {
                                    Text(Formatters.dayFull.string(from: group.day).capitalized)
                                    Spacer()
                                    Text(Formatters.hours(HoursCalculator.total(group.items)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                timerBanner
            }
            .navigationTitle(lang["tab.records"])
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewEntry = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNewEntry) { TimeEntryFormView() }
            .sheet(item: $editingEntry) { entry in TimeEntryFormView(entry: entry) }
            .sheet(isPresented: $manager.showingSaveTimer) {
                TimeEntryFormView(
                    initialHours: timerManager.timerDisplayed / 3600,
                    onSave: { timerManager.resetTimer() }
                )
            }
        }
    }

    // MARK: – Timer banner

    private var timerBanner: some View {
        HStack(spacing: 12) {
            if timerManager.timerRunning {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: "timer")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(timerManager.timerDisplayed > 0 || timerManager.timerRunning
                 ? timerManager.formatTimer()
                 : lang["dash.timer"])
                .font(timerManager.timerDisplayed > 0 || timerManager.timerRunning
                      ? .system(.body, design: .monospaced).weight(.semibold)
                      : .body)
                .monospacedDigit()
                .foregroundStyle(timerManager.timerDisplayed == 0 && !timerManager.timerRunning ? .secondary : .primary)
                .contentTransition(.numericText())

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .animation(.default, value: timerManager.timerRunning)
        .animation(.default, value: timerManager.timerDisplayed > 0)
    }

    // MARK: – Filtro

    private var filterMenu: some View {
        Menu {
            Picker(lang["form.client_picker"], selection: $filterClient) {
                Text(lang["entries.all_clients"]).tag(Client?.none)
                ForEach(clients) { Text($0.name).tag(Client?.some($0)) }
            }
            Picker(lang["form.project_picker"], selection: $filterProject) {
                Text(lang["entries.all_projects"]).tag(Project?.none)
                ForEach(projects) { Text($0.name).tag(Project?.some($0)) }
            }
            if filterClient != nil || filterProject != nil {
                Button(lang["entries.clear_filters"], role: .destructive) {
                    filterClient = nil; filterProject = nil
                }
            }
        } label: {
            Image(systemName: (filterClient != nil || filterProject != nil)
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - Fila de registro

private struct EntryRow: View {
    let entry: TimeEntry
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        HStack(spacing: 12) {
            ColorDot(hex: entry.project?.colorHex ?? entry.client?.colorHex ?? "#8E8E93", size: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.project?.name ?? entry.client?.name ?? lang["entries.unassigned"])
                    .font(.body)
                HStack(spacing: 6) {
                    if let client = entry.client {
                        Text(client.name)
                    }
                    if !entry.comment.isEmpty {
                        Text("· \(entry.comment)").lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatters.hours(entry.hours))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    TimeEntryListView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(TimerManager())
        .environment(LanguageManager())
}
