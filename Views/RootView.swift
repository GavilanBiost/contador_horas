import SwiftUI
import SwiftData

/// Navegación principal por pestañas.
/// Flujo: Inicio · Semana · Registrar · Estadísticas · Ajustes.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Inicio", systemImage: "house.fill") }

            WeekView()
                .tabItem { Label("Semana", systemImage: "calendar") }

            TimeEntryListView()
                .tabItem { Label("Registros", systemImage: "list.bullet.clipboard") }

            StatisticsView()
                .tabItem { Label("Gráficos", systemImage: "chart.pie.fill") }

            SettingsHubView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
        .onAppear(perform: ensureSettings)
    }

    /// Garantiza que exista un único registro de configuración.
    private func ensureSettings() {
        if settings.isEmpty {
            context.insert(AppSettings())
            try? context.save()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
}
