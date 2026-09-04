import AppIntents
import ActivityKit

// MARK: - Botones de la Live Activity / Dynamic Island

/// Inicia (o reanuda) el cronómetro desde la pantalla de bloqueo, sin abrir la app.
struct StartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Iniciar cronómetro"
    static var description = IntentDescription("Inicia el cronómetro de horas laborales.")

    func perform() async throws -> some IntentResult {
        SharedTimerStore.start()
        TimerLiveActivityController.start()
        return .result()
    }
}

/// Pausa el cronómetro desde la pantalla de bloqueo, sin abrir la app.
struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pausar cronómetro"
    static var description = IntentDescription("Pausa el cronómetro de horas laborales.")

    func perform() async throws -> some IntentResult {
        SharedTimerStore.pause()
        TimerLiveActivityController.update(isRunning: false)
        return .result()
    }
}

/// Pone a cero el cronómetro y cierra la Live Activity, sin abrir la app.
struct ResetTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Reiniciar cronómetro"
    static var description = IntentDescription("Pone a cero el cronómetro de horas laborales.")

    func perform() async throws -> some IntentResult {
        SharedTimerStore.reset()
        TimerLiveActivityController.end()
        return .result()
    }
}

// MARK: - Widget de Centro de Control

/// Enciende o apaga el cronómetro desde el widget de Centro de Control.
struct ToggleTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Cronómetro"

    @Parameter(title: "En marcha")
    var value: Bool

    init() {}

    init(_ value: Bool) {
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        if value {
            SharedTimerStore.start()
            TimerLiveActivityController.start()
        } else {
            SharedTimerStore.pause()
            TimerLiveActivityController.update(isRunning: false)
        }
        return .result()
    }
}
