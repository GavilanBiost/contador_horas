import SwiftUI
import SwiftData

struct ClientListView: View {
    @Environment(\.modelContext) private var context
    @Environment(LanguageManager.self) private var lang
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var showingForm = false
    @State private var editingClient: Client?

    var body: some View {
        Group {
            if clients.isEmpty {
                EmptyStateView(
                    systemImage: "person.2.fill",
                    title: lang["clients.empty_title"],
                    message: lang["clients.empty_message"],
                    actionTitle: lang["clients.add"],
                    action: { showingForm = true }
                )
            } else {
                List {
                    ForEach(clients) { client in
                        Button { editingClient = client } label: {
                            HStack(spacing: 12) {
                                ColorDot(hex: client.colorHex, size: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.name).foregroundStyle(.primary)
                                    let count = client.projects.count
                                    Text("\(count) \(count == 1 ? lang["clients.projects_one"] : lang["clients.projects_many"])")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if client.weeklyHours > 0 {
                                    Text(Formatters.hours(client.weeklyHours))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle(lang["clients.title"])
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingForm) { ClientFormView() }
        .sheet(item: $editingClient) { ClientFormView(client: $0) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(clients[index]) }
        try? context.save()
    }
}

#Preview {
    NavigationStack { ClientListView() }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(LanguageManager())
}
