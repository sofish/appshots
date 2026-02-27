import Foundation
#if canImport(AppKit)
import AppKit
#endif
import CoreGraphics

/// Manages device frame assets and handles screenshot embedding into frames.
///
/// The device frame is loaded from the app's Asset Catalog. If no frame asset
/// is available, the Compositor falls back to drawing a simple bezel.
///
/// Research insight: ~50% of top apps use realistic device mockups.
/// Clay mockups (solid-color silhouettes) are trending for premium apps.
/// Always use current-generation devices — outdated frames signal an abandoned app.
struct DeviceFrame {

    enum FrameStyle: String, CaseIterable, Identifiable {
        case realistic     // Photorealistic device frame
        case clay          // Solid-color minimalist silhouette
        case minimal       // Thin outline only
        case none          // No frame at all

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .realistic: return "Realistic"
            case .clay: return "Clay"
            case .minimal: return "Minimal"
            case .none: return "No Frame"
            }
        }
    }

    // MARK: - Frame Loading

    #if canImport(AppKit)
    /// Load a device frame image from the bundle's Asset Catalog.
    func loadFrame(for device: DeviceSize = .iPhone6_7, style: FrameStyle = .realistic) -> NSImage? {
        let assetName = "\(device.frameAssetName)_\(style.rawValue)"

        // Try loading from Asset Catalog
        if let image = NSImage(named: assetName) {
            return image
        }

        // Try loading from Resources directory
        if let url = Bundle.main.url(forResource: assetName, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        return nil
    }

    /// Generate a programmatic device frame (clay style).
    /// Used when no asset is available in the bundle.
    func generateClayFrame(
        size: CGSize,
        color: CGColor = CGColor(gray: 0.15, alpha: 1.0),
        cornerRadius: CGFloat? = nil
    ) -> NSImage {
        let radius = cornerRadius ?? size.width * 0.08

        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        // Device body
        let bodyRect = CGRect(origin: .zero, size: size)
        let bodyPath = CGPath(
            roundedRect: bodyRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        context.setFillColor(color)
        context.addPath(bodyPath)
        context.fillPath()

        // Inner screen cutout (slightly inset)
        let inset = size.width * 0.025
        let screenRect = bodyRect.insetBy(dx: inset, dy: inset)
        let screenRadius = radius - inset
        let screenPath = CGPath(
            roundedRect: screenRect,
            cornerWidth: max(screenRadius, 0),
            cornerHeight: max(screenRadius, 0),
            transform: nil
        )

        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.addPath(screenPath)
        context.fillPath()

        // Subtle border highlight
        context.setStrokeColor(CGColor(gray: 0.25, alpha: 0.5))
        context.setLineWidth(1)
        context.addPath(bodyPath)
        context.strokePath()

        image.unlockFocus()
        return image
    }

    /// Generate a minimal outline frame.
    func generateMinimalFrame(
        size: CGSize,
        strokeColor: CGColor = CGColor(gray: 0.3, alpha: 0.8),
        cornerRadius: CGFloat? = nil
    ) -> NSImage {
        let radius = cornerRadius ?? size.width * 0.08

        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let bodyRect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        let bodyPath = CGPath(
            roundedRect: bodyRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        context.setStrokeColor(strokeColor)
        context.setLineWidth(3)
        context.addPath(bodyPath)
        context.strokePath()

        image.unlockFocus()
        return image
    }
    #endif

    // MARK: - Screen Inset Calculation

    /// Calculate the screen area within a device frame.
    /// Returns the inset rect relative to the device frame's bounds.
    func screenInset(for deviceSize: DeviceSize, frameStyle: FrameStyle) -> CGRect {
        let w = CGFloat(deviceSize.width)
        let h = CGFloat(deviceSize.height)

        switch frameStyle {
        case .realistic:
            // Realistic frames have thicker bezels
            let insetX = w * 0.03
            let insetY = h * 0.015
            return CGRect(x: insetX, y: insetY, width: w - 2 * insetX, height: h - 2 * insetY)

        case .clay:
            let inset = w * 0.025
            return CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset)

        case .minimal:
            let inset = w * 0.01
            return CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset)

        case .none:
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
    }
}
