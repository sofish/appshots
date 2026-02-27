import SwiftUI

/// Settings view for configuring LLM and Gemini API endpoints.
/// Accessible from the app menu (⌘,) or sidebar settings button.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            apiSettings
                .tabItem {
                    Label("API", systemImage: "network")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - API Settings

    private var apiSettings: some View {
        Form {
            Section("LLM API (Plan Generation)") {
                TextField("Base URL", text: $appState.llmBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("OpenAI-compatible endpoint. e.g. https://api.openai.com/v1")

                SecureField("API Key", text: $appState.llmAPIKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Model", text: $appState.llmModel)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g. gpt-4o, claude-3.5-sonnet, etc.")
            }

            Section("Gemini API (Background Generation)") {
                TextField("Base URL", text: $appState.geminiBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Gemini API endpoint")

                SecureField("API Key", text: $appState.geminiAPIKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Model", text: $appState.geminiModel)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g. gemini-2.0-flash-exp")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Test LLM Connection") {
                        testLLMConnection()
                    }
                    .buttonStyle(.bordered)

                    Button("Test Gemini Connection") {
                        testGeminiConnection()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
        .padding()
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 48))
                .foregroundStyle(.accent)

            Text("AppShots")
                .font(.title.bold())

            Text("App Store Screenshot Generator")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Drop in screenshots + a Markdown description, get professional App Store screenshots powered by AI.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Divider()
                .frame(width: 200)

            VStack(spacing: 4) {
                Text("Built with SwiftUI + Core Graphics")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Zero third-party dependencies (except swift-markdown)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func testLLMConnection() {
        Task {
            await appState.syncServiceConfigs()
            // A quick test call would go here
        }
    }

    private func testGeminiConnection() {
        Task {
            await appState.syncServiceConfigs()
            // A quick test call would go here
        }
    }
}
