import Foundation
import ActivityKit

/// Arranca, actualiza y termina la Live Activity del cronómetro.
/// La usan tanto la app como los App Intents del widget, para que cualquiera
/// de los dos procesos pueda reflejar el estado en la pantalla de bloqueo.
/// Este archivo debe estar incluido también en el target del Widget Extension.
enum TimerLiveActivityController {
    static func start(projectName: String = "", clientName: String = "") {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if Activity<TimerActivityAttributes>.activities.first != nil {
            update(isRunning: true, projectName: projectName, clientName: clientName)
            return
        }

        let content = ActivityContent(
            state: makeContentState(isRunning: true, projectName: projectName, clientName: clientName),
            staleDate: nil
        )
        do {
            _ = try Activity.request(attributes: TimerActivityAttributes(), content: content)
        } catch {
            print("Live Activity start error: \(error)")
        }
    }

    static func update(isRunning: Bool, projectName: String = "", clientName: String = "") {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = Activity<TimerActivityAttributes>.activities.first else { return }
        let content = ActivityContent(
            state: makeContentState(isRunning: isRunning, projectName: projectName, clientName: clientName),
            staleDate: nil
        )
        Task { await activity.update(content) }
    }

    static func end() {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = Activity<TimerActivityAttributes>.activities.first else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
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
