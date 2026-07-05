import SwiftUI

/// Selector de color basado en la paleta predefinida.
/// Devuelve el HEX seleccionado mediante binding.
struct ColorSelector: View {
    @Binding var selectedHex: String

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Palette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if hex == selectedHex {
                            Circle()
                                .stroke(Color.primary, lineWidth: 3)
                                .padding(-3)
                        }
                    }
                    .overlay {
                        if hex == selectedHex {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedHex = hex }
                    }
            }
        }
    }
}

#Preview {
    struct Wrapper: View {
        @State var hex = Palette.colors[2]
        var body: some View { ColorSelector(selectedHex: $hex).padding() }
    }
    return Wrapper()
}
