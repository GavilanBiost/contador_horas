//
//  Contador_de_horas_laboralControl.swift
//  Contador de horas laboral
//
//  Created by Jesús García Gavilán on 04/09/2026.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Widget de Centro de Control: enciende/pausa el cronómetro sin abrir la app.
struct Contador_de_horas_laboralControl: ControlWidget {
    static let kind: String = "GavilanBiost.Contador-de-Horas-Laboral.Contador de horas laboral"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { isRunning in
            ControlWidgetToggle(
                "Cronómetro",
                isOn: isRunning,
                action: ToggleTimerIntent()
            ) { isOn in
                Label(isOn ? "En marcha" : "Pausado", systemImage: isOn ? "pause.fill" : "play.fill")
            }
        }
        .displayName("Cronómetro")
        .description("Inicia o pausa el cronómetro de horas laborales.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            SharedTimerStore.isRunning
        }
    }
}
