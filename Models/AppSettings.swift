import Foundation
import SwiftData

/// Configuración global de la app. Se mantiene como un único registro
/// (singleton) que se crea automáticamente al primer arranque.
@Model
final class AppSettings {
    /// Total de horas semanales que el usuario tiene asignadas en total.
    var totalWeeklyHours: Double

    init(totalWeeklyHours: Double = 40) {
        self.totalWeeklyHours = totalWeeklyHours
    }
}
