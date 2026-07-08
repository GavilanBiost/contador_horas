import SwiftUI
import SwiftData

struct ClientFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang

    var client: Client?

    @State private var name = ""
    @State private var colorHex = Palette.defaultHex

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang["clients.name"]) {
                    TextField(lang["clients.placeholder"], text: $name)
                }
                Section(lang["clients.color"]) {
                    ColorSelector(selectedHex: $colorHex)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle(client == nil ? lang["clients.new"] : lang["clients.edit"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(lang["clients.cancel"]) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang["clients.save"], action: save).disabled(!isValid)
                }
            }
            .onAppear {
                if let client {
                    name = client.name
                    colorHex = client.colorHex
                }
            }
        }
    }

    private func save() {
        if let client {
            client.name = name
            client.colorHex = colorHex
        } else {
            context.insert(Client(name: name, colorHex: colorHex))
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    ClientFormView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(LanguageManager())
}
