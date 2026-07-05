import Foundation
import SwiftData

/// Agrupación de horas asociada a una categoría (cliente o proyecto),
/// lista para alimentar listas y gráficos.
struct HoursBreakdown: Identifiable {
    let id: String      // identificador estable (nombre o "sin-asignar")
    let name: String
    let colorHex: String
    let hours: Double
}

/// Punto de evolución temporal (un periodo + sus horas).
struct EvolutionPoint: Identifiable {
    let id = UUID()
    let label: String   // "12 may", "mayo", "2025"
    let date: Date      // fecha de inicio del periodo, para ordenar
    let hours: Double
}

/// **Lógica central de cálculo.** Funciones puras sobre arrays de registros.
/// Mantenerla aislada facilita las pruebas y reutilizarla desde cualquier vista.
enum HoursCalculator {

    // MARK: Totales

    /// Suma total de horas de un conjunto de registros.
    static func total(_ entries: [TimeEntry]) -> Double {
        entries.reduce(0) { $0 + $1.hours }
    }

    /// Registros cuya fecha cae dentro del intervalo [inicio, fin).
    static func entries(_ entries: [TimeEntry], in interval: DateInterval) -> [TimeEntry] {
        entries.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    /// Horas trabajadas en el periodo que contiene `date`.
    static func worked(_ entries: [TimeEntry], in period: Period, containing date: Date) -> Double {
        total(self.entries(entries, in: date.interval(of: period)))
    }

    // MARK: Filtros

    static func filter(_ entries: [TimeEntry], client: Client?) -> [TimeEntry] {
        guard let client else { return entries }
        return entries.filter { $0.client?.persistentModelID == client.persistentModelID }
    }

    static func filter(_ entries: [TimeEntry], project: Project?) -> [TimeEntry] {
        guard let project else { return entries }
        return entries.filter { $0.project?.persistentModelID == project.persistentModelID }
    }

    // MARK: Desgloses (para gráficos circulares / barras)

    /// Reparto de horas por cliente/departamento.
    static func byClient(_ entries: [TimeEntry]) -> [HoursBreakdown] {
        var buckets: [String: (name: String, color: String, hours: Double)] = [:]
        for entry in entries {
            let key = entry.client?.name ?? "Sin asignar"
            let color = entry.client?.colorHex ?? "#8E8E93"
            buckets[key, default: (key, color, 0)].hours += entry.hours
        }
        return buckets
            .map { HoursBreakdown(id: $0.key, name: $0.value.name, colorHex: $0.value.color, hours: $0.value.hours) }
            .sorted { $0.hours > $1.hours }
    }

    /// Reparto de horas por proyecto.
    static func byProject(_ entries: [TimeEntry]) -> [HoursBreakdown] {
        var buckets: [String: (name: String, color: String, hours: Double)] = [:]
        for entry in entries {
            let key = entry.project?.name ?? "Sin proyecto"
            let color = entry.project?.colorHex ?? "#8E8E93"
            buckets[key, default: (key, color, 0)].hours += entry.hours
        }
        return buckets
            .map { HoursBreakdown(id: $0.key, name: $0.value.name, colorHex: $0.value.color, hours: $0.value.hours) }
            .sorted { $0.hours > $1.hours }
    }

    // MARK: Evolución temporal (para gráfico de líneas)

    /// Devuelve las horas trabajadas en los últimos `count` periodos,
    /// terminando en el periodo que contiene `reference`.
    static func evolution(
        _ entries: [TimeEntry],
        period: Period,
        endingAt reference: Date = .now,
        count: Int
    ) -> [EvolutionPoint] {
        var points: [EvolutionPoint] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            let date = reference.adding(-offset, period)
            let interval = date.interval(of: period)
            let hours = total(self.entries(entries, in: interval))
            points.append(EvolutionPoint(label: label(for: date, period: period), date: interval.start, hours: hours))
        }
        return points
    }

    private static func label(for date: Date, period: Period) -> String {
        switch period {
        case .week:  return Formatters.dayShort.string(from: date.interval(of: .week).start)
        case .month: return Formatters.monthYear.string(from: date)
        case .year:  return Calendar.app.component(.year, from: date).description
        }
    }

    // MARK: Progreso (asignadas vs trabajadas)

    /// Resultado del cálculo de progreso de un presupuesto de horas.
    struct Progress {
        let assigned: Double
        let worked: Double

        var remaining: Double { max(assigned - worked, 0) }
        var overflow: Double { max(worked - assigned, 0) }
        var isOver: Bool { worked > assigned && assigned > 0 }

        /// Fracción 0…1 (saturada) para barras y anillos.
        var fraction: Double {
            guard assigned > 0 else { return worked > 0 ? 1 : 0 }
            return min(worked / assigned, 1)
        }
    }

    static func progress(assigned: Double, worked: Double) -> Progress {
        Progress(assigned: assigned, worked: worked)
    }
}
