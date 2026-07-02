import SwiftUI
import SwiftData
import Charts

// Shared formatter — created once, reused by WeekView and DayColumn.
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

    @State private var weekOffset = 0
    @State private var selectedDay: Date?

    private var referenceDate: Date { Date().adding(weekOffset, .week) }
    private var interval: DateInterval { referenceDate.interval(of: .week) }
    private var weekEntries: [TimeEntry] { HoursCalculator.entries(entries, in: interval) }
    private var assigned: Double { settings.first?.totalWeeklyHours ?? 0 }
    /// Objetivo diario estimado (horas totales / 5 días laborables).
    private var dailyTarget: Double { assigned > 0 ? assigned / 5 : 0 }

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

    private var maxDayHours: Double {
        max(days.map { hoursForDay($0) }.max() ?? 0, dailyTarget, 1)
    }

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
                    calendarStrip
                    if let day = selectedDay {
                        dayDetailCard(day)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    weekBarChart
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Semana")
            .onChange(of: weekOffset) { _, _ in
                withAnimation { selectedDay = nil }
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
                    isToday: isToday, isSelected: isSel
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

    // MARK: – Weekly bar chart

    private var weekBarChart: some View {
        ChartCard(title: "Distribución semanal") {
            Chart {
                ForEach(days, id: \.self) { day in
                    let h = hoursForDay(day)
                    let isSel = selectedDay.map { Calendar.app.isDate($0, inSameDayAs: day) } ?? false
                    BarMark(
                        x: .value("Día", weekAbbrevFmt.string(from: day).uppercased()),
                        y: .value("Horas", h)
                    )
                    .foregroundStyle(
                        isSel
                            ? Color.accentColor.gradient
                            : (h > 0 ? Color.accentColor.opacity(0.55).gradient
                                     : Color(.systemGray5).gradient)
                    )
                    .cornerRadius(6)
                }
                if dailyTarget > 0 {
                    RuleMark(y: .value("Objetivo/día", dailyTarget))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Obj. \(compactHours(dailyTarget))/día")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = v.as(Double.self) {
                            Text(compactHours(h)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: – Helpers

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

// MARK: - DayColumn

private struct DayColumn: View {
    let day: Date
    let hours: Double
    let fraction: Double
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Day letter (L, M, X, J, V, S, D)
            Text(weekAbbrevFmt.string(from: day).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            // Day number with highlight circle
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

            // Mini vertical bar
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(
                            isSelected ? Color.accentColor
                            : (hours > 0 ? Color.accentColor.opacity(0.65) : Color(.systemGray5))
                        )
                        .frame(height: max(geo.size.height * CGFloat(fraction),
                                           hours > 0 ? 4 : 2))
                        .animation(.spring(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 52)

            // Compact hours label
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
}
