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

    enum CodingKeys: String, CodingKey {
        case id
        case screenIndex = "screen_index"
        case prompt
        case negativePrompt = "negative_prompt"
    }
}

// MARK: - Image Prompt Set

struct ImagePromptSet: Codable {
    var screens: [ImagePrompt]
}
