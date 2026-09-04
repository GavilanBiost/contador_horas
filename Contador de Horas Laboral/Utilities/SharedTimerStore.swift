import Foundation

/// Estado del cronómetro persistido en un App Group. Lo leen y escriben tanto
/// la app como el widget y la Live Activity, para que cualquiera de ellos
/// pueda iniciar, pausar o reiniciar el mismo cronómetro.
/// Este archivo debe estar incluido también en el target del Widget Extension.
enum SharedTimerStore {
    static let appGroupID = "group.GavilanBiost.Contador-de-Horas-Laboral"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private enum Keys {
        static let start = "timer.start"
        static let base = "timer.base"
    }

    static var startDate: Date? {
        get { defaults.object(forKey: Keys.start) as? Date }
        set { defaults.set(newValue, forKey: Keys.start) }
    }

    static var base: TimeInterval {
        get { defaults.double(forKey: Keys.base) }
        set { defaults.set(newValue, forKey: Keys.base) }
    }

    static var isRunning: Bool { startDate != nil }

    static var elapsed: TimeInterval {
        if let start = startDate {
            return base + Date().timeIntervalSince(start)
        }
        return base
    }

    static func start() {
        guard startDate == nil else { return }
        startDate = Date()
    }

    static func pause() {
        guard let start = startDate else { return }
        base += Date().timeIntervalSince(start)
        startDate = nil
    }

    static func reset() {
        startDate = nil
        base = 0
    }
}
