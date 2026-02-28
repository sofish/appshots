import Foundation

// MARK: - iPad Layout Type

enum iPadLayoutType: String, Codable, CaseIterable, Identifiable {
    // Tier 1 — ship first
    case standard                               // Layout 1: centered iPad device frame
    case angled                                  // Layout 2: tilted 3D perspective
    case frameless                               // Layout 3: floating UI, rounded corners + shadow, no device chrome
    case headlineDominant = "headline_dominant"   // Layout 5: large text area (45%), smaller device below
    case uiForward = "ui_forward"                // Layout 7: full bleed, minimal/no text

    // Tier 2 — new compositor capabilities
    case multiOrientation = "multi_orientation"  // Layout 4: portrait + landscape devices
    case darkLightDual = "dark_light_dual"       // Layout 12: split dark/light mode
    case splitPanel = "split_panel"              // Layout 14: 2-3 panels showing different views
    case beforeAfter = "before_after"            // Layout 15: diagonal split transformation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Centered Device"
        case .angled: return "Angled 3D"
        case .frameless: return "Frameless"
        case .headlineDominant: return "Headline Dominant"
        case .uiForward: return "UI Forward"
        case .multiOrientation: return "Multi-Orientation"
        case .darkLightDual: return "Dark/Light Split"
        case .splitPanel: return "Side Text"
        case .beforeAfter: return "Before/After"
        }
    }

    /// Tier 1 layouts (fully implemented in compositor)
    /// All fully implemented layouts available in the UI picker
    static let supportedCases: [iPadLayoutType] = [.standard, .angled, .frameless, .headlineDominant, .uiForward, .darkLightDual, .splitPanel]

    /// Derive an iPad layout from iPhone layout modifiers
    static func fromIPhoneModifiers(tilt: Bool, position: String, fullBleed: Bool) -> iPadLayoutType {
        if fullBleed { return .uiForward }
        if tilt { return .angled }
        if position == "left" || position == "right" { return .headlineDominant }
        return .standard
    }
}

// MARK: - iPad Screen Config

struct iPadScreenConfig: Codable, Equatable {
    var layoutType: iPadLayoutType
    var orientation: String    // "portrait" or "landscape"
    var imagePrompt: String
    var visualDirection: String
    var secondaryScreenshotMatch: Int?  // For dual-screenshot layouts (dark/light, before/after)

    init(
        layoutType: iPadLayoutType = .standard,
        orientation: String = "portrait",
        imagePrompt: String = "",
        visualDirection: String = "",
        secondaryScreenshotMatch: Int? = nil
    ) {
        self.layoutType = layoutType
        self.orientation = orientation
        self.imagePrompt = imagePrompt
        self.visualDirection = visualDirection
        self.secondaryScreenshotMatch = secondaryScreenshotMatch
    }

