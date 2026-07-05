import SwiftUI

/// Barra de progreso para mostrar horas trabajadas frente a asignadas.
/// Cambia de color y avisa visualmente si se supera el presupuesto.
struct HoursProgressBar: View {
    let progress: HoursCalculator.Progress
    var tint: Color = .accentColor
    var height: CGFloat = 12

    private var barColor: Color { progress.isOver ? .red : tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(geo.size.width * progress.fraction, progress.worked > 0 ? height : 0))
                        .animation(.spring(duration: 0.4), value: progress.fraction)
                }
            }
            .frame(height: height)

            HStack {
                Text("\(Formatters.hours(progress.worked)) de \(Formatters.hours(progress.assigned))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if progress.isOver {
                    Label("+\(Formatters.hours(progress.overflow))", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                } else {
                    Text("Faltan \(Formatters.hours(progress.remaining))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HoursProgressBar(progress: .init(assigned: 40, worked: 28), tint: .blue)
        HoursProgressBar(progress: .init(assigned: 40, worked: 46), tint: .blue)
    }
    .padding()
}
