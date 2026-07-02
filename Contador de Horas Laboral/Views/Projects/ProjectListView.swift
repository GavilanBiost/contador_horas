import SwiftUI
import SwiftData

/// Gestión de proyectos: crear, editar y eliminar.
struct ProjectListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Client.name) private var clients: [Client]

    @State private var showingForm = false
    @State private var editingProject: Project?

    var body: some View {
        Group {
            if projects.isEmpty {
                EmptyStateView(
                    systemImage: "folder.fill",
                    title: "Sin proyectos",
                    message: clients.isEmpty
                        ? "Crea primero un cliente y luego asígnale proyectos."
                        : "Crea tu primer proyecto y asígnalo a un cliente.",
                    actionTitle: clients.isEmpty ? nil : "Nuevo proyecto",
                    action: clients.isEmpty ? nil : { showingForm = true }
                )
            } else {
                List {
                    ForEach(projects) { project in
                        Button { editingProject = project } label: {
                            HStack(spacing: 12) {
                                ColorDot(hex: project.colorHex, size: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name).foregroundStyle(.primary)
                                    Text(project.client?.name ?? "Sin cliente")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if project.weeklyHours > 0 {
                                    Text(Formatters.hours(project.weeklyHours))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Proyectos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingForm = true } label: { Image(systemName: "plus") }
                    .disabled(clients.isEmpty)
            }
        }
        .sheet(isPresented: $showingForm) { ProjectFormView() }
        .sheet(item: $editingProject) { ProjectFormView(project: $0) }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(projects[index]) }
        try? context.save()
    }
}

#Preview {
    NavigationStack { ProjectListView() }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