    enum CodingKeys: String, CodingKey {
        case layoutType = "layout_type"
        case orientation
        case imagePrompt = "image_prompt"
        case visualDirection = "visual_direction"
        case secondaryScreenshotMatch = "secondary_screenshot_match"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.layoutType = (try? container.decode(iPadLayoutType.self, forKey: .layoutType)) ?? .standard
        self.orientation = try container.decodeIfPresent(String.self, forKey: .orientation) ?? "portrait"
        self.imagePrompt = try container.decodeIfPresent(String.self, forKey: .imagePrompt) ?? ""
        self.visualDirection = try container.decodeIfPresent(String.self, forKey: .visualDirection) ?? ""
        self.secondaryScreenshotMatch = try container.decodeIfPresent(Int.self, forKey: .secondaryScreenshotMatch)
    }
}

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
    var iPadConfig: iPadScreenConfig?  // iPad-specific layout; nil = derive from iPhone modifiers

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
        imagePrompt: String = "",
        iPadConfig: iPadScreenConfig? = nil
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
        self.iPadConfig = iPadConfig
    }

    /// Returns the iPad config, deriving from iPhone modifiers if not explicitly set.
    var resolvedIPadConfig: iPadScreenConfig {
        if let config = iPadConfig { return config }
        return iPadScreenConfig(
            layoutType: iPadLayoutType.fromIPhoneModifiers(tilt: tilt, position: position, fullBleed: fullBleed)
        )
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

    /// Returns a list of warning messages about potential issues with this plan.
    func validate() -> [String] {
        var warnings: [String] = []

        for screen in screens {
            if screen.heading.count > 40 {
                warnings.append("Screen \(screen.index): heading is over 40 characters (too long for thumbnail)")
            }
            if screen.heading.isEmpty {
                warnings.append("Screen \(screen.index): heading is empty")
            }
        }

        if screens.count > 1 {
            let positions = Set(screens.map { $0.position })
            if positions.count == 1 {
                warnings.append("All screens use the same position (\(positions.first ?? "center")) — consider adding layout variety")
            }
        }

        let tiltCount = screens.filter { $0.tilt }.count
        if tiltCount > 2 {
            warnings.append("More than 2 screens have tilt enabled (\(tiltCount)) — may feel repetitive")
        }

        let fullBleedCount = screens.filter { $0.fullBleed }.count
        if fullBleedCount > 1 {
            warnings.append("More than 1 screen has fullBleed enabled (\(fullBleedCount)) — use sparingly for impact")
        }

        return warnings
    }

    /// Returns true if there are no validation warnings.
    var isValid: Bool {
        validate().isEmpty
    }

    /// Randomizes the positions and tilt values while maintaining good variety.
    mutating func shuffleLayouts() {
        let positions = ["center", "left", "right"]
        for i in screens.indices {
            screens[i].position = positions[i % positions.count]
            screens[i].tilt = (i % 3 == 1) // Every 3rd screen gets tilt
        }
    }

    /// Duplicates the screen at the given index and appends the copy to the end.
    mutating func duplicateScreen(at index: Int) {
        guard index >= 0 && index < screens.count else { return }
        var copy = screens[index]
        copy = ScreenConfig(
            index: screens.count,
            screenshotMatch: copy.screenshotMatch,
            heading: copy.heading,
            subheading: copy.subheading,
            tilt: copy.tilt,
            position: copy.position,
            fullBleed: copy.fullBleed,
            visualDirection: copy.visualDirection,
            imagePrompt: copy.imagePrompt,
            iPadConfig: copy.iPadConfig
        )
        screens.append(copy)
    }

    /// Removes the screen at the given index and re-indexes remaining screens.
    mutating func removeScreen(at index: Int) {
        guard index >= 0 && index < screens.count else { return }
        screens.remove(at: index)
        // Re-index remaining screens
        for i in screens.indices {
            screens[i].index = i
        }
    }

    /// Scores the overall headline quality (0.0-1.0).
    /// +0.2 for each headline starting with a verb, +0.1 for 3-5 word headlines,
    /// -0.1 for headlines over 7 words. Normalized to 0.0-1.0 range.
    var headlineQuality: Double {
        guard !screens.isEmpty else { return 0.0 }

        let commonVerbs = Set([
            "get", "find", "track", "manage", "create", "build", "discover", "explore",
            "share", "save", "start", "stop", "make", "take", "keep", "see", "view",
            "plan", "organize", "connect", "sync", "send", "capture", "record", "edit",
            "design", "customize", "unlock", "boost", "master", "transform", "simplify",
            "automate", "monitor", "control", "schedule", "browse", "search", "stream",
            "learn", "achieve", "enjoy", "experience", "elevate", "optimize", "access"
        ])

        var rawScore: Double = 0.0

        for screen in screens {
            let words = screen.heading.split(separator: " ")
            let firstWord = words.first.map { String($0).lowercased() } ?? ""

            if commonVerbs.contains(firstWord) {
                rawScore += 0.2
            }
            if words.count >= 3 && words.count <= 5 {
                rawScore += 0.1
            }
            if words.count > 7 {
                rawScore -= 0.1
            }
        }

        // Normalize: max possible per screen is 0.3 (verb + word count)
        let maxPossible = Double(screens.count) * 0.3
        let normalized = rawScore / maxPossible
        return min(max(normalized, 0.0), 1.0)
    }
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
        case iPadConfig = "ipad_config"
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
        self.iPadConfig = try container.decodeIfPresent(iPadScreenConfig.self, forKey: .iPadConfig)
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
        try container.encodeIfPresent(iPadConfig, forKey: .iPadConfig)
    }
}
