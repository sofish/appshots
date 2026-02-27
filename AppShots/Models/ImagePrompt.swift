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
        self.negativePrompt = try container.decode(String.self, forKey: .negativePrompt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(screenIndex, forKey: .screenIndex)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(negativePrompt, forKey: .negativePrompt)
    }
}

// MARK: - Image Prompt Set

struct ImagePromptSet: Codable {
    var screens: [ImagePrompt]
}
