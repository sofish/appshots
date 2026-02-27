import SwiftUI

/// Settings view for configuring API endpoints.
/// Accessible from the app menu or sidebar settings button.
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
                TextField("https://api.anthropic.com", text: $appState.llmBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Anthropic Messages API endpoint")

                SecureField("sk-ant-...", text: $appState.llmAPIKey)
                    .textFieldStyle(.roundedBorder)

                TextField("claude-sonnet-4-20250514", text: $appState.llmModel)
                    .textFieldStyle(.roundedBorder)
                    .help("Anthropic model ID")
            }

            Section("Image Generation API (Backgrounds)") {
                TextField("https://generativelanguage.googleapis.com/v1beta/openai", text: $appState.geminiBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("OpenAI-compatible endpoint")

                SecureField("API Key", text: $appState.geminiAPIKey)
                    .textFieldStyle(.roundedBorder)

                TextField("gemini-2.0-flash-preview-image-generation", text: $appState.geminiModel)
                    .textFieldStyle(.roundedBorder)
                    .help("Image generation model ID")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Test LLM Connection") {
                        testLLMConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting || appState.llmAPIKey.isEmpty || appState.llmBaseURL.isEmpty)

                    Button("Test Image Gen Connection") {
                        testGeminiConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTesting || appState.geminiAPIKey.isEmpty || appState.geminiBaseURL.isEmpty)
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
                    testResultView("Image Gen", result: result)
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
                .foregroundStyle(Color.accentColor)

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

    // MARK: - Connection Test (Anthropic Messages API)

    private func testLLMConnection() {
        llmTestResult = nil
        isTesting = true
        Task {
            await appState.syncServiceConfigs()
            do {
                let base = appState.llmBaseURL.hasSuffix("/")
                    ? String(appState.llmBaseURL.dropLast())
                    : appState.llmBaseURL
                let urlString = base.hasSuffix("/v1")
                    ? base + "/messages"
                    : base + "/v1/messages"
                guard let endpoint = URL(string: urlString) else {
                    llmTestResult = .failure("Invalid URL")
                    isTesting = false
                    return
                }

                let body: [String: Any] = [
                    "model": appState.llmModel,
                    "max_tokens": 16,
                    "messages": [["role": "user", "content": "Hi"]]
                ]

                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(appState.llmAPIKey, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = 15

                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    llmTestResult = .success("Connected (HTTP \(http.statusCode))")
                } else if let http = response as? HTTPURLResponse {
                    var detail = "HTTP \(http.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        detail += " — \(message)"
                    }
                    llmTestResult = .failure(detail)
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
                let base = appState.geminiBaseURL.hasSuffix("/")
                    ? String(appState.geminiBaseURL.dropLast())
                    : appState.geminiBaseURL
                let urlString: String
                if base.hasSuffix("/chat/completions") {
                    urlString = base
                } else if base.hasSuffix("/v1") || base.hasSuffix("/v1beta/openai") {
                    urlString = base + "/chat/completions"
                } else {
                    urlString = base + "/v1/chat/completions"
                }
                guard let endpoint = URL(string: urlString) else {
                    geminiTestResult = .failure("Invalid URL")
                    isTesting = false
                    return
                }

                let body: [String: Any] = [
                    "model": appState.geminiModel,
                    "max_tokens": 16,
                    "messages": [["role": "user", "content": "Hi"]]
                ]

                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(appState.geminiAPIKey)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = 15

                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    geminiTestResult = .success("Connected (HTTP \(http.statusCode))")
                } else if let http = response as? HTTPURLResponse {
                    var detail = "HTTP \(http.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        detail += " — \(message)"
                    }
                    geminiTestResult = .failure(detail)
                }
            } catch {
                geminiTestResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
