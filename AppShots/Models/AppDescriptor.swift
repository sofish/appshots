import Foundation

// MARK: - Visual Style

enum VisualStyle: String, Codable, CaseIterable, Identifiable {
    case minimal
    case playful
    case professional
    case bold
    case elegant

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Platform

enum Platform: String, Codable, CaseIterable, Identifiable {
    case iOS
    case iPadOS
    case macOS
    case android = "Android"

    var id: String { rawValue }
}

// MARK: - Color Palette

struct ColorPalette: Codable, Equatable {
    var primary: String   // hex e.g. "#0a0a0a"
    var accent: String    // hex e.g. "#3b82f6"

    static let `default` = ColorPalette(primary: "#0a0a0a", accent: "#3b82f6")
}

// MARK: - Feature

struct Feature: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String

    init(id: UUID = UUID(), name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
}

// MARK: - App Descriptor (Markdown parse output)

struct AppDescriptor: Codable, Equatable {
    var name: String
    var tagline: String
    var category: String
    var platforms: [Platform]
    var language: String
    var style: VisualStyle
    var colors: ColorPalette
    var corePitch: String
    var features: [Feature]
    var targetAudience: String
    var socialProof: String?

    static let empty = AppDescriptor(
        name: "",
        tagline: "",
        category: "",
        platforms: [.iOS],
        language: "en",
        style: .minimal,
        colors: .default,
        corePitch: "",
        features: [],
        targetAudience: "",
        socialProof: nil
    )
}
