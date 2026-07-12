import SwiftUI
import SwiftData

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
    @Environment(LanguageManager.self) private var lang

    @State private var weekOffset = 0
    @State private var selectedDay: Date?
    @State private var weekTab: WeekTab = .summary
    @State private var selectedCalendarEvent: CalendarEvent?
    @State private var showCreateEventForm = false
    @State private var createEventDefaultDate: Date = Date()

    private enum WeekTab: CaseIterable {
        case summary, calendar
    }

    // Calendar grid layout constants
    private let calHourHeight: CGFloat = 56
    private let calStartHour = 7
    private let calEndHour = 22
    private let calTimeWidth: CGFloat = 40

    private var weekAbbrevFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = lang.locale
        f.dateFormat = "EEEEE"
        return f
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
                        Text(lang["week.summary"]).tag(WeekTab.summary)
                        Text(lang["week.calendar"]).tag(WeekTab.calendar)
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
            .navigationTitle(lang["tab.week"])
            .toolbar {
                if weekTab == .calendar && calendarService.isSignedIn && calendarService.hasWriteAccess {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            createEventDefaultDate = selectedDay ?? Date()
                            showCreateEventForm = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
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
            .sheet(item: $selectedCalendarEvent) { event in
                CalendarEventDetailView(event: event)
            }
            .sheet(isPresented: $showCreateEventForm) {
                CalendarEventFormView(event: nil, defaultDate: createEventDefaultDate, onSave: {})
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
                Text(lang.shortRange(interval)).font(.headline)
                if weekOffset == 0 {
                    Text(lang["week.this_week"]).font(.caption).foregroundStyle(.secondary)
                } else {
                    Button(lang["week.back_to_today"]) { withAnimation { weekOffset = 0 } }
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
                    breakdown: breakdownForDay(day),
                    locale: lang.locale
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
                Text(lang.dayFull(day))
                    .font(.headline)
                Spacer()
                Text(Formatters.hours(HoursCalculator.total(selectedDayEntries)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if selectedDayEntries.isEmpty {
                Text(lang["week.no_records_day"])
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
                            Text(entry.project?.name ?? entry.client?.name ?? lang["entries.unassigned"])
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
            Text(lang["dash.by_client"])
                .font(.headline)
            if clientBreakdown.isEmpty {
                Text(lang["dash.no_hours"])
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

    // MARK: – Calendar tab

    @ViewBuilder
    private var calendarEventsSection: some View {
        if !calendarService.isSignedIn {
            calSignInCard
        } else if calendarService.isLoading {
            calLoadingCard
        } else {
            VStack(spacing: 12) {
                if !calendarService.hasWriteAccess {
                    calWriteAccessBanner
                }

                weeklyCalendarGrid

                if let error = calendarService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    calendarService.signOut()
                } label: {
                    Label(lang["week.disconnect"], systemImage: "person.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var calSignInCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text(lang["week.connect_google"])
                    .font(.headline)
                Text(lang["week.google_desc"])
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
                    Text(lang["week.connect_google_btn"])
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
    }

    private var calLoadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(lang["week.loading"])
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var calWriteAccessBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil.slash")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(lang["week.readonly"])
                    .font(.subheadline.weight(.medium))
                Text(lang["week.readonly_desc"])
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await calendarService.requestWriteAccess() }
            } label: {
                Text(lang["week.expand"])
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(
            Color.orange.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: – Weekly Calendar Grid

    private var weeklyCalendarGrid: some View {
        VStack(spacing: 0) {
            calDayHeaderRow
            Divider()

            let allDayEvts = calendarService.events.filter { $0.isAllDay }
            if !allDayEvts.isEmpty {
                calAllDayStrip(allDayEvts)
                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    calTimeGrid
                }
                .onAppear {
                    let h = max(calStartHour, min(calEndHour - 1, Calendar.current.component(.hour, from: Date()) - 1))
                    proxy.scrollTo(h, anchor: .top)
                }
                .onChange(of: weekOffset) { _, _ in
                    let h = max(calStartHour, min(calEndHour - 1, Calendar.current.component(.hour, from: Date()) - 1))
                    proxy.scrollTo(h, anchor: .top)
                }
            }
        }
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var calDayHeaderRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: calTimeWidth)
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.app.isDateInToday(day)
                VStack(spacing: 2) {
                    Text(weekAbbrevFormatter.string(from: day).uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    ZStack {
                        Circle()
                            .fill(isToday ? Color.accentColor : Color.clear)
                            .frame(width: 26, height: 26)
                        Text(weekDayNumFmt.string(from: day))
                            .font(.subheadline.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .white : .primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private func calAllDayStrip(_ events: [CalendarEvent]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(lang["week.all_day_short"])
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(width: calTimeWidth, alignment: .trailing)
                .padding(.trailing, 4)

            ForEach(days, id: \.self) { day in
                let dayEvts = events.filter { Calendar.app.isDate($0.start, inSameDayAs: day) }
                VStack(spacing: 2) {
                    ForEach(dayEvts) { event in
                        Button { selectedCalendarEvent = event } label: {
                            Text(event.title)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: event.colorHex).opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(Color(hex: event.colorHex).opacity(0.6), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    if dayEvts.isEmpty { Color.clear.frame(height: 1) }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 1)
            }
        }
        .padding(.vertical, 6)
    }

    private var calTimeGrid: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(calStartHour..<calEndHour, id: \.self) { hour in
                    HStack(spacing: 0) {
                        Text(calHourLabel(hour))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: calTimeWidth, alignment: .trailing)
                            .padding(.trailing, 4)
                            .offset(y: -6)
                        Rectangle()
                            .fill(Color(.separator).opacity(0.25))
                            .frame(height: 0.5)
                    }
                    .frame(height: calHourHeight)
                    .id(hour)
                }
            }

            HStack(alignment: .top, spacing: 0) {
                Color.clear.frame(width: calTimeWidth)
                ForEach(days, id: \.self) { day in
                    calDayEventsColumn(day)
                }
            }

            if weekOffset == 0 {
                calNowIndicator
            }
        }
        .frame(height: CGFloat(calEndHour - calStartHour) * calHourHeight)
    }

    private func calDayEventsColumn(_ day: Date) -> some View {
        let timedEvents = calendarService.events.filter {
            !$0.isAllDay && Calendar.app.isDate($0.start, inSameDayAs: day)
        }
        return ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(timedEvents) { event in
                let top = calEventTop(event)
                let height = calEventHeight(event)
                let totalH = CGFloat(calEndHour - calStartHour) * calHourHeight
                if top < totalH {
                    calEventBlock(event, height: height)
                        .offset(y: max(0, top))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 1)
    }

    private func calEventBlock(_ event: CalendarEvent, height: CGFloat) -> some View {
        Button {
            selectedCalendarEvent = event
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(height > 30 ? 2 : 1)
                if height > 34 {
                    Text("\(Formatters.timeShort.string(from: event.start)) – \(Formatters.timeShort.string(from: event.end))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(height: height)
            .background(Color(hex: event.colorHex))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var calNowIndicator: some View {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        if hour >= calStartHour && hour < calEndHour {
            let y = CGFloat((hour - calStartHour) * 60 + minute) / 60.0 * calHourHeight
            GeometryReader { geo in
                let colWidth = (geo.size.width - calTimeWidth) / CGFloat(days.count)
                let todayIdx = CGFloat(days.firstIndex(where: { Calendar.app.isDateInToday($0) }) ?? 0)
                let x = calTimeWidth + todayIdx * colWidth
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: colWidth - 2, height: 1.5)
                        .offset(x: x + 1)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .offset(x: x - 3.5)
                }
                .offset(y: y - 0.75)
            }
        }
    }

    // MARK: – Calendar helpers

    private func calEventTop(_ event: CalendarEvent) -> CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: event.start)
        let m = cal.component(.minute, from: event.start)
        return CGFloat((h - calStartHour) * 60 + m) / 60.0 * calHourHeight
    }

    private func calEventHeight(_ event: CalendarEvent) -> CGFloat {
        let duration = event.end.timeIntervalSince(event.start) / 3600
        return max(CGFloat(duration) * calHourHeight, 20)
    }

    private func calHourLabel(_ hour: Int) -> String {
        switch hour {
        case 0, 24: return "12a"
        case 12:    return "12p"
        default:    return hour > 12 ? "\(hour - 12)p" : "\(hour)a"
        }
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
    let locale: Locale

    private var abbrevFmt: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EEEEE"
        return f
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(abbrevFmt.string(from: day).uppercased())
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

// MARK: - Calendar Event Detail Sheet

struct CalendarEventDetailView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    @Environment(GoogleCalendarService.self) private var calendarService
    @Environment(LanguageManager.self) private var lang

    @State private var showEditForm = false
    @State private var editSucceeded = false
    @State private var showDeleteConfirm = false

    private var durationText: String {
        let totalMinutes = Int(event.end.timeIntervalSince(event.start) / 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        switch (h, m) {
        case (_, 0): return "\(h) h"
        case (0, _): return "\(m) min"
        default:     return "\(h) h \(m) min"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(hex: event.colorHex))
                            .frame(width: 6, height: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.title3.weight(.semibold))
                            if event.isAllDay {
                                Text(lang["week.all_day"])
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(Formatters.timeShort.string(from: event.start)) – \(Formatters.timeShort.string(from: event.end))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Label {
                        Text(lang.dayFull(event.start))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    if !event.isAllDay {
                        Label {
                            Text(durationText)
                        } icon: {
                            Image(systemName: "clock")
                        }
                    }
                }

                if calendarService.hasWriteAccess {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label(lang["cal.delete"], systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(lang["cal.detail"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang["cal.close"]) { dismiss() }
                }
                if calendarService.hasWriteAccess {
                    ToolbarItem(placement: .primaryAction) {
                        Button(lang["cal.edit"]) { showEditForm = true }
                    }
                }
            }
            .confirmationDialog(
                "¿Eliminar \"\(event.title)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(lang["form.delete"], role: .destructive) {
                    Task {
                        try? await calendarService.deleteEvent(id: event.id)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditForm, onDismiss: {
                if editSucceeded { dismiss() }
            }) {
                CalendarEventFormView(event: event, defaultDate: event.start) {
                    editSucceeded = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Calendar Event Form (crear / editar)

struct CalendarEventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GoogleCalendarService.self) private var calendarService
    @Environment(LanguageManager.self) private var lang

    let event: CalendarEvent?
    let defaultDate: Date
    let onSave: () -> Void

    @State private var title = ""
    @State private var isAllDay = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isSaving = false
    @State private var saveError: String?

    private var isEditing: Bool { event != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(lang["cal.title_placeholder"], text: $title)
                }

                Section {
                    Toggle(lang["week.all_day"], isOn: $isAllDay.animation())
                    if isAllDay {
                        DatePicker(lang["cal.date"], selection: $startDate, displayedComponents: .date)
                    } else {
                        DatePicker(lang["cal.start"], selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker(lang["cal.end"], selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? lang["cal.edit_title"] : lang["cal.new"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang["cal.cancel"]) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button(isEditing ? lang["cal.save"] : lang["cal.create"]) {
                            Task { await save() }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onChange(of: startDate) { _, newStart in
                if endDate <= newStart {
                    endDate = newStart.addingTimeInterval(3600)
                }
            }
            .onAppear { initializeFields() }
        }
    }

    private func initializeFields() {
        if let event {
            title = event.title
            isAllDay = event.isAllDay
            startDate = event.start
            endDate = event.end
        } else {
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day, .hour], from: defaultDate)
            comps.minute = 0
            let rounded = cal.date(from: comps) ?? defaultDate
            startDate = rounded
            endDate = rounded.addingTimeInterval(3600)
        }
    }

    private func save() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }

        isSaving = true
        saveError = nil

        let effectiveEnd: Date
        if isAllDay {
            effectiveEnd = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate
        } else {
            effectiveEnd = endDate > startDate ? endDate : startDate.addingTimeInterval(3600)
        }

        do {
            if let event {
                try await calendarService.updateEvent(
                    id: event.id,
                    title: cleanTitle,
                    start: startDate,
                    end: effectiveEnd,
                    isAllDay: isAllDay
                )
            } else {
                try await calendarService.createEvent(
                    title: cleanTitle,
                    start: startDate,
                    end: effectiveEnd,
                    isAllDay: isAllDay
                )
            }
            onSave()
            dismiss()
        } catch {
            saveError = "No se pudo guardar el evento. Comprueba tu conexión."
            isSaving = false
        }
    }
}

#Preview {
    WeekView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(GoogleCalendarService())
        .environment(LanguageManager())
}
