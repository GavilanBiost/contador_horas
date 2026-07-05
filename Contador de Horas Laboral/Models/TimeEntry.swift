import Foundation
import SwiftData

/// Representa un **registro diario de horas trabajadas**.
/// Es la unidad básica de cálculo de toda la app.
@Model
final class TimeEntry {
    /// Día al que corresponde el trabajo.
    var date: Date

    /// Número de horas trabajadas (puede tener decimales: 1.5, 0.25, …).
    var hours: Double

    /// Comentario opcional.
    var comment: String

    /// Cliente/Departamento asociado.
    var client: Client?

    /// Proyecto asociado.
    var project: Project?

    var createdAt: Date

    init(
        date: Date = .now,
        hours: Double = 0,
        comment: String = "",
        client: Client? = nil,
        project: Project? = nil,
        createdAt: Date = .now
    ) {
        self.date = date
        self.hours = hours
        self.comment = comment
        self.client = client
        self.project = project
        self.createdAt = createdAt
    }
}
