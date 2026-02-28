import SwiftUI

/// Settings view for configuring API endpoints.
/// Accessible from the app menu or sidebar settings button.
struct SettingsView: View {
    @Environment(AppState.self) var appState
    @State private var llmTestResult: TestResult?
    @State private var geminiTestResult: TestResult?
    @State private var isTesting = false
    @State private var copyConfirmation = false
    @State private var lastLLMTestTime: Date?
    @State private var lastGeminiTestTime: Date?

    enum TestResult {
        case success(String)
        case failure(String)
    }

    /// Connection status indicator color for LLM
    private var llmStatusColor: Color {
        if let result = llmTestResult {
            switch result {
            case .success: return .green
            case .failure: return .red
            }
        }
        return .gray
    }

    /// Connection status indicator color for Gemini
    private var geminiStatusColor: Color {
        if let result = geminiTestResult {
            switch result {
            case .success: return .green
            case .failure: return .red
            }
        }
        return .gray
    }

    /// Whether the LLM URL is valid (starts with http)
    private var isLLMURLValid: Bool {
        appState.llmBaseURL.isEmpty || appState.llmBaseURL.lowercased().hasPrefix("http")
    }

    /// Whether the Gemini URL is valid (starts with http)
    private var isGeminiURLValid: Bool {
        appState.geminiBaseURL.isEmpty || appState.geminiBaseURL.lowercased().hasPrefix("http")
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
        .frame(width: 550, height: 450)
    }

    // MARK: - API Settings

    private var apiSettings: some View {
        @Bindable var appState = appState
        return Form {
            Section {
                TextField("https://api.anthropic.com", text: $appState.llmBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Anthropic Messages API endpoint")
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isLLMURLValid ? Color.clear : Color.red.opacity(0.6), lineWidth: 1)
                    )

                if !isLLMURLValid {
                    Text("URL must start with http:// or https://")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                SecureField("sk-ant-...", text: $appState.llmAPIKey)
                    .textFieldStyle(.roundedBorder)

                TextField("claude-sonnet-4-20250514", text: $appState.llmModel)
                    .textFieldStyle(.roundedBorder)
                    .help("Anthropic model ID")

                Text("Popular: claude-sonnet-4-20250514, claude-haiku-4-20250414, claude-opus-4-20250514")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(llmStatusColor)
                        .frame(width: 8, height: 8)
                    Text("LLM API (Plan Generation)")
                }
            }

            Section {
                TextField("https://generativelanguage.googleapis.com/v1beta/openai", text: $appState.geminiBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("OpenAI-compatible endpoint")
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isGeminiURLValid ? Color.clear : Color.red.opacity(0.6), lineWidth: 1)
                    )

                if !isGeminiURLValid {
                    Text("URL must start with http:// or https://")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                SecureField("API Key", text: $appState.geminiAPIKey)
                    .textFieldStyle(.roundedBorder)

                TextField("gemini-2.0-flash-preview-image-generation", text: $appState.geminiModel)
                    .textFieldStyle(.roundedBorder)
                    .help("Image generation model ID")

                Text("Popular: gemini-2.0-flash-preview-image-generation, gemini-2.0-flash-exp")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(geminiStatusColor)
                        .frame(width: 8, height: 8)
                    Text("Image Generation API (Backgrounds)")
                }
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
                    if let time = lastLLMTestTime {
                        Text("Last tested: \(time, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let result = geminiTestResult {
                    testResultView("Image Gen", result: result)
                    if let time = lastGeminiTestTime {
                        Text("Last tested: \(time, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Copy Configuration button
                HStack {
                    Spacer()
                    Button {
                        copyConfiguration()
                    } label: {
                        Label(
                            copyConfirmation ? "Copied!" : "Copy Configuration",
                            systemImage: copyConfirmation ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Reset to Defaults") {
                        appState.llmBaseURL = "https://api.anthropic.com"
                        appState.llmModel = "claude-sonnet-4-20250514"
                        appState.geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/openai"
                        appState.geminiModel = "gemini-2.0-flash-preview-image-generation"
                        // Don't reset API keys
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
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

    // MARK: - Copy Configuration

    private func copyConfiguration() {
        let config: [String: Any] = [
            "llm": [
                "baseURL": appState.llmBaseURL,
                "model": appState.llmModel
            ],
            "imageGeneration": [
                "baseURL": appState.geminiBaseURL,
                "model": appState.geminiModel
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)
            copyConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copyConfirmation = false
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

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

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
                    lastLLMTestTime = Date()
                } else if let http = response as? HTTPURLResponse {
                    var detail = "HTTP \(http.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        detail += " -- \(message)"
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
                    lastGeminiTestTime = Date()
                } else if let http = response as? HTTPURLResponse {
                    var detail = "HTTP \(http.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        detail += " -- \(message)"
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
