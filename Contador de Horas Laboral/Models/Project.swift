import Foundation
import SwiftData

/// Representa un **Proyecto** que puede pertenecer a uno o varios Clientes/Departamentos.
@Model
final class Project {
    var name: String
    var projectDescription: String
    var colorHex: String
    var weeklyHours: Double
    var createdAt: Date

    /// Clientes a los que pertenece este proyecto (relación muchos-a-muchos).
    var clients: [Client] = []

    /// Registros de horas de este proyecto. Cascada al borrar.
    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    var entries: [TimeEntry] = []

    init(
        name: String,
        projectDescription: String = "",
        colorHex: String = Palette.defaultHex,
        weeklyHours: Double = 0,
        clients: [Client] = [],
        createdAt: Date = .now
    ) {
        self.name = name
        self.projectDescription = projectDescription
        self.colorHex = colorHex
        self.weeklyHours = weeklyHours
        self.clients = clients
        self.createdAt = createdAt
    }
}
