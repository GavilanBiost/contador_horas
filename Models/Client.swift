import Foundation
import SwiftData

/// Representa un **Departamento o Cliente**.
/// Es el nivel más alto de organización: agrupa proyectos y registros de horas.
@Model
final class Client {
    /// Nombre identificativo (obligatorio).
    var name: String

    /// Color identificativo en formato HEX (p. ej. "#4C8DFF").
    /// Se usa para diferenciar el cliente en listas y gráficos.
    var colorHex: String

    /// Horas semanales asignadas (presupuesto) a este cliente.
    /// 0 significa "sin asignación específica".
    var weeklyHours: Double

    /// Fecha de creación, útil para ordenar.
    var createdAt: Date

    /// Proyectos asociados. Al borrar el cliente se borran en cascada.
    @Relationship(deleteRule: .cascade, inverse: \Project.client)
    var projects: [Project] = []

    /// Registros de horas asociados directamente al cliente.
    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.client)
    var entries: [TimeEntry] = []

    init(
        name: String,
        colorHex: String = Palette.defaultHex,
        weeklyHours: Double = 0,
        createdAt: Date = .now
    ) {
        self.name = name
        self.colorHex = colorHex
        self.weeklyHours = weeklyHours
        self.createdAt = createdAt
    }
}
