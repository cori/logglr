import SwiftUI
import SwiftData
import LifeLogKit

struct QuickLogView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    @State private var moodValue: Double = 5
    @State private var showingConfirmation = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mood emoji visualization
                Text(moodEmoji)
                    .font(.system(size: 60))
                    .padding(.top)

                // Mood value
                Text("\(Int(moodValue))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(moodColor)
                    .contentTransition(.numericText())

                // Slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("How are you feeling?")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Slider(value: $moodValue, in: 1...10, step: 1)
                        .tint(moodColor)
                }
                .padding(.horizontal)

                // Scale labels
                HStack {
                    Text("1")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("10")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Log button
                Button {
                    Task {
                        await logMood()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isSaving)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .navigationTitle("Quick Log")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: showingConfirmation)
        .alert("Logged!", isPresented: $showingConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Mood: \(Int(moodValue))")
        }
    }

    // MARK: - Computed Properties

    private var moodEmoji: String {
        switch Int(moodValue) {
        case 1...2: return "😢"
        case 3...4: return "😕"
        case 5...6: return "😐"
        case 7...8: return "🙂"
        case 9...10: return "😄"
        default: return "😐"
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

    private func logMood() async {
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        // Create entry
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: DeviceInfo.source,
            deviceId: DeviceInfo.identifier,
            category: "mood",
            data: LogData(
                metric: Metric(
                    name: "mood",
                    value: moodValue,
                    scaleMin: 1.0,
                    scaleMax: 10.0
                ),
                tags: ["quick-log"]
            ),
            synced: false
        )

        // Save to local SwiftData
        modelContext.insert(entry)
        try? modelContext.save()

        // Send to iPhone via Watch Connectivity
        connectivity.sendEntry(entry.toAPIModel())

        // Show confirmation
        showingConfirmation = true
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        QuickLogView()
    }
    .environment(\.modelContext, PersistenceController.preview().mainContext)
    .environmentObject(WatchConnectivityManager.shared)
}
