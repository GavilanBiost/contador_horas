import SwiftUI
import SwiftData

struct TimeEntryFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var lang

    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Project.name) private var projects: [Project]

    var entry: TimeEntry?
    var initialHours: Double? = nil
    var onSave: (() -> Void)? = nil

    @State private var date: Date = .now
    @State private var hoursText: String = "1"
    @State private var minutesText: String = "00"
    @State private var comment: String = ""
    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var showingDeleteConfirmation = false

    private var availableProjects: [Project] {
        guard let selectedClient else { return projects }
        return projects.filter { project in
            project.clients.contains { $0.persistentModelID == selectedClient.persistentModelID }
        }
    }

    private var totalHours: Double {
        let h = min(24, max(0, Int(hoursText) ?? 0))
        let m = min(59, max(0, Int(minutesText) ?? 0))
        return Double(h) + Double(m) / 60.0
    }

    private var isValid: Bool { totalHours > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang["form.date"]) {
                    DatePicker(lang["form.day"], selection: $date, displayedComponents: .date)
                }

                Section(lang["form.hours"]) {
                    HStack(spacing: 12) {
                        Button {
                            let total = max(0, (Int(hoursText) ?? 0) * 60 + (Int(minutesText) ?? 0) - 1)
                            hoursText = "\(total / 60)"
                            minutesText = String(format: "%02d", total % 60)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(totalHours > 0 ? Color.accentColor : Color.secondary)
                        .disabled(totalHours <= 0)

                        Spacer()

                        HStack(spacing: 4) {
                            TextField("0", text: $hoursText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 44)
                                .onChange(of: hoursText) { _, val in
                                    let filtered = val.filter { $0.isNumber }
                                    if filtered != val { hoursText = filtered }
                                }
                            Text("h")
                                .foregroundStyle(.secondary)
                            Spacer().frame(width: 12)
                            TextField("00", text: $minutesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 44)
                                .onChange(of: minutesText) { _, val in
                                    let filtered = val.filter { $0.isNumber }
                                    if filtered != val {
                                        minutesText = filtered
                                        return
                                    }
                                    if let m = Int(filtered), m >= 60 {
                                        let h = min(24, (Int(hoursText) ?? 0) + m / 60)
                                        hoursText = "\(h)"
                                        minutesText = String(format: "%02d", m % 60)
                                    }
                                }
                            Text("min")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            let total = min(24 * 60, (Int(hoursText) ?? 0) * 60 + (Int(minutesText) ?? 0) + 1)
                            hoursText = "\(total / 60)"
                            minutesText = String(format: "%02d", total % 60)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(totalHours >= 24 ? Color.secondary : Color.accentColor)
                        .disabled(totalHours >= 24)
                    }
                    .padding(.vertical, 4)
                }

                Section(lang["form.client"]) {
                    if clients.isEmpty {
                        Text(lang["form.create_client"])
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(lang["form.client_picker"], selection: $selectedClient) {
                            Text(lang["form.no_client"]).tag(Client?.none)
                            ForEach(clients) { client in
                                Text(client.name).tag(Client?.some(client))
                            }
                        }
                        .onChange(of: selectedClient) { _, newClient in
                            if let p = selectedProject, let client = newClient {
                                let stillValid = p.clients.contains { $0.persistentModelID == client.persistentModelID }
                                if !stillValid { selectedProject = nil }
                            }
                        }
                    }
                }

                Section(lang["form.project"]) {
                    Picker(lang["form.project_picker"], selection: $selectedProject) {
                        Text(lang["form.no_project"]).tag(Project?.none)
                        ForEach(availableProjects) { project in
                            Text(project.name).tag(Project?.some(project))
                        }
                    }
                }

                Section(lang["form.comment"]) {
                    TextField(lang["form.comment_hint"], text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                }

                if entry != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(lang["form.delete_entry"])
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? lang["form.new"] : lang["form.edit"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang["form.cancel"]) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang["form.save"], action: save).disabled(!isValid)
                }
            }
            .onAppear(perform: loadIfEditing)
            .confirmationDialog(
                lang["form.delete_entry"],
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(lang["form.delete"], role: .destructive) {
                    if let entry {
                        context.delete(entry)
                        try? context.save()
                    }
                    dismiss()
                }
                Button(lang["form.cancel"], role: .cancel) { }
            } message: {
                Text(lang["form.irreversible"])
            }
        }
    }

    private func loadIfEditing() {
        if let entry {
            date = entry.date
            let totalMinutes = Int((entry.hours * 60).rounded())
            hoursText = "\(totalMinutes / 60)"
            minutesText = String(format: "%02d", totalMinutes % 60)
            comment = entry.comment
            selectedClient = entry.client
            selectedProject = entry.project
        } else if let initial = initialHours, initial > 0 {
            let totalMinutes = Int((initial * 60).rounded())
            hoursText = "\(totalMinutes / 60)"
            minutesText = String(format: "%02d", totalMinutes % 60)
        }
    }

    private func save() {
        if let entry {
            entry.date = date
            entry.hours = totalHours
            entry.comment = comment
            entry.client = selectedClient
            entry.project = selectedProject
        } else {
            let new = TimeEntry(
                date: date,
                hours: totalHours,
                comment: comment,
                client: selectedClient ?? selectedProject?.clients.first,
                project: selectedProject
            )
            context.insert(new)
        }
        try? context.save()
        onSave?()
        dismiss()
    }
}

#Preview {
    TimeEntryFormView()
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, AppSettings.self], inMemory: true)
        .environment(LanguageManager())
}
