import Foundation
import SwiftData

/// Representa un **Proyecto** que pertenece a un Cliente/Departamento.
@Model
final class Project {
    /// Nombre del proyecto (obligatorio).
    var name: String

    /// Descripción opcional.
    var projectDescription: String

    /// Color identificativo en formato HEX.
    var colorHex: String

    /// Horas semanales asignadas (presupuesto) a este proyecto.
    var weeklyHours: Double

    var createdAt: Date

    /// Cliente al que pertenece. Opcional para que el registro
    /// histórico sobreviva si el cliente cambia.
    var client: Client?

    /// Registros de horas de este proyecto. Cascada al borrar.
    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    var entries: [TimeEntry] = []

    init(
        name: String,
        projectDescription: String = "",
        colorHex: String = Palette.defaultHex,
        weeklyHours: Double = 0,
        client: Client? = nil,
        createdAt: Date = .now
    ) {
        self.name = name
        self.projectDescription = projectDescription
        self.colorHex = colorHex
        self.weeklyHours = weeklyHours
        self.client = client
        self.createdAt = createdAt
    }
}
