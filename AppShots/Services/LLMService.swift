import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Unified HTTP client for LLM API calls.
/// Supports any OpenAI-compatible endpoint (configurable base URL).
actor LLMService {

    struct Configuration {
        var baseURL: String = "https://api.openai.com/v1"
        var apiKey: String = ""
        var model: String = "gpt-4o"
        var maxTokens: Int = 4096
        var temperature: Double = 0.7
    }

    enum LLMError: LocalizedError {
        case invalidURL
        case invalidResponse(Int)
        case decodingFailed(String)
        case emptyResponse
        case noAPIKey

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL."
            case .invalidResponse(let code): return "API returned status \(code)."
            case .decodingFailed(let detail): return "Failed to decode response: \(detail)"
            case .emptyResponse: return "Empty response from API."
            case .noAPIKey: return "No API key configured. Set it in Settings."
            }
        }
    }

    private var config: Configuration

    init(config: Configuration = .init()) {
        self.config = config
    }

    func updateConfig(_ config: Configuration) {
        self.config = config
    }

    // MARK: - Chat Completion (text only)

    func chatCompletion(
        systemPrompt: String,
        userMessage: String,
        temperature: Double? = nil
    ) async throws -> String {
        guard !config.apiKey.isEmpty else { throw LLMError.noAPIKey }

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userMessage]
        ]

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": temperature ?? config.temperature
        ]

        let data = try await post(path: "/chat/completions", body: body)
        return try extractContent(from: data)
    }

    // MARK: - Chat Completion with Images

    func chatCompletionWithImages(
        systemPrompt: String,
        userMessage: String,
        imageDataArray: [Data],
        temperature: Double? = nil
    ) async throws -> String {
        guard !config.apiKey.isEmpty else { throw LLMError.noAPIKey }

        // Build user content with text + images
        var userContent: [[String: Any]] = [
            ["type": "text", "text": userMessage]
        ]

        for imageData in imageDataArray {
            let base64 = imageData.base64EncodedString()
            userContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/png;base64,\(base64)"
                ]
            ])
        }

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContent]
        ]

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "max_tokens": config.maxTokens,
            "temperature": temperature ?? config.temperature
        ]

        let data = try await post(path: "/chat/completions", body: body)
        return try extractContent(from: data)
    }

    // MARK: - Internal HTTP

    private func post(path: String, body: [String: Any]) async throws -> Data {
        let urlString = config.baseURL.hasSuffix("/")
            ? config.baseURL + String(path.dropFirst())
            : config.baseURL + path

        guard let url = URL(string: urlString) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw LLMError.invalidResponse(httpResponse.statusCode)
        }

        return data
    }

    private func extractContent(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.emptyResponse
        }
        return content
    }
}
