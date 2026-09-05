import Foundation
import ActivityKit

/// Arranca, actualiza y termina la Live Activity del cronómetro.
/// La usan tanto la app como los App Intents del widget, para que cualquiera
/// de los dos procesos pueda reflejar el estado en la pantalla de bloqueo.
/// Este archivo debe estar incluido también en el target del Widget Extension.
enum TimerLiveActivityController {

    // MARK: - API síncrona (uso desde la app; el proceso sigue vivo, así que
    // no hace falta esperar a que termine la actualización de la Live Activity)

    static func start(projectName: String = "", clientName: String = "") {
        Task { await startAndWait(projectName: projectName, clientName: clientName) }
    }

    static func update(isRunning: Bool, projectName: String = "", clientName: String = "") {
        Task { await updateAndWait(isRunning: isRunning, projectName: projectName, clientName: clientName) }
    }

    static func end() {
        Task { await endAndWait() }
    }

    /// Hace que la Live Activity refleje el estado de `SharedTimerStore`:
    /// la crea si falta (p. ej. tras reinstalar o forzar el cierre de la app con
    /// el cronómetro en marcha), la actualiza si existe y la termina si el
    /// cronómetro está a cero. Pensada para llamarse al pasar la app a primer plano.
    static func syncWithStore() {
        Task { await syncWithStoreAndWait() }
    }

    // MARK: - API asíncrona (uso desde App Intents de la pantalla de bloqueo
    // / Centro de Control: hay que esperar (`await`) el resultado dentro de
    // `perform()`, porque en cuanto el intent retorna, el sistema puede
    // suspender el proceso de la extensión y cancelar cualquier tarea en
    // segundo plano que aún no haya terminado, dejando la Live Activity sin
    // actualizar).

    static func startAndWait(projectName: String = "", clientName: String = "") async {
        await serialized {
            if let existing = currentActivity {
                log("Ya existe la actividad \(existing.id) (estado \(existing.activityState)); se actualiza")
                await applyUpdate(to: existing, isRunning: true, projectName: projectName, clientName: clientName)
            } else {
                await request(isRunning: true, projectName: projectName, clientName: clientName)
            }
        }
    }

    static func updateAndWait(isRunning: Bool, projectName: String = "", clientName: String = "") async {
        await serialized {
            guard let activity = currentActivity else { return }
            await applyUpdate(to: activity, isRunning: isRunning, projectName: projectName, clientName: clientName)
        }
    }

    static func endAndWait() async {
        await serialized {
            guard #available(iOS 16.2, *) else { return }
            for activity in Activity<TimerActivityAttributes>.activities {
                log("Terminando la actividad \(activity.id)")
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    static func syncWithStoreAndWait() async {
        await serialized {
            let isRunning = SharedTimerStore.isRunning
            let hasContent = isRunning || SharedTimerStore.base > 0
            if let activity = currentActivity {
                if hasContent {
                    await applyUpdate(to: activity, isRunning: isRunning, projectName: "", clientName: "")
                } else {
                    log("Cronómetro a cero; terminando la actividad \(activity.id)")
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            } else if hasContent {
                log("Cronómetro con tiempo pero sin Live Activity; se crea")
                await request(isRunning: isRunning, projectName: "", clientName: "")
            }
        }
    }

    // MARK: - Implementación

    @available(iOS 16.2, *)
    private static var currentActivity: Activity<TimerActivityAttributes>? {
        Activity<TimerActivityAttributes>.activities.first
    }

    @available(iOS 16.2, *)
    private static func request(isRunning: Bool, projectName: String, clientName: String) async {
        let auth = ActivityAuthorizationInfo()
        guard auth.areActivitiesEnabled else {
            log("Live Activities desactivadas en Ajustes para esta app; no se crea la actividad")
            return
        }
        let content = ActivityContent(
            state: makeContentState(isRunning: isRunning, projectName: projectName, clientName: clientName),
            staleDate: nil
        )
        do {
            let activity = try Activity.request(attributes: TimerActivityAttributes(), content: content)
            log("Actividad creada \(activity.id) (estado \(activity.activityState))")
            Task {
                for await state in activity.activityStateUpdates {
                    log("Actividad \(activity.id) cambió a estado \(state)")
                }
            }
        } catch {
            log("Error al crear la actividad: \(error)")
        }
    }

    @available(iOS 16.2, *)
    private static func applyUpdate(
        to activity: Activity<TimerActivityAttributes>,
        isRunning: Bool,
        projectName: String,
        clientName: String
    ) async {
        let content = ActivityContent(
            state: makeContentState(isRunning: isRunning, projectName: projectName, clientName: clientName),
            staleDate: nil
        )
        await activity.update(content)
    }

    /// Encadena las operaciones sobre la Live Activity para que dos llamadas
    /// concurrentes (p. ej. un intent del widget y la app al volver a primer
    /// plano) no creen dos actividades a la vez.
    private static var lastOperation: Task<Void, Never>?

    private static func serialized(_ operation: @escaping () async -> Void) async {
        let previous = lastOperation
        let task = Task {
            await previous?.value
            await operation()
        }
        lastOperation = task
        await task.value
    }

    private static func log(_ message: String) {
        // stderr no tiene búfer: las trazas se ven al instante en la consola del dispositivo.
        FileHandle.standardError.write(Data("[LiveActivity] \(message)\n".utf8))
    }

    @available(iOS 16.2, *)
    private static func makeContentState(
        isRunning: Bool,
        projectName: String,
        clientName: String
    ) -> TimerActivityAttributes.ContentState {
        // effectiveStartDate es la fecha desde la que Text(timerInterval:) muestra el tiempo total.
        // Matemática: now - effectiveStart = base + (now - startDate) = tiempo total transcurrido.
        let effectiveStart: Date? = isRunning
            ? SharedTimerStore.startDate?.addingTimeInterval(-SharedTimerStore.base)
            : nil
        return TimerActivityAttributes.ContentState(
            effectiveStartDate: effectiveStart,
            isRunning: isRunning,
            pausedElapsed: SharedTimerStore.base,
            projectName: projectName,
            clientName: clientName
        )
    }
}
