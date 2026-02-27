import Foundation
import Markdown

/// Parses a structured Markdown document into an AppDescriptor.
///
/// Expected format:
/// ```
/// # App Name
/// > Tagline
/// - **类别：** Category
/// - **平台：** iOS / macOS
/// - **语言：** en
/// - **风格：** minimal
/// - **色调：** #hex1, #hex2
/// ## 核心卖点
/// Core pitch text
/// ## 功能亮点
/// ### Feature A
/// Description A
/// ### Feature B
/// Description B
/// ## 目标用户
/// Target audience text
/// ## 补充说明
/// Social proof text
/// ```
struct MarkdownParser {

    enum ParseError: LocalizedError {
        case emptyDocument
        case missingAppName
        case missingFeatures

        var errorDescription: String? {
            switch self {
            case .emptyDocument: return "The Markdown document is empty."
            case .missingAppName: return "Missing app name (# heading)."
            case .missingFeatures: return "No features found (### headings under 功能亮点/Features)."
            }
        }
    }

    func parse(_ source: String) throws -> AppDescriptor {
        let document = Document(parsing: source)
        var walker = DescriptorWalker()
        walker.visit(document)

        guard !walker.appName.isEmpty else {
            throw ParseError.missingAppName
        }

        return AppDescriptor(
            name: walker.appName,
            tagline: walker.tagline,
            category: walker.metadata["类别"] ?? walker.metadata["Category"] ?? "",
            platforms: parsePlatforms(walker.metadata["平台"] ?? walker.metadata["Platform"] ?? "iOS"),
            language: walker.metadata["语言"] ?? walker.metadata["Language"] ?? "en",
            style: parseStyle(walker.metadata["风格"] ?? walker.metadata["Style"] ?? "minimal"),
            colors: parseColors(walker.metadata["色调"] ?? walker.metadata["Colors"] ?? ""),
            corePitch: walker.corePitch,
            features: walker.features,
            targetAudience: walker.targetAudience,
            socialProof: walker.socialProof.isEmpty ? nil : walker.socialProof
        )
    }

    // MARK: - Private Helpers

    private func parsePlatforms(_ raw: String) -> [Platform] {
        let parts = raw.components(separatedBy: CharacterSet(charactersIn: "/,"))
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return parts.compactMap { part in
            switch part.lowercased() {
            case "ios": return .iOS
            case "ipados": return .iPadOS
            case "macos": return .macOS
            case "android": return .android
            default: return nil
            }
        }
    }

    private func parseStyle(_ raw: String) -> VisualStyle {
        VisualStyle(rawValue: raw.lowercased().trimmingCharacters(in: .whitespaces)) ?? .minimal
    }

    private func parseColors(_ raw: String) -> ColorPalette {
        let hexes = raw.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("#") }

        return ColorPalette(
            primary: hexes.first ?? "#0a0a0a",
            accent: hexes.count > 1 ? hexes[1] : "#3b82f6"
        )
    }
}

// MARK: - Markdown AST Walker

private struct DescriptorWalker: MarkupWalker {
    var appName = ""
    var tagline = ""
    var metadata: [String: String] = [:]
    var corePitch = ""
    var features: [Feature] = []
    var targetAudience = ""
    var socialProof = ""

    // State tracking
    private var currentH2Section = ""
    private var currentH3Name = ""
    private var collectingParagraph = false

    mutating func visitHeading(_ heading: Heading) {
        let text = heading.plainText
        switch heading.level {
        case 1:
            appName = text
        case 2:
            currentH2Section = text
            currentH3Name = ""
        case 3:
            if isFeatureSection {
                currentH3Name = text
            }
        default:
            break
        }
        descendInto(heading)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        // First blockquote after h1 = tagline
        if tagline.isEmpty {
            tagline = blockQuote.plainText
        }
        descendInto(blockQuote)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let text = listItem.plainText
        // Parse metadata items like "**类别：** iOS"
        if let (key, value) = parseMetadataItem(text) {
            metadata[key] = value
        }
        descendInto(listItem)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        let text = paragraph.plainText

        if isCorePitchSection && corePitch.isEmpty {
            corePitch = text
        } else if isFeatureSection && !currentH3Name.isEmpty {
            features.append(Feature(name: currentH3Name, description: text))
            currentH3Name = ""
        } else if isTargetAudienceSection && targetAudience.isEmpty {
            targetAudience = text
        } else if isSocialProofSection && socialProof.isEmpty {
            socialProof = text
        }

        descendInto(paragraph)
    }

    // MARK: - Section detection

    private var isCorePitchSection: Bool {
        let s = currentH2Section.lowercased()
        return s.contains("核心卖点") || s.contains("core") || s.contains("pitch") || s.contains("value")
    }

    private var isFeatureSection: Bool {
        let s = currentH2Section.lowercased()
        return s.contains("功能亮点") || s.contains("feature") || s.contains("highlight")
    }

    private var isTargetAudienceSection: Bool {
        let s = currentH2Section.lowercased()
        return s.contains("目标用户") || s.contains("target") || s.contains("audience")
    }

    private var isSocialProofSection: Bool {
        let s = currentH2Section.lowercased()
        return s.contains("补充说明") || s.contains("social") || s.contains("proof") || s.contains("supplement")
    }

    // MARK: - Metadata parsing

    private func parseMetadataItem(_ text: String) -> (String, String)? {
        // Match patterns like "**类别：** iOS" or "**Category:** iOS"
        // Strip bold markers and split on colon
        let cleaned = text
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Try both Chinese and English colons
        for separator in ["：", ":"] {
            if let range = cleaned.range(of: separator) {
                let key = String(cleaned[cleaned.startIndex..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let value = String(cleaned[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if !key.isEmpty && !value.isEmpty {
                    return (key, value)
                }
            }
        }
        return nil
    }
}

// MARK: - Markup text extraction

private extension Markup {
    var plainText: String {
        var result = ""
        for child in children {
            if let text = child as? Markdown.Text {
                result += text.string
            } else if let softBreak = child as? SoftBreak {
                result += " "
            } else if let code = child as? InlineCode {
                result += code.code
            } else if let strong = child as? Strong {
                result += strong.plainText
            } else if let emphasis = child as? Emphasis {
                result += emphasis.plainText
            } else {
                result += child.plainText
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
