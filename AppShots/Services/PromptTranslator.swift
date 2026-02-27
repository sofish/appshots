import Foundation

/// LLM Call #2: Translates visual directions from ScreenPlan into
/// optimized Gemini image generation prompts.
struct PromptTranslator {

    private let llmService: LLMService

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    func translate(plan: ScreenPlan) async throws -> [ImagePrompt] {
        let systemPrompt = SystemPrompts.promptTranslation
        let userMessage = buildUserMessage(from: plan)

        let response = try await llmService.chatCompletion(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            temperature: 0.5
        )

        return try parseResponse(response)
    }

    // MARK: - Build user message

    private func buildUserMessage(from plan: ScreenPlan) -> String {
        var parts: [String] = []
        parts.append("App: \(plan.appName)")
        parts.append("Tone: \(plan.tone.rawValue)")
        parts.append("Colors: primary=\(plan.colors.primary), accent=\(plan.colors.accent), text=\(plan.colors.text), subtext=\(plan.colors.subtext)")
        parts.append("")
        parts.append("Screens to generate backgrounds for:")
        parts.append("")

        for screen in plan.screens {
            parts.append("Screen \(screen.index):")
            parts.append("  Heading: \(screen.heading)")
            parts.append("  Layout: \(screen.layout.rawValue)")
            parts.append("  Visual Direction: \(screen.visualDirection)")
            parts.append("")
        }

        parts.append("Output target resolution: 1290x2796 pixels (iPhone portrait)")
        parts.append("Generate ONLY background images — no text, no device frames, no UI elements.")

        return parts.joined(separator: "\n")
    }

    // MARK: - Parse response

    private func parseResponse(_ response: String) throws -> [ImagePrompt] {
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw LLMService.LLMError.decodingFailed("Could not encode response as UTF-8")
        }

        let decoder = JSONDecoder()

        // Try parsing as { "screens": [...] } first
        if let set = try? decoder.decode(ImagePromptSet.self, from: data) {
            return set.screens
        }

        // Try parsing as a plain array
        if let array = try? decoder.decode([ImagePrompt].self, from: data) {
            return array
        }

        throw LLMService.LLMError.decodingFailed("Could not parse image prompts from response")
    }

    private func extractJSON(from text: String) -> String {
        if let startRange = text.range(of: "```json"),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let startRange = text.range(of: "```"),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let start = text.firstIndex(where: { $0 == "{" || $0 == "[" }),
           let end = text.lastIndex(where: { $0 == "}" || $0 == "]" }) {
            return String(text[start...end])
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
