import Foundation

/// Generates background images using Gemini API (or compatible image generation endpoint).
/// Calls are made in parallel using Swift Concurrency TaskGroup.
actor BackgroundGenerator {

    struct Configuration {
        var baseURL: String = "https://generativelanguage.googleapis.com/v1beta"
        var apiKey: String = ""
        var model: String = "gemini-2.0-flash-exp"
    }

    enum GeneratorError: LocalizedError {
        case invalidURL
        case noAPIKey
        case generationFailed(String)
        case invalidImageData

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid Gemini API URL."
            case .noAPIKey: return "No Gemini API key configured."
            case .generationFailed(let msg): return "Image generation failed: \(msg)"
            case .invalidImageData: return "Generated image data is invalid."
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
        onProgress: @Sendable @escaping (Int, Data) -> Void
    ) async throws -> [Int: Data] {
        guard !config.apiKey.isEmpty else { throw GeneratorError.noAPIKey }

        return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for prompt in prompts {
                group.addTask {
                    let imageData = try await self.generateSingle(prompt: prompt)
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

    // MARK: - Generate single background

    func generateSingle(prompt: ImagePrompt) async throws -> Data {
        guard !config.apiKey.isEmpty else { throw GeneratorError.noAPIKey }

        let urlString = "\(config.baseURL)/models/\(config.model):generateContent?key=\(config.apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeneratorError.invalidURL
        }

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt.prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["image", "text"],
                "responseMimeType": "image/png"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw GeneratorError.generationFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        return try extractImageData(from: data)
    }

    // MARK: - Extract image from Gemini response

    private func extractImageData(from responseData: Data) throws -> Data {
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeneratorError.generationFailed("Unexpected response format")
        }

        // Look for inline_data with image
        for part in parts {
            if let inlineData = part["inline_data"] as? [String: Any],
               let base64 = inlineData["data"] as? String,
               let imageData = Data(base64Encoded: base64) {
                return imageData
            }
        }

        // Look for image in text response (base64 encoded)
        for part in parts {
            if let text = part["text"] as? String,
               let imageData = Data(base64Encoded: text) {
                return imageData
            }
        }

        throw GeneratorError.invalidImageData
    }
}
