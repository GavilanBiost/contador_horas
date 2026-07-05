import SwiftUI
import SwiftData

// MARK: - TimerManager

/// Estado compartido del cronómetro. Se persiste en UserDefaults para que
/// siga contando aunque la app se cierre y se vuelva a abrir.
@Observable
final class TimerManager {
    private(set) var timerRunning = false
    var timerDisplayed: TimeInterval = 0
    var showingSaveTimer = false

    private var base: TimeInterval = 0     // tiempo acumulado antes de la última pausa
    private var startDate: Date?           // cuándo se inició la sesión actual
    private var ticker: Timer?

    private enum Keys {
        static let start = "timer.start"
        static let base  = "timer.base"
    }

    init() {
        base = UserDefaults.standard.double(forKey: Keys.base)
        startDate = UserDefaults.standard.object(forKey: Keys.start) as? Date

        if let start = startDate {
            timerRunning = true
            timerDisplayed = base + Date().timeIntervalSince(start)
            startTicking()
        } else {
            timerDisplayed = base
        }
    }

    func startTimer() {
        let now = Date()
        startDate = now
        UserDefaults.standard.set(now, forKey: Keys.start)
        timerRunning = true
        startTicking()
    }

    func pauseTimer() {
        if let start = startDate {
            base += Date().timeIntervalSince(start)
        }
        startDate = nil
        timerRunning = false
        timerDisplayed = base
        UserDefaults.standard.set(base, forKey: Keys.base)
        UserDefaults.standard.removeObject(forKey: Keys.start)
        stopTicking()
    }

    func resetTimer() {
        stopTicking()
        startDate = nil
        base = 0
        timerRunning = false
        timerDisplayed = 0
        showingSaveTimer = false
        UserDefaults.standard.removeObject(forKey: Keys.start)
        UserDefaults.standard.removeObject(forKey: Keys.base)
    }

    func formatTimer() -> String {
        let total = Int(timerDisplayed)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            self.timerDisplayed = self.base + Date().timeIntervalSince(start)
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}

// MARK: - App

@main
struct HourTrackerApp: App {
    let timerManager = TimerManager()

    let container: ModelContainer = {
        let schema = Schema([Client.self, Project.self, TimeEntry.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Cambio de schema incompatible con el store existente → borra y recrea.
            let storeDir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let exts = ["sqlite", "sqlite-wal", "sqlite-shm"]
            if let files = try? FileManager.default.contentsOfDirectory(
                at: storeDir, includingPropertiesForKeys: nil
            ) {
                files
                    .filter { exts.contains($0.pathExtension) }
                    .forEach { try? FileManager.default.removeItem(at: $0) }
            }
            return try! ModelContainer(for: schema, configurations: [config])
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(timerManager)
    }
}
