import ActivityKit
import Foundation

/// Atributos de la Live Activity del cronómetro.
/// Este archivo debe estar incluido también en el target del Widget Extension.
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Cuando el cronómetro corre: `Date() - effectiveStartDate` = tiempo total transcurrido.
        /// Permite usar `Text(timerInterval:)` en el widget para actualización automática.
        var effectiveStartDate: Date?
        var isRunning: Bool
        /// Tiempo acumulado cuando está en pausa.
        var pausedElapsed: TimeInterval
        var projectName: String
        var clientName: String
    }
}
