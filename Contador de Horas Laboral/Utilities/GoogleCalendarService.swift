import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - Modelo de evento (siempre disponible)

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let colorHex: String
}

// MARK: - Decodable internos (respuesta de la API REST)

private struct GCListResponse: Decodable {
    let items: [GCItem]?
}

private struct GCItem: Decodable {
    let id: String?
    let summary: String?
    let colorId: String?
    let start: GCDateTime?
    let end: GCDateTime?
}

private struct GCDateTime: Decodable {
    let dateTime: String?
    let date: String?
}

// MARK: - Servicio

@Observable
final class GoogleCalendarService {

    private(set) var isSignedIn  = false
    private(set) var isLoading   = false
    private(set) var events: [CalendarEvent] = []
    private(set) var errorMessage: String?

    /// True si GIDClientID está configurado en Info.plist.
    private var isConfigured: Bool {
        Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String != nil
    }

    init() {
#if canImport(GoogleSignIn)
        guard isConfigured else { return }
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            DispatchQueue.main.async { self?.isSignedIn = user != nil }
        }
#endif
    }

    // MARK: – Autenticación

    @MainActor
    func signIn() async {
#if canImport(GoogleSignIn)
        guard isConfigured else {
            errorMessage = "Falta GIDClientID en Info.plist. Revisa la configuración."
            return
        }
        guard let vc = rootViewController() else { return }
        errorMessage = nil
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: vc,
                additionalScopes: ["https://www.googleapis.com/auth/calendar.readonly"]
            )
            isSignedIn = result.user != nil
        } catch {
            let nsErr = error as NSError
            if nsErr.domain != "com.google.GIDSignIn" || nsErr.code != -5 {
                errorMessage = "No se pudo conectar con Google: \(error.localizedDescription)"
            }
        }
#else
        errorMessage = "Añade el paquete GoogleSignIn-iOS via SPM primero."
#endif
    }

    func signOut() {
#if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
#endif
        isSignedIn = false
        events = []
        errorMessage = nil
    }

    // MARK: – Eventos

    @MainActor
    func fetchEvents(for interval: DateInterval) async {
#if canImport(GoogleSignIn)
        guard let user = GIDSignIn.sharedInstance.currentUser else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await user.refreshTokensIfNeeded()
            let token = user.accessToken.tokenString
            events = try await fetchCalendarEvents(token: token, interval: interval)
        } catch {
            errorMessage = "Error al cargar el calendario. Comprueba tu conexión."
        }
#endif
    }

    // MARK: – Privado: llamada REST

    private func fetchCalendarEvents(token: String, interval: DateInterval) async throws -> [CalendarEvent] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            .init(name: "timeMin",      value: iso.string(from: interval.start)),
            .init(name: "timeMax",      value: iso.string(from: interval.end)),
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy",      value: "startTime"),
            .init(name: "maxResults",   value: "100")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(GCListResponse.self, from: data)

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        let dayParser: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            return f
        }()

        return (decoded.items ?? []).compactMap { item in
            guard let id = item.id, let title = item.summary else { return nil }

            func parseDate(from dt: GCDateTime?) -> (Date, Bool)? {
                if let raw = dt?.dateTime {
                    let d = isoFull.date(from: raw) ?? isoBasic.date(from: raw)
                    return d.map { ($0, false) }
                }
                if let raw = dt?.date {
                    return dayParser.date(from: raw).map { ($0, true) }
                }
                return nil
            }

            guard let (start, isAllDay) = parseDate(from: item.start),
                  let (end, _)          = parseDate(from: item.end) else { return nil }

            return CalendarEvent(
                id: id, title: title,
                start: start, end: end,
                isAllDay: isAllDay,
                colorHex: Self.gcColorHex(item.colorId)
            )
        }
    }

    private static func gcColorHex(_ colorId: String?) -> String {
        switch colorId {
        case "1":  return "#D50000"
        case "2":  return "#E67C73"
        case "3":  return "#F4511E"
        case "4":  return "#F6BF26"
        case "5":  return "#33B679"
        case "6":  return "#0B8043"
        case "7":  return "#039BE5"
        case "8":  return "#3F51B5"
        case "9":  return "#7986CB"
        case "10": return "#8E24AA"
        case "11": return "#616161"
        default:   return "#4C8DFF"
        }
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
