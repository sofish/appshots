import SwiftUI

/// Settings view for configuring LLM and Gemini API endpoints.
/// Accessible from the app menu (⌘,) or sidebar settings button.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var llmTestResult: TestResult?
    @State private var geminiTestResult: TestResult?
    @State private var isTesting = false

    enum TestResult {
        case success(String)
        case failure(String)
    }

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
                    .disabled(isTesting || appState.llmAPIKey.isEmpty)

                    Button("Test Gemini Connection") {
                        testGeminiConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting || appState.geminiAPIKey.isEmpty)
                    Spacer()
                }

                if isTesting {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("Testing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                if let result = llmTestResult {
                    testResultView("LLM", result: result)
                }

                if let result = geminiTestResult {
                    testResultView("Gemini", result: result)
                }
            }
        }
        .padding()
    }

    private func testResultView(_ label: String, result: TestResult) -> some View {
        HStack(spacing: 6) {
            switch result {
            case .success(let msg):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(label): \(msg)")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failure(let msg):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("\(label): \(msg)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
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
        llmTestResult = nil
        isTesting = true
        Task {
            await appState.syncServiceConfigs()
            do {
                let url = appState.llmBaseURL.hasSuffix("/")
                    ? appState.llmBaseURL + "models"
                    : appState.llmBaseURL + "/models"
                guard let endpoint = URL(string: url) else {
                    llmTestResult = .failure("Invalid URL")
                    isTesting = false
                    return
                }
                var request = URLRequest(url: endpoint)
                request.setValue("Bearer \(appState.llmAPIKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 10
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    llmTestResult = .success("Connected (HTTP \(http.statusCode))")
                } else if let http = response as? HTTPURLResponse {
                    llmTestResult = .failure("HTTP \(http.statusCode)")
                }
            } catch {
                llmTestResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }

    private func testGeminiConnection() {
        geminiTestResult = nil
        isTesting = true
        Task {
            await appState.syncServiceConfigs()
            do {
                let url = "\(appState.geminiBaseURL)/models/\(appState.geminiModel)?key=\(appState.geminiAPIKey)"
                guard let endpoint = URL(string: url) else {
                    geminiTestResult = .failure("Invalid URL")
                    isTesting = false
                    return
                }
                var request = URLRequest(url: endpoint)
                request.timeoutInterval = 10
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    geminiTestResult = .success("Connected (HTTP \(http.statusCode))")
                } else if let http = response as? HTTPURLResponse {
                    geminiTestResult = .failure("HTTP \(http.statusCode)")
                }
            } catch {
                geminiTestResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
