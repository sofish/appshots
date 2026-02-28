import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Device Type

enum DeviceType: String, Codable, CaseIterable, Identifiable {
    case iPhone
    case iPad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iPhone: return "iPhone"
        case .iPad: return "iPad"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .iPhone: return 19.5 / 9.0
        case .iPad: return 2732.0 / 2048.0
        }
    }

    var defaultSize: DeviceSize {
        switch self {
        case .iPhone: return .iPhone6_7
        case .iPad: return .iPad13
        }
    }
}

// MARK: - Device Size

struct DeviceSize: Identifiable, Hashable {
    let id: String
    let displayName: String
    let width: Int
    let height: Int
    let isRequired: Bool

    var pixelSize: String { "\(width) × \(height)" }

    // The frame asset name in the bundle
    var frameAssetName: String { "frame_\(id)" }

    var deviceType: DeviceType {
        id.hasPrefix("ipad") ? .iPad : .iPhone
    }
}

extension DeviceSize {
    static let iPhone6_9 = DeviceSize(
        id: "iphone_6.9",
        displayName: "iPhone 6.9\"",
        width: 1320,
        height: 2868,
        isRequired: true
    )

    static let iPhone6_7 = DeviceSize(
        id: "iphone_6.7",
        displayName: "iPhone 6.7\"",
        width: 1290,
        height: 2796,
        isRequired: true
    )

    static let iPhone6_5 = DeviceSize(
        id: "iphone_6.5",
        displayName: "iPhone 6.5\"",
        width: 1242,
        height: 2688,
        isRequired: false
    )

    static let iPhone5_5 = DeviceSize(
        id: "iphone_5.5",
        displayName: "iPhone 5.5\"",
        width: 1242,
        height: 2208,
        isRequired: false
    )

    static let iPhone6_1 = DeviceSize(
        id: "iphone_6.1",
        displayName: "iPhone 6.1\"",
        width: 1179,
        height: 2556,
        isRequired: false
    )

    static let iPad13 = DeviceSize(
        id: "ipad_13",
        displayName: "iPad 13\" (Portrait)",
        width: 2048,
        height: 2732,
        isRequired: false
    )

    static let iPad13Landscape = DeviceSize(
        id: "ipad_13_landscape",
        displayName: "iPad 13\" (Landscape)",
        width: 2732,
        height: 2048,
        isRequired: false
    )

    static let allSizes: [DeviceSize] = [
        .iPhone6_9, .iPhone6_7, .iPhone6_5, .iPhone5_5, .iPhone6_1, .iPad13, .iPad13Landscape
    ]

    static var recommendedSizes: [DeviceSize] {
        allSizes.filter { $0.isRequired }
    }

    static let defaultSizes: [DeviceSize] = [
        .iPhone6_9, .iPhone6_7
    ]
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }
}

// MARK: - Export Config

struct ExportConfig {
    var sizes: [DeviceSize] = DeviceSize.defaultSizes
    var format: ExportFormat = .png
    var jpegQuality: Double = 0.9
    var maxFileSizeMB: Double = 10.0   // App Store limit

    static let `default` = ExportConfig()

    static func estimatedFileSize(pixelCount: Int, format: ExportFormat, quality: Double) -> Int {
        switch format {
        case .png:
            return pixelCount * 4
        case .jpeg:
            return Int(Double(pixelCount) * 3.0 * quality * 0.15)
        }
    }
}

