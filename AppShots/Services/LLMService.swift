import Foundation

/// Unified HTTP client for LLM API calls.
/// Uses Anthropic Messages API format (compatible with Claude and Anthropic-style proxies).
actor LLMService {

    struct Configuration {
        var baseURL: String = ""
        var apiKey: String = ""
        var model: String = ""
        var maxTokens: Int = 4096
        var temperature: Double = 0.7
    }

    enum LLMError: LocalizedError {
        case invalidURL
        case invalidResponse(Int)
        case decodingFailed(String)
        case emptyResponse
        case noAPIKey
        case noBaseURL
        case rateLimited(retryAfter: Int?)
        case serverError(Int)
        case modelNotFound

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL."
            case .invalidResponse(let code): return "API returned status \(code)."
            case .decodingFailed(let detail): return "Failed to decode response: \(detail)"
            case .emptyResponse: return "Empty response from API."
            case .noAPIKey: return "No LLM API key configured. Set it in Settings."
            case .noBaseURL: return "No LLM base URL configured. Set it in Settings."
            case .rateLimited(let retryAfter):
                if let seconds = retryAfter {
                    return "Rate limited by API. Retry after \(seconds) seconds."
                }
                return "Rate limited by API."
            case .serverError(let code): return "API server error (HTTP \(code))."
            case .modelNotFound: return "The specified model was not found."
            }
        }

        var friendlyMessage: String {
            switch self {
            case .rateLimited:
                return "The API is rate-limited. Please wait a moment and try again."
            case .serverError:
                return "The API server is experiencing issues. Please try again later."
            case .modelNotFound:
                return "The specified model was not found. Check your model name in Settings."
            case .invalidURL:
                return "The API URL is invalid. Check your settings."
            case .noAPIKey, .noBaseURL:
                return "API configuration is incomplete. Open Settings to configure your API keys."
            case .invalidResponse:
                return "The API returned an unexpected response. Please try again."
            case .decodingFailed:
                return "The API response could not be understood. The format may have changed."
            case .emptyResponse:
                return "The API returned an empty response. Please try again."
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
        guard !config.baseURL.isEmpty else { throw LLMError.noBaseURL }
        guard !config.apiKey.isEmpty else { throw LLMError.noAPIKey }

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "temperature": temperature ?? config.temperature,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        let data = try await post(path: "/v1/messages", body: body)
        return try extractContent(from: data)
    }

    // MARK: - Chat Completion with Images

    func chatCompletionWithImages(
        systemPrompt: String,
        userMessage: String,
        imageDataArray: [Data],
        temperature: Double? = nil
    ) async throws -> String {
        guard !config.baseURL.isEmpty else { throw LLMError.noBaseURL }
        guard !config.apiKey.isEmpty else { throw LLMError.noAPIKey }

        // Build user content with images + text
        var userContent: [[String: Any]] = []

        for imageData in imageDataArray {
            let base64 = imageData.base64EncodedString()
            userContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/png",
                    "data": base64
                ]
            ])
        }

        userContent.append([
            "type": "text",
            "text": userMessage
        ])

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "temperature": temperature ?? config.temperature,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]

        let data = try await post(path: "/v1/messages", body: body)
        return try extractContent(from: data)
    }

    // MARK: - Internal HTTP

    private func post(path: String, body: [String: Any]) async throws -> Data {
        let base = config.baseURL.hasSuffix("/")
            ? String(config.baseURL.dropLast())
            : config.baseURL
        // If base already ends with /v1, strip /v1 prefix from path
        let resolvedPath = base.hasSuffix("/v1") ? String(path.dropFirst(3)) : path
        let urlString = base + resolvedPath

        guard let url = URL(string: urlString) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let statusCode = httpResponse.statusCode

            // Handle rate limiting (HTTP 429)
            if statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Int($0) }
                throw LLMError.rateLimited(retryAfter: retryAfter)
            }

            // Handle server errors (HTTP 5xx)
            if (500...599).contains(statusCode) {
                throw LLMError.serverError(statusCode)
            }

            // Handle model not found (HTTP 404 with model-related message)
            if statusCode == 404 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String,
                   message.lowercased().contains("model") {
                    throw LLMError.modelNotFound
                }
            }

            // Try to extract Anthropic error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw LLMError.decodingFailed("API error: \(message)")
            }
            throw LLMError.invalidResponse(statusCode)
        }

        return data
    }

    // MARK: - Extract text from Anthropic Messages response

    private func extractContent(from data: Data) throws -> String {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary data>"
            throw LLMError.decodingFailed("Response is not valid JSON. Preview: \(preview)")
        }

        guard let dict = json as? [String: Any] else {
            throw LLMError.decodingFailed("Expected JSON object at top level.")
        }

        // Check for Anthropic error response
        if let error = dict["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw LLMError.decodingFailed("API error: \(message)")
        }

        // Anthropic format: content[].text
        guard let content = dict["content"] as? [[String: Any]] else {
            throw LLMError.emptyResponse
        }

        // Collect all text blocks
        let texts = content.compactMap { block -> String? in
            guard (block["type"] as? String) == "text" else { return nil }
            return block["text"] as? String
        }

        guard !texts.isEmpty else {
            throw LLMError.emptyResponse
        }

        return texts.joined()
    }
}
