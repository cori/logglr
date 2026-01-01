import SwiftUI
import LifeLogKit

struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isConfigured {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {

    var body: some View {
        TabView {
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {

    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("Welcome to LifeLog")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Track your life, one moment at a time")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showSettings = true
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text("You'll need to configure your API settings first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .padding()
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - Previews

#Preview("Configured") {
    ContentView()
        .environmentObject(AppState.shared)
        .environment(\.modelContext, PersistenceController.preview().mainContext)
}

#Preview("Onboarding") {
    let state = AppState.shared
    state.isConfigured = false

    return ContentView()
        .environmentObject(state)
}
