import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity del cronómetro

struct Contador_de_horas_laboralLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Vista en pantalla de bloqueo y banner
            TimerLockScreenLiveView(context: context)
                .activityBackgroundTint(Color.accentColor.opacity(0.12))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Registrando", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerLiveText(context: context)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let subtitle = [context.state.clientName, context.state.projectName]
                        .filter { !$0.isEmpty }.joined(separator: " · ")
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "clock.fill").foregroundStyle(Color.accentColor)
            } compactTrailing: {
                TimerLiveText(context: context)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "clock.fill").foregroundStyle(Color.accentColor)
            }
            .keylineTint(Color.accentColor)
        }
    }
}

// MARK: - Pantalla de bloqueo

private struct TimerLockScreenLiveView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill").foregroundStyle(Color.accentColor)
                    Text("Horas Laborales").font(.subheadline.weight(.medium))
                }
                let subtitle = [context.state.clientName, context.state.projectName]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                TimerLiveText(context: context)
                    .font(.system(.title2, design: .monospaced).weight(.semibold))

                HStack(spacing: 4) {
                    if context.state.isRunning {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("EN CURSO").font(.caption2.weight(.medium)).foregroundStyle(.red)
                    } else {
                        Text("PAUSADO").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Texto del contador

/// Usa Text(timerInterval:) cuando corre para actualización automática sin push.
private struct TimerLiveText: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        if context.state.isRunning, let start = context.state.effectiveStartDate {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
        } else {
            Text(formatted(context.state.pausedElapsed))
        }
    }

    private func formatted(_ elapsed: TimeInterval) -> String {
        let t = Int(elapsed)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
