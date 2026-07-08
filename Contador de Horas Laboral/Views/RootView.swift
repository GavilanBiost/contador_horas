import SwiftUI
import SwiftData

/// Navegación principal por pestañas.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(LanguageManager.self) private var lang
    @Query private var settings: [AppSettings]

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label(lang["tab.home"], systemImage: "house.fill") }

            WeekView()
                .tabItem { Label(lang["tab.week"], systemImage: "calendar") }

            TimeEntryListView()
                .tabItem { Label(lang["tab.records"], systemImage: "list.bullet.clipboard") }

            StatisticsView()
                .tabItem { Label(lang["tab.charts"], systemImage: "chart.pie.fill") }

            SettingsHubView()
                .tabItem { Label(lang["tab.settings"], systemImage: "gearshape.fill") }
        }
        .environment(\.locale, lang.locale)
        .onAppear(perform: ensureSettings)
    }

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
        .environment(LanguageManager())
}
