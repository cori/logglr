import SwiftUI
import SwiftData
import LifeLogKit

struct NewEntryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @State private var entryType: EntryType = .mood
    @State private var text = ""
    @State private var moodValue: Double = 5
    @State private var includeLocation = false
    @State private var tags: [String] = []
    @State private var newTag = ""

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum EntryType: String, CaseIterable {
        case mood = "Mood"
        case note = "Note"
        case work = "Work"

        var icon: String {
            switch self {
            case .mood: return "face.smiling"
            case .note: return "note.text"
            case .work: return "briefcase"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Entry Type Picker
                Section {
                    Picker("Type", selection: $entryType) {
                        ForEach(EntryType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Type-specific content
                switch entryType {
                case .mood:
                    moodSection
                case .note:
                    noteSection
                case .work:
                    workSection
                }

                // Location toggle
                Section {
                    Toggle("Include Location", isOn: $includeLocation)
                } footer: {
                    if includeLocation {
                        Text("Your current location will be attached to this entry")
                    }
                }

                // Tags
                Section("Tags") {
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(tag: tag) {
                                        removeTag(tag)
                                    }
                                }
                            }
                        }
                    }

                    HStack {
                        TextField("Add tag", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                addTag()
                            }

                        if !newTag.isEmpty {
                            Button("Add") {
                                addTag()
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveEntry()
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Type-Specific Sections

    private var moodSection: some View {
        Section {
            VStack(spacing: 16) {
                HStack {
                    Text("😔")
                        .font(.title3)
                    Spacer()
                    Text("\(Int(moodValue))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(moodColor)
                    Spacer()
                    Text("😊")
                        .font(.title3)
                }

                Slider(value: $moodValue, in: 1...10, step: 1)
                    .tint(moodColor)

                Text("How are you feeling?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            TextField("Notes (optional)", text: $text, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("Mood Rating")
        }
    }

    private var noteSection: some View {
        Section {
            TextField("What's on your mind?", text: $text, axis: .vertical)
                .lineLimit(5...15)
        } header: {
            Text("Note")
        }
    }

    private var workSection: some View {
        Section {
            TextField("What are you working on?", text: $text, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("Work Log")
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        switch entryType {
        case .mood:
            return true // Mood always has a value
        case .note, .work:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var moodColor: Color {
        if moodValue >= 7 {
            return .green
        } else if moodValue >= 4 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }

        withAnimation {
            tags.append(trimmed)
            newTag = ""
        }
    }

    private func removeTag(_ tag: String) {
        withAnimation {
            tags.removeAll { $0 == tag }
        }
    }

    private func saveEntry() async {
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            // Build LogData
            var data = LogData()
            data.text = text.isEmpty ? nil : text
            data.tags = tags.isEmpty ? nil : tags

            // Add metric for mood
            if entryType == .mood {
                data.metric = Metric(
                    name: "mood",
                    value: moodValue,
                    scaleMin: 1.0,
                    scaleMax: 10.0
                )
            }

            // Add location if requested (simplified - just coordinates for MVP)
            if includeLocation {
                // In a real app, we'd use CLLocationManager here
                // For MVP, we'll skip actual location fetching
                data.location = nil
            }

            // Create entry
            let entry = LogEntryModel(
                id: UUID(),
                timestamp: Date(),
                recordedAt: Date(),
                source: DeviceInfo.source,
                deviceId: DeviceInfo.identifier,
                category: entryType.rawValue.lowercased(),
                data: data,
                synced: false
            )

            // Save to SwiftData
            modelContext.insert(entry)
            try modelContext.save()

            // Try to sync immediately if configured
            if appState.isConfigured, let apiClient = appState.apiClient {
                let syncManager = SyncManager(
                    apiClient: apiClient,
                    modelContainer: PersistenceController.shared.container
                )
                try await syncManager.syncUnsyncedEntries()
                appState.updateLastSyncDate()
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Tag Chip View

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.gray.opacity(0.15))
        .foregroundStyle(.primary)
        .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Mood") {
    NewEntryView()
        .environment(\.modelContext, PersistenceController.preview().mainContext)
        .environmentObject(AppState.shared)
}

#Preview("Note") {
    var view = NewEntryView()
    view.entryType = .note

    return view
        .environment(\.modelContext, PersistenceController.preview().mainContext)
        .environmentObject(AppState.shared)
}
