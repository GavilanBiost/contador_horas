import SwiftUI

// MARK: - Color desde HEX

extension Color {
    /// Crea un Color a partir de una cadena HEX ("#RRGGBB" o "RRGGBB").
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((value >> 8) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6: // RRGGBB (24-bit)
            (r, g, b) = (value >> 16, value >> 8 & 0xFF, value & 0xFF)
        default:
            (r, g, b) = (120, 120, 120)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Paleta de colores predefinida

/// Paleta cerrada de colores para clientes y proyectos.
/// Trabajar con HEX predefinidos evita problemas de conversión Color→HEX
/// y garantiza una estética coherente.
enum Palette {
    static let defaultHex = "#4C8DFF"

    static let colors: [String] = [
        "#4C8DFF", // azul
        "#34C759", // verde
        "#FF9500", // naranja
        "#FF3B30", // rojo
        "#AF52DE", // morado
        "#FF2D55", // rosa
        "#5AC8FA", // celeste
        "#FFCC00", // amarillo
        "#00C7BE", // turquesa
        "#8E8E93", // gris
        "#A2845E", // marrón
        "#30B0C7"  // cian
    ]
}
