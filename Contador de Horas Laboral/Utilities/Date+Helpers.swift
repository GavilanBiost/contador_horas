import Foundation

// MARK: - Calendario de la app

extension Calendar {
    /// Calendario configurado para España: la semana empieza en lunes.
    static var app: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 1 = domingo, 2 = lunes
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = .current
        return cal
    }
}

// MARK: - Periodos (semana / mes / año)

/// Granularidad temporal usada en estadísticas y vistas.
enum Period: String, CaseIterable, Identifiable {
    case week = "Semana"
    case month = "Mes"
    case year = "Año"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .week:  return .weekOfYear
        case .month: return .month
        case .year:  return .year
        }
    }
}

// MARK: - Helpers de Date

extension Date {
    /// Devuelve el intervalo [inicio, fin) del periodo que contiene esta fecha.
    func interval(of period: Period, calendar: Calendar = .app) -> DateInterval {
        calendar.dateInterval(of: period.calendarComponent, for: self)
            ?? DateInterval(start: self, duration: 0)
    }

    func startOfDay(_ calendar: Calendar = .app) -> Date {
        calendar.startOfDay(for: self)
    }

    /// Suma (o resta) un número de periodos a la fecha.
    func adding(_ count: Int, _ period: Period, calendar: Calendar = .app) -> Date {
        calendar.date(byAdding: period.calendarComponent, value: count, to: self) ?? self
    }
}

// MARK: - Formateadores reutilizables

enum Formatters {
    /// "12 may" – etiqueta corta de día.
    static let dayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM"
        return f
    }()

    /// "lunes, 12 de mayo" – fecha completa.
    static let dayFull: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f
    }()

    /// "mayo 2025" – etiqueta de mes.
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// "09:30" – hora corta para eventos de calendario.
    static let timeShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    /// Formatea horas con un máximo de 2 decimales: 8, 7.5, 0.25.
    static func hours(_ value: Double) -> String {
        let totalMinutes = Int((value * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        switch (h, m) {
        case (_, 0): return "\(h) h"
        case (0, _): return "\(m) min"
        default:     return "\(h) h \(m) min"
        }
    }
}

// MARK: - Rango legible de un intervalo

extension DateInterval {
    /// "12 may – 18 may" para una semana.
    var shortRangeLabel: String {
        let cal = Calendar.app
        let endInclusive = cal.date(byAdding: .day, value: -1, to: end) ?? end
        return "\(Formatters.dayShort.string(from: start)) – \(Formatters.dayShort.string(from: endInclusive))"
    }
}
