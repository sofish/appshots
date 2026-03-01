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

    /// Recommended number of screenshots: always between 3 and 6, based on feature count.
    var screenshotCountRecommendation: Int {
        min(max(features.count, 3), 6)
    }

    /// One-line summary of the app descriptor.
    var briefSummary: String {
        "\(name) - \(category) (\(style.rawValue)) - \(features.count) features"
    }

    /// Returns the primary color if non-empty, otherwise a default dark color.
    var dominantColor: String {
        colors.primary.isEmpty ? "#0a0a0a" : colors.primary
    }

    /// Returns true if all essential fields are filled in.
    var isComplete: Bool {
        !name.isEmpty && !tagline.isEmpty && !features.isEmpty && !corePitch.isEmpty
    }

    /// One-line summary of the first few features.
    var featuresSummary: String {
        features.prefix(3).map(\.name).joined(separator: ", ") + (features.count > 3 ? " +\(features.count - 3) more" : "")
    }

    /// Returns true if the descriptor has the minimum content needed to proceed.
    var hasMinimumContent: Bool {
        !name.isEmpty && !features.isEmpty && !corePitch.isEmpty
    }
}
