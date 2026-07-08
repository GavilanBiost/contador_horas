import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
import UIKit
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

// MARK: - Tipos internos Decodable

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

// MARK: - Tipo interno Encodable (crear / editar)

private struct GCEventBody: Encodable {
    struct EventDateTime: Encodable {
        var dateTime: String?
        var date: String?
        var timeZone: String?
    }
    var summary: String
    var start: EventDateTime
    var end: EventDateTime
}

// MARK: - Servicio

@Observable
final class GoogleCalendarService {

    private(set) var isSignedIn  = false
    private(set) var isLoading   = false
    private(set) var events: [CalendarEvent] = []
    private(set) var errorMessage: String?

    private static let calendarEventsScope = "https://www.googleapis.com/auth/calendar.events"

    var hasWriteAccess: Bool {
#if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.currentUser?.grantedScopes?
            .contains(Self.calendarEventsScope) ?? false
#else
        return false
#endif
    }

#if canImport(GoogleSignIn)
    private static let clientID = "798645956367-vjo9e08hchh790kd494rgs27cjcj2dj1.apps.googleusercontent.com"
#endif

    init() {
#if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Self.clientID)
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            DispatchQueue.main.async { self?.isSignedIn = user != nil }
        }
#endif
    }

    // MARK: – Autenticación

    @MainActor
    func signIn() async {
#if canImport(GoogleSignIn)
        guard let vc = rootViewController() else { return }
        errorMessage = nil
        do {
            _ = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: vc,
                hint: nil,
                additionalScopes: [Self.calendarEventsScope]
            )
            isSignedIn = true
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

    @MainActor
    func requestWriteAccess() async {
#if canImport(GoogleSignIn)
        guard let vc = rootViewController() else { return }
        errorMessage = nil
        do {
            _ = try await GIDSignIn.sharedInstance.addScopes(
                [Self.calendarEventsScope],
                presenting: vc
            )
        } catch {
            errorMessage = "No se pudo ampliar los permisos."
        }
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

    // MARK: – Lectura

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

    // MARK: – Escritura

    @MainActor
    func createEvent(title: String, start: Date, end: Date, isAllDay: Bool) async throws {
#if canImport(GoogleSignIn)
        guard let user = GIDSignIn.sharedInstance.currentUser else { return }
        try await user.refreshTokensIfNeeded()
        let token = user.accessToken.tokenString
        let newEvent = try await postCalendarEvent(token: token, title: title, start: start, end: end, isAllDay: isAllDay)
        events.append(newEvent)
        events.sort { $0.start < $1.start }
#endif
    }

    @MainActor
    func updateEvent(id: String, title: String, start: Date, end: Date, isAllDay: Bool) async throws {
#if canImport(GoogleSignIn)
        guard let user = GIDSignIn.sharedInstance.currentUser else { return }
        try await user.refreshTokensIfNeeded()
        let token = user.accessToken.tokenString
        let updated = try await patchCalendarEvent(token: token, id: id, title: title, start: start, end: end, isAllDay: isAllDay)
        if let idx = events.firstIndex(where: { $0.id == id }) {
            events[idx] = updated
        }
#endif
    }

    @MainActor
    func deleteEvent(id: String) async throws {
#if canImport(GoogleSignIn)
        guard let user = GIDSignIn.sharedInstance.currentUser else { return }
        try await user.refreshTokensIfNeeded()
        let token = user.accessToken.tokenString
        try await deleteCalendarEvent(token: token, id: id)
        events.removeAll { $0.id == id }
#endif
    }

    // MARK: – REST privado: fetch

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
        return (decoded.items ?? []).compactMap { gcItemToEvent($0) }
    }

    // MARK: – REST privado: write

    private func postCalendarEvent(token: String, title: String, start: Date, end: Date, isAllDay: Bool) async throws -> CalendarEvent {
        let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(makeEventBody(title: title, start: start, end: end, isAllDay: isAllDay))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let code = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
            throw URLError(.badServerResponse)
        }
        guard let event = gcItemToEvent(try JSONDecoder().decode(GCItem.self, from: data)) else {
            throw URLError(.cannotParseResponse)
        }
        return event
    }

    private func patchCalendarEvent(token: String, id: String, title: String, start: Date, end: Date, isAllDay: Bool) async throws -> CalendarEvent {
        let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(makeEventBody(title: title, start: start, end: end, isAllDay: isAllDay))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let code = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
            throw URLError(.badServerResponse)
        }
        guard let event = gcItemToEvent(try JSONDecoder().decode(GCItem.self, from: data)) else {
            throw URLError(.cannotParseResponse)
        }
        return event
    }

    private func deleteCalendarEvent(token: String, id: String) async throws {
        let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 204 || (200..<300).contains(code) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: – Helpers

    private func makeEventBody(title: String, start: Date, end: Date, isAllDay: Bool) -> GCEventBody {
        if isAllDay {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = .current
            return GCEventBody(
                summary: title,
                start: .init(date: fmt.string(from: start)),
                end: .init(date: fmt.string(from: end))
            )
        } else {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            return GCEventBody(
                summary: title,
                start: .init(dateTime: iso.string(from: start), timeZone: TimeZone.current.identifier),
                end: .init(dateTime: iso.string(from: end), timeZone: TimeZone.current.identifier)
            )
        }
    }

    private func gcItemToEvent(_ item: GCItem) -> CalendarEvent? {
        guard let id = item.id, let title = item.summary else { return nil }

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

#if canImport(GoogleSignIn)
    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
#endif
}
