import Foundation

/// LLM Call #1: Generates a ScreenPlan from AppDescriptor + screenshots.
/// Takes the parsed Markdown structure and user screenshots, sends them to the LLM,
/// and receives back a JSON plan describing each screenshot's heading, subheading,
/// layout, and visual direction.
struct PlanGenerator {

    private let llmService: LLMService

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    func generate(
        descriptor: AppDescriptor,
        screenshotData: [Data],
        includeIPad: Bool = false
    ) async throws -> ScreenPlan {
        var systemPrompt = SystemPrompts.planGeneration
        if includeIPad {
            systemPrompt += SystemPrompts.iPadPlanAddendum
        }
        let userMessage = buildUserMessage(from: descriptor, screenshotCount: screenshotData.count, includeIPad: includeIPad)

        let response: String
        if screenshotData.isEmpty {
            response = try await llmService.chatCompletion(
                systemPrompt: systemPrompt,
                userMessage: userMessage,
                temperature: 0.7
            )
        } else {
            response = try await llmService.chatCompletionWithImages(
                systemPrompt: systemPrompt,
                userMessage: userMessage,
                imageDataArray: screenshotData,
                temperature: 0.7
            )
        }

        return try parseResponse(response)
    }

    // MARK: - Build user message from descriptor

    private func buildUserMessage(from desc: AppDescriptor, screenshotCount: Int, includeIPad: Bool = false) -> String {
        var parts: [String] = []

        parts.append("# \(desc.name)")
        parts.append("> \(desc.tagline)")
        parts.append("")
        parts.append("- **Category:** \(desc.category)")
        parts.append("- **Platforms:** \(desc.platforms.map(\.rawValue).joined(separator: ", "))")
        parts.append("- **Language:** \(desc.language)")
        parts.append("- **Style:** \(desc.style.rawValue)")
        parts.append("- **Colors:** \(desc.colors.primary), \(desc.colors.accent)")
        parts.append("")
        parts.append("## Core Value Proposition")
        parts.append(desc.corePitch)
        parts.append("")
        parts.append("## Feature Highlights")

        for feature in desc.features {
            parts.append("### \(feature.name)")
            parts.append(feature.description)
            parts.append("")
        }

        parts.append("## Target Audience")
        parts.append(desc.targetAudience)

        if let proof = desc.socialProof, !proof.isEmpty {
            parts.append("")
            parts.append("## Social Proof")
            parts.append(proof)
        }

        // Use screenshot count as primary driver; fall back to features if no screenshots
        let screenCount = screenshotCount > 0
            ? screenshotCount
            : max(desc.features.count, 3)
        parts.append("")
        parts.append("Number of screenshots provided: \(screenshotCount)")
        parts.append("Number of features described: \(desc.features.count)")
        parts.append("Please generate a screenshot plan with exactly \(screenCount) screens.")
        if desc.features.isEmpty {
            parts.append("Since no explicit features were listed, derive \(screenCount) key selling points from the app description and core pitch.")
        }

        if includeIPad {
            parts.append("")
            parts.append("IMPORTANT: This app also targets iPad. For EACH screen, include an `ipad_config` object.")
            parts.append("The iPad canvas is 2048×2732 (~3:4 ratio). Choose layouts that leverage the wider canvas.")
            parts.append("Use varied iPad layout types: standard, angled, frameless, headline_dominant, ui_forward.")
            parts.append("Write iPad-specific image_prompts that mention 'iPad' and describe the wider canvas composition.")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Parse LLM JSON response

    private func parseResponse(_ response: String) throws -> ScreenPlan {
        // Extract JSON from the response (may be wrapped in ```json ... ```)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw LLMService.LLMError.decodingFailed("Could not encode response as UTF-8")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ScreenPlan.self, from: data)
        } catch {
            let preview = String(jsonString.prefix(300))
            throw LLMService.LLMError.decodingFailed("\(error.localizedDescription)\nResponse preview: \(preview)")
        }
    }

    private func extractJSON(from text: String) -> String {
        // Try to find JSON block in markdown code fence
        if let startRange = text.range(of: "```json"),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find JSON block without language tag
        if let startRange = text.range(of: "```"),
           let endRange = text.range(of: "```", range: startRange.upperBound..<text.endIndex) {
            return String(text[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find raw JSON object
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
