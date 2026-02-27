import Foundation

// MARK: - Layout Type

enum LayoutType: String, Codable, CaseIterable, Identifiable {
    case centerDevice = "center_device"
    case leftDevice = "left_device"
    case tilted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .centerDevice: return "Center Device"
        case .leftDevice: return "Left Device"
        case .tilted: return "Tilted 3D"
        }
    }

    var iconName: String {
        switch self {
        case .centerDevice: return "iphone"
        case .leftDevice: return "rectangle.lefthalf.inset.filled"
        case .tilted: return "rotate.3d"
        }
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
    var layout: LayoutType
    var visualDirection: String

    init(
        id: UUID = UUID(),
        index: Int,
        screenshotMatch: Int,
        heading: String,
        subheading: String,
        layout: LayoutType = .centerDevice,
        visualDirection: String = ""
    ) {
        self.id = id
        self.index = index
        self.screenshotMatch = screenshotMatch
        self.heading = heading
        self.subheading = subheading
        self.layout = layout
        self.visualDirection = visualDirection
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
}

extension ScreenConfig {
    enum CodingKeys: String, CodingKey {
        case id, index
        case screenshotMatch = "screenshot_match"
        case heading, subheading, layout
        case visualDirection = "visual_direction"
    }
}
