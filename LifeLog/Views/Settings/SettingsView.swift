import SwiftUI
import LifeLogKit

struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var apiBaseURL: String = ""
    @State private var apiKey: String = ""
    @State private var showingClearConfirmation = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                // Configuration Section
                Section {
                    TextField("API Base URL", text: $apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Enter your Val Town API endpoint and key. You'll get these after deploying the backend.")
                }

                // Save Button
                Section {
                    Button {
                        Task {
                            await saveConfiguration()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isSaving ? "Saving..." : "Save Configuration")
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isSaving)
                }

                // Status Section
                if appState.isConfigured {
                    Section {
                        LabeledContent("Status", value: "Configured")
                            .foregroundStyle(.green)

                        if let lastSync = appState.lastSyncDate {
                            LabeledContent("Last Sync") {
                                Text(lastSync, style: .relative)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Current URL") {
                            Text(appState.apiBaseURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } header: {
                        Text("Current Configuration")
                    }
                }

                // Danger Zone
                if appState.isConfigured {
                    Section {
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Text("Clear Configuration")
                        }
                    } header: {
                        Text("Danger Zone")
                    } footer: {
                        Text("This will remove your API configuration. Your local entries will be preserved.")
                    }
                }

                // App Info
                Section {
                    LabeledContent("Device", value: DeviceInfo.source.capitalized)
                    LabeledContent("Device ID") {
                        Text(DeviceInfo.identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    LabeledContent("Version", value: "1.0.0 (MVP)")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadCurrentConfiguration()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Configuration saved successfully!")
            }
            .confirmationDialog(
                "Clear Configuration?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Configuration", role: .destructive) {
                    clearConfiguration()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove your API configuration. Your local entries will be preserved.")
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: apiBaseURL) != nil
    }

    // MARK: - Actions

    private func loadCurrentConfiguration() {
        apiBaseURL = appState.apiBaseURL

        // Try to load API key from keychain
        if let key = try? KeychainHelper.retrieve(
            service: "com.lifelog.api",
            account: "apiKey"
        ) {
            apiKey = key
        }
    }

    private func saveConfiguration() async {
        guard !isSaving else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try appState.saveConfiguration(
                baseURL: apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func clearConfiguration() {
        appState.clearConfiguration()
        apiBaseURL = ""
        apiKey = ""
    }
}

// MARK: - Previews

#Preview("Configured") {
    let state = AppState.shared
    state.isConfigured = true
    state.apiBaseURL = "https://username-lifelog.web.val.run"

    return SettingsView()
        .environmentObject(state)
}

#Preview("Unconfigured") {
    let state = AppState.shared
    state.isConfigured = false

    return SettingsView()
        .environmentObject(state)
}
