import Foundation

/// Generates background images using an OpenAI-compatible Chat Completions API endpoint.
/// Works with OpenAI, OpenRouter, Google Gemini (via OpenAI-compat), LiteLLM, etc.
actor BackgroundGenerator {

    struct Configuration {
        var baseURL: String = ""
        var apiKey: String = ""
        var model: String = ""
        var timeoutInterval: TimeInterval = 120
    }

    enum GeneratorError: LocalizedError {
        case invalidURL
        case noAPIKey
        case noBaseURL
        case generationFailed(String)
        case invalidImageData
        case timeout(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL."
            case .noAPIKey: return "No image generation API key configured. Set it in Settings."
            case .noBaseURL: return "No image generation base URL configured. Set it in Settings."
            case .generationFailed(let msg): return "Image generation failed: \(msg)"
            case .invalidImageData: return "Generated image data is invalid."
            case .timeout(let seconds): return "Image generation timed out after \(seconds) seconds."
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

    // MARK: - Generate all backgrounds in parallel

    func generateAll(
        prompts: [ImagePrompt],
        screenshotDataMap: [Int: Data] = [:],
        onProgress: @Sendable @escaping (Int, Data) -> Void
    ) async throws -> [Int: Data] {
        guard !config.baseURL.isEmpty else { throw GeneratorError.noBaseURL }
        guard !config.apiKey.isEmpty else { throw GeneratorError.noAPIKey }

        return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for prompt in prompts {
                let screenshotData = screenshotDataMap[prompt.screenIndex]
                group.addTask {
                    let imageData = try await self.generateWithRetry(prompt: prompt, screenshotData: screenshotData)
                    onProgress(prompt.screenIndex, imageData)
                    return (prompt.screenIndex, imageData)
                }
            }

            var results: [Int: Data] = [:]
            for try await (index, data) in group {
                results[index] = data
            }
            return results
        }
    }

    // MARK: - Generate with retry logic

    private func generateWithRetry(
        prompt: ImagePrompt,
        screenshotData: Data? = nil,
        maxRetries: Int = 2
    ) async throws -> Data {
        let timeoutSeconds: UInt64 = 90
        var lastError: Error?

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = attempt == 1 ? 2 : 4
                print("[BackgroundGenerator] Retry attempt \(attempt)/\(maxRetries) for screen \(prompt.screenIndex) after \(delay)s delay")
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }

            do {
                let result = try await withThrowingTaskGroup(of: Data.self) { group in
                    group.addTask {
                        try await self.generateSingle(prompt: prompt, screenshotData: screenshotData)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                        throw GeneratorError.timeout(Int(timeoutSeconds))
                    }

                    let data = try await group.next()!
                    group.cancelAll()
                    return data
                }
                return result
            } catch {
                lastError = error
                if error is GeneratorError, case GeneratorError.timeout = error {
                    print("[BackgroundGenerator] Generation timed out after \(timeoutSeconds)s for screen \(prompt.screenIndex)")
                } else {
                    print("[BackgroundGenerator] Generation failed for screen \(prompt.screenIndex): \(error.localizedDescription)")
                }
            }
        }

        throw lastError!
    }

    // MARK: - Generate single background (OpenAI-compatible Chat Completions)

    func generateSingle(prompt: ImagePrompt, screenshotData: Data? = nil) async throws -> Data {
        guard !config.baseURL.isEmpty else { throw GeneratorError.noBaseURL }
        guard !config.apiKey.isEmpty else { throw GeneratorError.noAPIKey }

        let base = config.baseURL.hasSuffix("/")
            ? String(config.baseURL.dropLast())
            : config.baseURL
        let urlString: String
        if base.hasSuffix("/chat/completions") {
            urlString = base
        } else if base.hasSuffix("/v1") || base.hasSuffix("/v1beta/openai") {
            urlString = base + "/chat/completions"
        } else {
            urlString = base + "/v1/chat/completions"
        }
        guard let url = URL(string: urlString) else {
            throw GeneratorError.invalidURL
        }

        // Build message content — multimodal if screenshot data provided
        let messageContent: Any
        if let screenshotData = screenshotData {
            let base64 = screenshotData.base64EncodedString()
            messageContent = [
                ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                ["type": "text", "text": prompt.prompt]
            ] as [[String: Any]]
        } else {
            messageContent = prompt.prompt
        }

        let requestBody: [String: Any] = [
            "model": config.model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": messageContent]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = config.timeoutInterval

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GeneratorError.generationFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return try await extractImageData(from: data)
    }

    // MARK: - Extract image from OpenAI-compatible response

    private func extractImageData(from responseData: Data) async throws -> Data {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: responseData)
        } catch {
            let preview = String(data: responseData.prefix(500), encoding: .utf8) ?? "<binary>"
            throw GeneratorError.generationFailed("Response is not valid JSON: \(preview)")
        }

        guard let dict = json as? [String: Any] else {
            throw GeneratorError.generationFailed("Expected JSON object at top level.")
        }

        // Check for API error response
        if let error = dict["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw GeneratorError.generationFailed("API error: \(message)")
        }

        // OpenAI Chat Completions format: choices[].message.content
        if let choices = dict["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any] {

            // content can be a string or an array of content parts
            if let contentArray = message["content"] as? [[String: Any]] {
                // Multimodal response: array of parts
                for part in contentArray {
                    if let imageData = extractImageFromPart(part) {
                        return imageData
                    }
                }
                // Fallback: try base64 from text parts
                for part in contentArray {
                    if (part["type"] as? String) == "text",
                       let text = part["text"] as? String,
                       let imageData = extractBase64FromText(text) {
                        return imageData
                    }
                }
            } else if let contentString = message["content"] as? String {
                // Plain text response — try to decode as base64
                if let imageData = extractBase64FromText(contentString) {
                    return imageData
                }
            }
        }

        // OpenAI Images API format: data[].b64_json
        if let dataArray = dict["data"] as? [[String: Any]] {
            for item in dataArray {
                if let b64 = item["b64_json"] as? String,
                   let imageData = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
                   imageData.count > 100 {
                    return imageData
                }
                // Also check url field and download
                if let urlStr = item["url"] as? String,
                   let url = URL(string: urlStr) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if data.count > 100 {
                        return data
                    }
                }
            }
        }

        let preview = String(data: responseData.prefix(500), encoding: .utf8) ?? ""
        let topLevelKeys = (dict as NSDictionary).allKeys.map { "\($0)" }.joined(separator: ", ")
        throw GeneratorError.generationFailed("No image data found. Response keys: [\(topLevelKeys)]. Preview: \(preview)")
    }

    /// Extract image data from a multimodal content part.
    private func extractImageFromPart(_ part: [String: Any]) -> Data? {
        let type = part["type"] as? String

        // OpenAI format: { "type": "image_url", "image_url": { "url": "data:image/png;base64,..." } }
        if type == "image_url",
           let imageUrl = part["image_url"] as? [String: Any],
           let urlStr = imageUrl["url"] as? String {
            return extractBase64FromText(urlStr)
        }

        // Inline base64: { "type": "image", "data": "...", "media_type": "..." }
        if type == "image",
           let b64 = part["data"] as? String,
           let imageData = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
           imageData.count > 100 {
            return imageData
        }

        // Gemini-via-OpenAI: { "type": "image", "image": { "url": "data:..." } }
        if type == "image",
           let imageDict = part["image"] as? [String: Any],
           let urlStr = imageDict["url"] as? String {
            return extractBase64FromText(urlStr)
        }

        return nil
    }

    /// Try to extract base64-encoded image data from a text string.
    private func extractBase64FromText(_ text: String) -> Data? {
        // Direct base64 decode
        if let imageData = Data(base64Encoded: text, options: .ignoreUnknownCharacters),
           imageData.count > 100 {
            return imageData
        }

        // Data URI: data:image/png;base64,...
        if let range = text.range(of: "base64,") {
            let b64 = String(text[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet(charactersIn: "\"' \n")).first ?? ""
            if let imageData = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
               imageData.count > 100 {
                return imageData
            }
        }

        return nil
    }
}
