import SwiftUI

struct LanguageSettingsView: View {
    @Environment(LanguageManager.self) private var lang

    var body: some View {
        List {
            ForEach(LanguageManager.supported, id: \.code) { option in
                Button {
                    lang.setLanguage(option.code)
                } label: {
                    HStack {
                        Text(option.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if lang.language == option.code {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle(lang["lang.title"])
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { LanguageSettingsView() }
        .environment(LanguageManager())
}
