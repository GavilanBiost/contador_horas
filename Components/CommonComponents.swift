import SwiftUI

/// Estado vacío reutilizable para listas sin contenido.
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

/// Punto de color reutilizable para identificar clientes/proyectos.
struct ColorDot: View {
    let hex: String
    var size: CGFloat = 12
    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

/// Fila de desglose con punto de color, nombre, mini-barra y horas.
/// Reutilizada en dashboard, vista semanal y estadísticas.
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
