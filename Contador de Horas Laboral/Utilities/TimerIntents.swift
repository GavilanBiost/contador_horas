import AppIntents
import ActivityKit

// IMPORTANTE: este archivo debe estar incluido en DOS targets: la app y el
// Widget Extension (por eso hay una copia idéntica en
// "Contador de Horas Laboral/Utilities/TimerIntents.swift").
//
// Motivo: los intents que conforman `LiveActivityIntent` NO se ejecutan en el
// proceso del widget, sino que el sistema lanza la app en segundo plano y
// ejecuta `perform()` en el proceso de la APP (solo la app puede crear una
// Live Activity con `Activity.request`). Si el tipo del intent no existe en
// los metadatos de App Intents de la app, el botón del widget no hace nada.

// MARK: - Botones de la Live Activity / Dynamic Island

/// Inicia (o reanuda) el cronómetro desde la pantalla de bloqueo, sin abrir la app.
nonisolated struct StartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Iniciar cronómetro"
    static var description = IntentDescription("Inicia el cronómetro de horas laborales.")

    func perform() async throws -> some IntentResult {
        SharedTimerStore.start()
        await TimerLiveActivityController.startAndWait()
        return .result()
    }
}

/// Pausa el cronómetro desde la pantalla de bloqueo, sin abrir la app.
nonisolated struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pausar cronómetro"
    static var description = IntentDescription("Pausa el cronómetro de horas laborales.")

    func perform() async throws -> some IntentResult {
        SharedTimerStore.pause()
        await TimerLiveActivityController.updateAndWait(isRunning: false)
        return .result()
    }
}

// MARK: - Widget de Centro de Control

/// Enciende o apaga el cronómetro desde el widget de Centro de Control.
/// También conforma `LiveActivityIntent` para que se ejecute en la app y pueda
/// crear la Live Activity si todavía no existe.
nonisolated struct ToggleTimerIntent: SetValueIntent, LiveActivityIntent {
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
            await TimerLiveActivityController.startAndWait()
        } else {
            SharedTimerStore.pause()
            await TimerLiveActivityController.updateAndWait(isRunning: false)
        }
        return .result()
    }
}
