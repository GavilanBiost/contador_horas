import SwiftUI

/// Tarjeta de resumen reutilizable: un dato grande con título e icono.
/// Se usa en el dashboard y en la vista semanal.
struct SummaryCard: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = .accentColor
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    HStack {
        SummaryCard(title: "Asignadas", value: "40 h", systemImage: "calendar", tint: .blue)
        SummaryCard(title: "Restantes", value: "12,5 h", systemImage: "hourglass", tint: .green)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
