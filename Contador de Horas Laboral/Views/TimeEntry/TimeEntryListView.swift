import SwiftUI
import SwiftData

/// Historial de registros. Agrupa por día, permite filtrar por cliente
/// y proyecto, y editar/eliminar cada entrada.
struct TimeEntryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\TimeEntry.date, order: .reverse),
                  SortDescriptor(\TimeEntry.createdAt, order: .reverse)]) private var entries: [TimeEntry]
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showingNewEntry = false
    @State private var editingEntry: TimeEntry?
    @State private var filterClient: Client?
    @State private var filterProject: Project?

    // MARK: – Cronómetro
    @State private var timerRunning = false
    @State private var timerStart: Date? = nil
    @State private var timerBase: TimeInterval = 0
    @State private var timerDisplayed: TimeInterval = 0
    @State private var showingSaveTimer = false

    private let timerPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: – Datos filtrados

    private var filtered: [TimeEntry] {
        var result = entries
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
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyStateView(
                        systemImage: "clock.badge.questionmark",
                        title: "Sin registros",
                        message: "Empieza registrando las horas que trabajas cada día.",
                        actionTitle: "Registrar horas",
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
                                                Label("Borrar", systemImage: "trash")
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
            .navigationTitle("Registros")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewEntry = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNewEntry) { TimeEntryFormView() }
            .sheet(item: $editingEntry) { entry in TimeEntryFormView(entry: entry) }
            .sheet(isPresented: $showingSaveTimer) {
                TimeEntryFormView(
                    initialHours: timerDisplayed / 3600,
                    onSave: { resetTimer() }
                )
            }
            .onReceive(timerPublisher) { _ in
                guard timerRunning, let start = timerStart else { return }
                timerDisplayed = timerBase + Date().timeIntervalSince(start)
            }
        }
    }

    // MARK: – Timer banner

    private var timerBanner: some View {
        HStack(spacing: 12) {
            // Indicador / icono
            if timerRunning {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: "timer")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Tiempo transcurrido o etiqueta
            Text(timerDisplayed > 0 || timerRunning
                 ? formatTimer(timerDisplayed)
                 : "Cronómetro")
                .font(timerDisplayed > 0 || timerRunning
                      ? .system(.body, design: .monospaced).weight(.semibold)
                      : .body)
                .monospacedDigit()
                .foregroundStyle(timerDisplayed == 0 && !timerRunning ? .secondary : .primary)
                .contentTransition(.numericText())

            Spacer()

            // Controles según estado
            if timerRunning {
                Button { pauseTimer() } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if timerDisplayed > 0 {
                Button { resetTimer() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button { startTimer() } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.bordered)

                Button("Guardar") { showingSaveTimer = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Button { startTimer() } label: {
                    Label("Iniciar", systemImage: "play.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .animation(.default, value: timerRunning)
        .animation(.default, value: timerDisplayed > 0)
    }

    // MARK: – Timer actions

    private func startTimer() {
        timerStart = Date()
        timerRunning = true
    }

    private func pauseTimer() {
        if let start = timerStart {
            timerBase += Date().timeIntervalSince(start)
        }
        timerStart = nil
        timerRunning = false
        timerDisplayed = timerBase
    }

    private func resetTimer() {
        timerRunning = false
        timerStart = nil
        timerBase = 0
        timerDisplayed = 0
    }

    private func formatTimer(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: – Filtro

    private var filterMenu: some View {
        Menu {
            Picker("Cliente", selection: $filterClient) {
                Text("Todos los clientes").tag(Client?.none)
                ForEach(clients) { Text($0.name).tag(Client?.some($0)) }
            }
            Picker("Proyecto", selection: $filterProject) {
                Text("Todos los proyectos").tag(Project?.none)
                ForEach(projects) { Text($0.name).tag(Project?.some($0)) }
            }
            if filterClient != nil || filterProject != nil {
                Button("Quitar filtros", role: .destructive) {
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

    var body: some View {
        HStack(spacing: 12) {
            ColorDot(hex: entry.project?.colorHex ?? entry.client?.colorHex ?? "#8E8E93", size: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.project?.name ?? entry.client?.name ?? "Sin asignar")
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
}
