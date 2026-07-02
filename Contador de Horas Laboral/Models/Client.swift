import Foundation
import SwiftData

/// Representa un **Departamento o Cliente**.
@Model
final class Client {
    var name: String
    var colorHex: String
    var weeklyHours: Double
    var createdAt: Date

    /// Proyectos asociados (muchos-a-muchos). Al borrar el cliente no se borran
    /// los proyectos, ya que pueden pertenecer a otros clientes.
    @Relationship(inverse: \Project.clients)
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
