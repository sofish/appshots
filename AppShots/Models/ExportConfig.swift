import Foundation

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

    static let iPad13 = DeviceSize(
        id: "ipad_13",
        displayName: "iPad 13\"",
        width: 2048,
        height: 2732,
        isRequired: false
    )

    static let allSizes: [DeviceSize] = [
        .iPhone6_9, .iPhone6_7, .iPhone6_5, .iPhone5_5, .iPad13
    ]

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
}

