import SwiftUI
import SwiftData
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - TimerManager

/// Estado del cronómetro. Se apoya en `SharedTimerStore` (App Group) para que
/// el widget, el Centro de Control y la Live Activity puedan iniciarlo, pausarlo
/// o reiniciarlo aunque la app esté cerrada, y para que la app refleje esos
/// cambios en cuanto vuelve a primer plano (ver `syncFromStore()`).
@Observable
final class TimerManager {
    private(set) var timerRunning = false
    var timerDisplayed: TimeInterval = 0
    var showingSaveTimer = false

    private var ticker: Timer?
    private var storeObserver: NSObjectProtocol?

    init() {
        syncFromStore()

        // Los botones del widget, la Live Activity y el Centro de Control son
        // `LiveActivityIntent`, así que se ejecutan en el proceso de la app de
        // forma asíncrona, a veces con la app ya en primer plano (o justo
        // después de que la escena vuelva a estar activa). El cambio de
        // `scenePhase` no basta para verlos: nos avisa el propio store.
        SharedTimerStore.startObservingChanges()
        storeObserver = NotificationCenter.default.addObserver(
            forName: SharedTimerStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncFromStore()
            }
        }
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    /// Vuelve a leer el estado compartido. Se llama al reactivar la app y cada
    /// vez que el store avisa de un cambio, por si el widget, el Control o la
    /// Live Activity cambiaron el cronómetro.
    func syncFromStore() {
        timerRunning = SharedTimerStore.isRunning
        timerDisplayed = SharedTimerStore.elapsed
        if timerRunning {
            startTicking()
        } else {
            stopTicking()
        }
    }

    func startTimer() {
        SharedTimerStore.start()
        timerRunning = true
        timerDisplayed = SharedTimerStore.elapsed
        startTicking()
        TimerLiveActivityController.start()
    }

    func pauseTimer() {
        SharedTimerStore.pause()
        timerRunning = false
        timerDisplayed = SharedTimerStore.elapsed
        stopTicking()
        TimerLiveActivityController.update(isRunning: false)
    }

    func resetTimer() {
        stopTicking()
        SharedTimerStore.reset()
        timerRunning = false
        timerDisplayed = 0
        showingSaveTimer = false
        TimerLiveActivityController.end()
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
            self?.timerDisplayed = SharedTimerStore.elapsed
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
    let calendarService = GoogleCalendarService()
    let languageManager = LanguageManager()
    @Environment(\.scenePhase) private var scenePhase

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
                .onOpenURL { url in
                    if url.scheme == "contadorhoras" {
                        if url.host == "guardar" {
                            timerManager.showingSaveTimer = true
                        }
                        return
                    }
#if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
#endif
                }
        }
        .modelContainer(container)
        .environment(timerManager)
        .environment(calendarService)
        .environment(languageManager)
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if newPhase == .active {
                timerManager.syncFromStore()
                // Si la Live Activity desapareció (reinstalación, cierre forzado,
                // caducidad) pero el cronómetro sigue con tiempo, se recrea.
                TimerLiveActivityController.syncWithStore()
            }
        }
    }
}
