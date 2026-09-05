import Foundation

/// Estado del cronómetro persistido en un App Group. Lo leen y escriben tanto
/// la app como el widget y la Live Activity, para que cualquiera de ellos
/// pueda iniciar, pausar o reiniciar el mismo cronómetro.
///
/// Cada cambio (`start`, `pause`, `reset`) emite una notificación Darwin, que
/// llega a todos los procesos (incluido el que la emite). La app la recibe
/// llamando a `startObservingChanges()` y la reenvía como
/// `didChangeNotification` en `NotificationCenter.default` (hilo principal),
/// para que `TimerManager` se resincronice al instante aunque el cambio venga
/// de un App Intent ejecutado mientras la app está en primer plano.
///
/// Este archivo debe estar incluido también en el target del Widget Extension.
enum SharedTimerStore {
    static let appGroupID = "group.GavilanBiost.Contador-de-Horas-Laboral"

    /// Se publica en `NotificationCenter.default` (hilo principal) cada vez que
    /// cambia el estado del cronómetro, lo haya cambiado este proceso u otro.
    /// Requiere haber llamado antes a `startObservingChanges()`.
    static let didChangeNotification = Notification.Name("SharedTimerStore.didChange")

    private static let darwinNotificationName = "GavilanBiost.Contador-de-Horas-Laboral.timerDidChange"

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
        notifyChange()
    }

    static func pause() {
        guard let start = startDate else { return }
        base += Date().timeIntervalSince(start)
        startDate = nil
        notifyChange()
    }

    static func reset() {
        startDate = nil
        base = 0
        notifyChange()
    }

    // MARK: - Notificación de cambios

    private static var isObserving = false

    /// Empieza a escuchar los cambios del cronómetro (propios o de otros
    /// procesos) y los reenvía como `didChangeNotification`. Idempotente.
    static func startObservingChanges() {
        guard !isObserving else { return }
        isObserving = true
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                // Callback en C: no puede capturar contexto. Solo reenvía al
                // hilo principal.
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: SharedTimerStore.didChangeNotification, object: nil)
                }
            },
            darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private static func notifyChange() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }
}
