import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ColorDot: View {
    let hex: String
    var size: CGFloat = 12
    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

struct ClientProgressRow: View {
    let item: HoursBreakdown
    let assigned: Double
    let maxHours: Double
    @Environment(LanguageManager.self) private var lang

    private var progress: HoursCalculator.Progress {
        HoursCalculator.progress(assigned: assigned, worked: item.hours)
    }
    private var hasAssigned: Bool { assigned > 0 }
    private var barFraction: Double {
        hasAssigned ? progress.fraction : (maxHours > 0 ? item.hours / maxHours : 0)
    }
    private var barColor: Color {
        hasAssigned && progress.isOver ? .red : Color(hex: item.colorHex).opacity(0.85)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ColorDot(hex: item.colorHex)
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                if hasAssigned {
                    Text("\(Formatters.hours(item.hours)) / \(Formatters.hours(assigned))")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(progress.isOver ? .red : .primary)
                } else {
                    Text(Formatters.hours(item.hours))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(geo.size.width * barFraction, 4), height: 8)
                        .animation(.spring(duration: 0.4), value: barFraction)
                }
            }
            .frame(height: 8)

            if hasAssigned {
                HStack {
                    Spacer()
                    if progress.isOver {
                        Label("+\(Formatters.hours(progress.overflow))", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    } else {
                        Text(lang["common.missing_format"].replacingOccurrences(of: "{0}", with: Formatters.hours(progress.remaining)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct BreakdownRow: View {
    let item: HoursBreakdown
    let maxHours: Double

    private var fraction: Double {
        guard maxHours > 0 else { return 0 }
        return item.hours / maxHours
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ColorDot(hex: item.colorHex)
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(Formatters.hours(item.hours))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                Capsule()
                    .fill(Color(hex: item.colorHex).opacity(0.85))
                    .frame(width: max(geo.size.width * fraction, 4), height: 6)
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}
