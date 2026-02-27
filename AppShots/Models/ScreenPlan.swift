import Foundation

// MARK: - Resolved Colors

struct ResolvedColors: Codable, Equatable {
    var primary: String    // background primary
    var accent: String     // accent color
    var text: String       // heading text color
    var subtext: String    // subheading text color

    static let `default` = ResolvedColors(
        primary: "#0a0a0a",
        accent: "#3b82f6",
        text: "#ffffff",
        subtext: "#a0a0a0"
    )
}

// MARK: - Screen Config

struct ScreenConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var index: Int
    var screenshotMatch: Int
    var heading: String
    var subheading: String
    var tilt: Bool
    var position: String       // "center", "left", "right"
    var fullBleed: Bool
    var visualDirection: String
    var imagePrompt: String    // Creative prompt for Gemini image generation

    init(
        id: UUID = UUID(),
        index: Int,
        screenshotMatch: Int,
        heading: String,
        subheading: String,
        tilt: Bool = false,
        position: String = "center",
        fullBleed: Bool = false,
        visualDirection: String = "",
        imagePrompt: String = ""
    ) {
        self.id = id
        self.index = index
        self.screenshotMatch = screenshotMatch
        self.heading = heading
        self.subheading = subheading
        self.tilt = tilt
        self.position = position
        self.fullBleed = fullBleed
        self.visualDirection = visualDirection
        self.imagePrompt = imagePrompt
    }
}

// MARK: - Screen Plan (LLM Call #1 output)

struct ScreenPlan: Codable, Equatable {
    var appName: String
    var tagline: String
    var tone: VisualStyle
    var colors: ResolvedColors
    var screens: [ScreenConfig]

    static let empty = ScreenPlan(
        appName: "",
        tagline: "",
        tone: .minimal,
        colors: .default,
        screens: []
    )
}

// MARK: - JSON coding keys for LLM response parsing

extension ScreenPlan {
    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case tagline, tone, colors, screens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.appName = try container.decodeIfPresent(String.self, forKey: .appName) ?? ""
        self.tagline = try container.decodeIfPresent(String.self, forKey: .tagline) ?? ""
        self.tone = (try? container.decode(VisualStyle.self, forKey: .tone)) ?? .minimal
        self.colors = try container.decodeIfPresent(ResolvedColors.self, forKey: .colors) ?? .default
        self.screens = try container.decode([ScreenConfig].self, forKey: .screens)
    }
}

extension ScreenConfig {
    // Only include keys the LLM will produce (no `id` — we generate it locally)
    enum CodingKeys: String, CodingKey {
        case index
        case screenshotMatch = "screenshot_match"
        case heading, subheading, tilt, position
        case fullBleed = "full_bleed"
        case visualDirection = "visual_direction"
        case imagePrompt = "image_prompt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // Auto-generate; LLM won't provide this
        self.index = try container.decode(Int.self, forKey: .index)
        self.screenshotMatch = try container.decodeIfPresent(Int.self, forKey: .screenshotMatch) ?? self.index
        self.heading = try container.decode(String.self, forKey: .heading)
        self.subheading = try container.decodeIfPresent(String.self, forKey: .subheading) ?? ""
        self.tilt = try container.decodeIfPresent(Bool.self, forKey: .tilt) ?? false
        self.position = try container.decodeIfPresent(String.self, forKey: .position) ?? "center"
        self.fullBleed = try container.decodeIfPresent(Bool.self, forKey: .fullBleed) ?? false
        self.visualDirection = try container.decodeIfPresent(String.self, forKey: .visualDirection) ?? ""
        self.imagePrompt = try container.decodeIfPresent(String.self, forKey: .imagePrompt) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(screenshotMatch, forKey: .screenshotMatch)
        try container.encode(heading, forKey: .heading)
        try container.encode(subheading, forKey: .subheading)
        try container.encode(tilt, forKey: .tilt)
        try container.encode(position, forKey: .position)
        try container.encode(fullBleed, forKey: .fullBleed)
        try container.encode(visualDirection, forKey: .visualDirection)
        try container.encode(imagePrompt, forKey: .imagePrompt)
    }
}
