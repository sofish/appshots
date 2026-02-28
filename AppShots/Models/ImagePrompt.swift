import Foundation

// MARK: - Image Prompt (LLM Call #2 output)

struct ImagePrompt: Identifiable, Codable, Equatable {
    var id: UUID
    var screenIndex: Int
    var prompt: String
    var negativePrompt: String

    init(id: UUID = UUID(), screenIndex: Int, prompt: String, negativePrompt: String) {
        self.id = id
        self.screenIndex = screenIndex
        self.prompt = prompt
        self.negativePrompt = negativePrompt
    }

    // Only include keys the LLM will produce (no `id` — we generate it locally)
    enum CodingKeys: String, CodingKey {
        case screenIndex = "screen_index"
        case prompt
        case negativePrompt = "negative_prompt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.screenIndex = try container.decode(Int.self, forKey: .screenIndex)
        self.prompt = try container.decode(String.self, forKey: .prompt)
        self.negativePrompt = try container.decodeIfPresent(String.self, forKey: .negativePrompt) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(screenIndex, forKey: .screenIndex)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(negativePrompt, forKey: .negativePrompt)
    }

    /// Number of words in the prompt.
    var wordCount: Int {
        prompt.split(separator: " ").count
    }

    /// Quality score (0.0-1.0) based on prompt content analysis.
    var qualityScore: Double {
        var score: Double = 0.0
        let lowered = prompt.lowercased()

        // +0.3 if prompt mentions a device
        let deviceKeywords = ["iphone", "ipad", "device", "mockup"]
        if deviceKeywords.contains(where: { lowered.contains($0) }) {
            score += 0.3
        }

        // +0.2 if prompt includes quoted heading text
        if prompt.contains("\"") {
            score += 0.2
        }

        // +0.2 if prompt mentions colors or hex values
        if prompt.contains("#") {
            score += 0.2
        }

        // +0.2 if prompt mentions quality keywords
        let qualityKeywords = ["premium", "editorial", "professional", "studio"]
        if qualityKeywords.contains(where: { lowered.contains($0) }) {
            score += 0.2
        }

        // +0.1 if word count is in the sweet spot (20-60)
        if wordCount >= 20 && wordCount <= 60 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    /// True if the prompt has fewer than 10 words.
    var isMinimal: Bool {
        wordCount < 10
    }
}

// MARK: - Image Prompt Set

struct ImagePromptSet: Codable {
    var screens: [ImagePrompt]
}
