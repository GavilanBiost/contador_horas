import SwiftUI

/// Anillo de progreso (estilo "Actividad") usado en el dashboard
/// para representar el avance semanal de un vistazo.
struct ProgressRing: View {
    let progress: HoursCalculator.Progress
    var tint: Color = .accentColor
    var lineWidth: CGFloat = 14

    private var ringColor: Color { progress.isOver ? .red : tint }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress.fraction)

            VStack(spacing: 2) {
                Text(Formatters.hours(progress.worked))
                    .font(.title.weight(.bold))
                Text(progress.isOver ? "¡Superadas!" : "de \(Formatters.hours(progress.assigned))")
                    .font(.caption)
                    .foregroundStyle(progress.isOver ? .red : .secondary)
            }
        }
    }
}

#Preview {
    ProgressRing(progress: .init(assigned: 40, worked: 31), tint: .blue)
        .frame(width: 180, height: 180)
        .padding()
}
