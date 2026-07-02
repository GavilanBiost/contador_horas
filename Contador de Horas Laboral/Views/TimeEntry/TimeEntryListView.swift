import SwiftUI
import SwiftData

/// Historial de registros. Agrupa por día, permite filtrar por cliente
/// y proyecto, y editar/eliminar cada entrada.
struct TimeEntryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]
    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showingNewEntry = false
    @State private var editingEntry: TimeEntry?
    @State private var filterClient: Client?
    @State private var filterProject: Project?

    private var filtered: [TimeEntry] {
        var result = entries
        result = HoursCalculator.filter(result, client: filterClient)
        result = HoursCalculator.filter(result, project: filterProject)
        return result
    }

    /// Registros agrupados por día (inicio de día), ordenados desc.
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
                                }
                                .onDelete { offsets in delete(group.items, at: offsets) }
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
            .navigationTitle("Registros")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewEntry = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingNewEntry) { TimeEntryFormView() }
            .sheet(item: $editingEntry) { entry in TimeEntryFormView(entry: entry) }
        }
    }

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
            Image(systemName: (filterClient != nil || filterProject != nil) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private func delete(_ items: [TimeEntry], at offsets: IndexSet) {
        for index in offsets { context.delete(items[index]) }
        try? context.save()
    }
}

/// Fila individual de un registro de horas.
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
