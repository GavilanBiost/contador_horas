import SwiftUI
import SwiftData

private let weekAbbrevFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_ES")
    f.dateFormat = "EEEEE"
    return f
}()

private let weekDayNumFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "d"
    return f
}()

// MARK: - WeekView

struct WeekView: View {
    @Query private var entries: [TimeEntry]
    @Query private var settings: [AppSettings]
    @Query(sort: \Client.name) private var clients: [Client]

    @Environment(GoogleCalendarService.self) private var calendarService

    @State private var weekOffset = 0
    @State private var selectedDay: Date?
    @State private var weekTab: WeekTab = .summary

    private enum WeekTab: String, CaseIterable {
        case summary  = "Resumen"
        case calendar = "Calendario"
    }

    private var referenceDate: Date { Date().adding(weekOffset, .week) }
    private var interval: DateInterval { referenceDate.interval(of: .week) }
    private var weekEntries: [TimeEntry] { HoursCalculator.entries(entries, in: interval) }
    private var assigned: Double { settings.first?.totalWeeklyHours ?? 0 }
    private var dailyTarget: Double {
        let explicit = settings.first?.dailyHoursTarget ?? 0
        return explicit > 0 ? explicit : (assigned > 0 ? assigned / 5 : 0)
    }

    private var days: [Date] {
        (0..<7).compactMap { Calendar.app.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private func hoursForDay(_ day: Date) -> Double {
        let start = day.startOfDay()
        guard let end = Calendar.app.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return HoursCalculator.total(
            HoursCalculator.entries(weekEntries, in: DateInterval(start: start, end: end))
        )
    }

    private func breakdownForDay(_ day: Date) -> [HoursBreakdown] {
        let start = day.startOfDay()
        guard let end = Calendar.app.date(byAdding: .day, value: 1, to: start) else { return [] }
        return HoursCalculator.byClient(
            HoursCalculator.entries(weekEntries, in: DateInterval(start: start, end: end))
        )
    }

    private var maxDayHours: Double {
        max(days.map { hoursForDay($0) }.max() ?? 0, dailyTarget, 1)
    }

    private var clientBreakdown: [HoursBreakdown] { HoursCalculator.byClient(weekEntries) }

    private var selectedDayEntries: [TimeEntry] {
        guard let day = selectedDay else { return [] }
        let start = day.startOfDay()
        guard let end = Calendar.app.date(byAdding: .day, value: 1, to: start) else { return [] }
        return HoursCalculator.entries(weekEntries, in: DateInterval(start: start, end: end))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weekNavigator

                    Picker("", selection: $weekTab) {
                        ForEach(WeekTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if weekTab == .summary {
                        calendarStrip
                        if let day = selectedDay {
                            dayDetailCard(day)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        clientBreakdownSection
                    } else {
                        calendarEventsSection
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.2), value: weekTab)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Semana")
            .onChange(of: weekOffset) { _, _ in
                withAnimation { selectedDay = nil }
                if weekTab == .calendar && calendarService.isSignedIn {
                    Task { await calendarService.fetchEvents(for: interval) }
                }
            }
            .onChange(of: weekTab) { _, newTab in
                if newTab == .calendar && calendarService.isSignedIn {
                    Task { await calendarService.fetchEvents(for: interval) }
                }
            }
        }
    }

    // MARK: – Week navigator

    private var weekNavigator: some View {
        HStack {
            Button { withAnimation { weekOffset -= 1 } } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(interval.shortRangeLabel).font(.headline)
                if weekOffset == 0 {
                    Text("Esta semana").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Volver a hoy") { withAnimation { weekOffset = 0 } }
                        .font(.caption)
                }
            }
            Spacer()
            Button { withAnimation { weekOffset += 1 } } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: – 7-day calendar strip

    private var calendarStrip: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let h = hoursForDay(day)
                let isToday = Calendar.app.isDateInToday(day)
                let isSel = selectedDay.map { Calendar.app.isDate($0, inSameDayAs: day) } ?? false
                DayColumn(
                    day: day, hours: h,
                    fraction: maxDayHours > 0 ? h / maxDayHours : 0,
                    targetFraction: maxDayHours > 0 ? dailyTarget / maxDayHours : 0,
                    isToday: isToday, isSelected: isSel,
                    breakdown: breakdownForDay(day)
                )
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedDay = isSel ? nil : day
                    }
                }
            }
        }
        .padding(12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: – Selected day detail

    private func dayDetailCard(_ day: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Formatters.dayFull.string(from: day).capitalized)
                    .font(.headline)
                Spacer()
                Text(Formatters.hours(HoursCalculator.total(selectedDayEntries)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if selectedDayEntries.isEmpty {
                Text("Sin registros para este día.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(selectedDayEntries) { entry in
                    HStack(spacing: 10) {
                        ColorDot(
                            hex: entry.project?.colorHex ?? entry.client?.colorHex ?? "#8E8E93",
                            size: 10
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.project?.name ?? entry.client?.name ?? "Sin asignar")
                                .font(.subheadline)
                            if !entry.comment.isEmpty {
                                Text(entry.comment)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(Formatters.hours(entry.hours))
                            .font(.subheadline.weight(.semibold))
                    }
                    if entry.persistentModelID != selectedDayEntries.last?.persistentModelID {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
        .padding(16)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: – Client breakdown

    private var clientBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Por cliente / departamento")
                .font(.headline)
            if clientBreakdown.isEmpty {
                Text("Aún no has registrado horas esta semana.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(clientBreakdown) { item in
                    ClientProgressRow(
                        item: item,
                        assigned: clients.first { $0.name == item.name }?.weeklyHours ?? 0,
                        maxHours: clientBreakdown.first?.hours ?? 1
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: – Google Calendar section

    @ViewBuilder
    private var calendarEventsSection: some View {
        if !calendarService.isSignedIn {
            // Pantalla de conexión
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                VStack(spacing: 6) {
                    Text("Conecta Google Calendar")
                        .font(.headline)
                    Text("Visualiza tus eventos junto con tus horas de trabajo sin salir de la app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let error = calendarService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task { await calendarService.signIn() }
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key.fill")
                        Text("Conectar con Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        } else if calendarService.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Cargando eventos…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        } else {
            let grouped = Dictionary(grouping: calendarService.events) { $0.start.startOfDay() }
            VStack(spacing: 10) {
                if calendarService.events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Sin eventos esta semana.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                } else {
                    ForEach(days, id: \.self) { day in
                        let dayEvents = grouped[day.startOfDay()] ?? []
                        if !dayEvents.isEmpty {
                            calendarDayCard(day: day, events: dayEvents)
                        }
                    }
                }

                if let error = calendarService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    calendarService.signOut()
                } label: {
                    Label("Desconectar Google Calendar", systemImage: "person.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func calendarDayCard(day: Date, events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Formatters.dayFull.string(from: day).capitalized)
                .font(.headline)
            ForEach(events) { event in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: event.colorHex))
                        .frame(width: 4, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline)
                            .lineLimit(2)
                        if event.isAllDay {
                            Text("Todo el día")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Formatters.timeShort.string(from: event.start)) – \(Formatters.timeShort.string(from: event.end))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if event.id != events.last?.id {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

// MARK: - DayColumn

private struct DayColumn: View {
    let day: Date
    let hours: Double
    let fraction: Double
    let targetFraction: Double
    let isToday: Bool
    let isSelected: Bool
    let breakdown: [HoursBreakdown]

    var body: some View {
        VStack(spacing: 4) {
            Text(weekAbbrevFmt.string(from: day).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(
                        isSelected ? Color.accentColor.opacity(0.18)
                        : isToday  ? Color.accentColor.opacity(0.10)
                        : Color.clear
                    )
                    .frame(width: 28, height: 28)
                Text(weekDayNumFmt.string(from: day))
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday || isSelected ? Color.accentColor : .primary)
            }

            GeometryReader { geo in
                let totalH = breakdown.reduce(0) { $0 + $1.hours }
                let barH = max(geo.size.height * CGFloat(fraction), hours > 0 ? 4 : 0)

                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle().fill(Color(.systemGray4).opacity(0.35)).frame(height: 0.5)
                        Spacer()
                        Rectangle().fill(Color(.systemGray4).opacity(0.35)).frame(height: 0.5)
                        Spacer()
                        Rectangle().fill(Color(.systemGray4).opacity(0.35)).frame(height: 0.5)
                        Spacer()
                    }

                    if !breakdown.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(breakdown.reversed()) { item in
                                Color(hex: item.colorHex)
                                    .opacity(isSelected ? 1.0 : 0.72)
                                    .frame(height: totalH > 0 ? barH * CGFloat(item.hours / totalH) : 0)
                            }
                        }
                        .frame(height: barH)
                        .animation(.spring(duration: 0.4), value: fraction)
                    }

                    if targetFraction > 0 {
                        Rectangle()
                            .fill(Color.orange.opacity(0.85))
                            .frame(width: geo.size.width, height: 1.5)
                            .offset(y: -geo.size.height * CGFloat(min(targetFraction, 1.0)))
                    }
                }
            }
            .frame(height: 52)

            Text(hours > 0 ? compactHours(hours) : "·")
                .font(.system(size: 9,
                              weight: isSelected ? .semibold : .regular,
                              design: .monospaced))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func compactHours(_ value: Double) -> String {
        let m = Int((value * 60).rounded())
        let h = m / 60, min = m % 60
        switch (h, min) {
        case (_, 0): return "\(h)h"
        case (0, _): return "\(min)m"
        default:     return "\(h)h\(min)m"
        }
    }
}

#Preview {
    WeekView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(GoogleCalendarService())
}
