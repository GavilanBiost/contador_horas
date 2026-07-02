import SwiftUI
import SwiftData

/// Gestión de clientes / departamentos: crear, editar y eliminar.
struct ClientListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var showingForm = false
    @State private var editingClient: Client?

    var body: some View {
        Group {
            if clients.isEmpty {
                EmptyStateView(
                    systemImage: "person.2.fill",
                    title: "Sin clientes",
                    message: "Crea tu primer cliente o departamento para organizar tus horas.",
                    actionTitle: "Nuevo cliente",
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
                                    Text("\(client.projects.count) proyecto(s)")
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
        .navigationTitle("Clientes")
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
}
