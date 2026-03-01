import Foundation
import AppKit
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

    /// Returns a human-readable name for the given device frame style.
    func frameStyleName(for style: FrameStyle) -> String {
        switch style {
        case .realistic: return "Realistic Device Frame"
        case .clay: return "Clay Mockup"
        case .minimal: return "Minimal Outline"
        case .none: return "No Frame"
        }
    }

    // MARK: - Frame Loading

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
        deviceType: DeviceType = .iPhone,
        color: CGColor = CGColor(gray: 0.15, alpha: 1.0),
        cornerRadius: CGFloat? = nil
    ) -> NSImage {
        let defaultRadius: CGFloat = deviceType == .iPad ? size.width * 0.04 : size.width * 0.08
        let radius = cornerRadius ?? defaultRadius
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return NSImage(size: size)
        }

        context.setShouldAntialias(true)

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

        // Notch (iPhone) or camera bump (iPad)
        if deviceType == .iPhone {
            // Rounded notch at the top center
            let notchWidth = size.width * 0.30
            let notchHeight = size.height * 0.015
            let notchRadius = notchHeight * 0.5
            let notchX = (size.width - notchWidth) / 2.0
            // Position at the top of the screen area (flipped: top = height - inset)
            let notchY = size.height - inset - notchHeight
            let notchRect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
            let notchPath = CGPath(
                roundedRect: notchRect,
                cornerWidth: notchRadius,
                cornerHeight: notchRadius,
                transform: nil
            )
            context.setFillColor(color)
            context.addPath(notchPath)
            context.fillPath()
        } else {
            // Small circular camera bump at the top center for iPad
            let bumpRadius = size.width * 0.008
            let bumpX = size.width / 2.0
            // Position near the top edge of the screen area
            let bumpY = size.height - inset + (inset * 0.4)
            let bumpRect = CGRect(
                x: bumpX - bumpRadius,
                y: bumpY - bumpRadius,
                width: bumpRadius * 2,
                height: bumpRadius * 2
            )
            context.setFillColor(CGColor(gray: 0.08, alpha: 1.0))
            context.fillEllipse(in: bumpRect)
        }

        // Subtle border highlight
        context.setStrokeColor(CGColor(gray: 0.25, alpha: 0.5))
        context.setLineWidth(1)
        context.addPath(bodyPath)
        context.strokePath()

        guard let cgImage = context.makeImage() else {
            return NSImage(size: size)
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Generate a minimal outline frame.
    func generateMinimalFrame(
        size: CGSize,
        deviceType: DeviceType = .iPhone,
        strokeColor: CGColor = CGColor(gray: 0.3, alpha: 0.8),
        cornerRadius: CGFloat? = nil
    ) -> NSImage {
        let defaultRadius: CGFloat = deviceType == .iPad ? size.width * 0.04 : size.width * 0.08
        let radius = cornerRadius ?? defaultRadius
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return NSImage(size: size)
        }

        context.setShouldAntialias(true)

        // Outer frame outline
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

        // Inner screen cutout with subtle rounded corners
        let innerInset = size.width * 0.015
        let innerRect = bodyRect.insetBy(dx: innerInset, dy: innerInset)
        let innerRadius = max(radius - innerInset, 4)
        let innerPath = CGPath(
            roundedRect: innerRect,
            cornerWidth: innerRadius,
            cornerHeight: innerRadius,
            transform: nil
        )

        var innerStrokeColor = strokeColor
        // Use a subtler version of the stroke color for the inner cutout
        let innerStrokeAlpha: CGFloat = 0.3
        if let components = strokeColor.components, components.count >= 2 {
            innerStrokeColor = CGColor(gray: components[0], alpha: innerStrokeAlpha)
        }
        context.setStrokeColor(innerStrokeColor)
        context.setLineWidth(1.5)
        context.addPath(innerPath)
        context.strokePath()

        guard let cgImage = context.makeImage() else {
            return NSImage(size: size)
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Generate a glass-effect device frame with gradient fill and highlight.
    /// Creates a frosted glass look that feels premium — similar to clay but with a
    /// subtle top-to-bottom gradient and a highlight stroke on the top edge.
    func generateGlassFrame(
        size: CGSize,
        deviceType: DeviceType = .iPhone,
        cornerRadius: CGFloat? = nil
    ) -> NSImage {
        let defaultRadius: CGFloat = deviceType == .iPad ? size.width * 0.04 : size.width * 0.08
        let radius = cornerRadius ?? defaultRadius
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return NSImage(size: size)
        }

        context.setShouldAntialias(true)

        // Device body with rounded rect clip
        let bodyRect = CGRect(origin: .zero, size: size)
        let bodyPath = CGPath(
            roundedRect: bodyRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        // Fill with a subtle top-to-bottom gradient (lighter at top, darker at bottom)
        context.saveGState()
        context.addPath(bodyPath)
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradientColors = [
            CGColor(gray: 0.22, alpha: 1.0),  // Slightly lighter gray at top
            CGColor(gray: 0.12, alpha: 1.0)   // Slightly darker gray at bottom
        ] as CFArray
        let gradientLocations: [CGFloat] = [0.0, 1.0]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
            // In CoreGraphics, y=0 is bottom, y=height is top
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: size.height),  // top
                end: CGPoint(x: size.width / 2, y: 0),              // bottom
                options: []
            )
        }
        context.restoreGState()

        // Top edge highlight
        context.saveGState()
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.2))
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: bodyRect.minX + radius, y: bodyRect.maxY))
        context.addLine(to: CGPoint(x: bodyRect.maxX - radius, y: bodyRect.maxY))
        context.strokePath()
        context.restoreGState()

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

        // Notch (iPhone) or camera bump (iPad) -- same as clay
        if deviceType == .iPhone {
            let notchWidth = size.width * 0.30
            let notchHeight = size.height * 0.015
            let notchRadius = notchHeight * 0.5
            let notchX = (size.width - notchWidth) / 2.0
            let notchY = size.height - inset - notchHeight
            let notchRect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
            let notchPath = CGPath(
                roundedRect: notchRect,
                cornerWidth: notchRadius,
                cornerHeight: notchRadius,
                transform: nil
            )
            context.setFillColor(CGColor(gray: 0.17, alpha: 1.0))
            context.addPath(notchPath)
            context.fillPath()
        } else {
            let bumpRadius = size.width * 0.008
            let bumpX = size.width / 2.0
            let bumpY = size.height - inset + (inset * 0.4)
            let bumpRect = CGRect(
                x: bumpX - bumpRadius,
                y: bumpY - bumpRadius,
                width: bumpRadius * 2,
                height: bumpRadius * 2
            )
            context.setFillColor(CGColor(gray: 0.08, alpha: 1.0))
            context.fillEllipse(in: bumpRect)
        }

        // Subtle border highlight on the outer edge
        context.setStrokeColor(CGColor(gray: 0.3, alpha: 0.4))
        context.setLineWidth(1)
        context.addPath(bodyPath)
        context.strokePath()

        // Top edge highlight stroke (white at 0.15 alpha) for frosted glass effect
        // Draw a partial stroke along the top portion of the body path
        context.saveGState()
        let highlightInset: CGFloat = 1.0
        let topHighlightPath = CGMutablePath()
        // Draw a line across the top with rounded ends blending into corners
        let topArcCenterY = size.height - highlightInset
        topHighlightPath.move(to: CGPoint(x: radius * 0.7, y: topArcCenterY))
        topHighlightPath.addLine(to: CGPoint(x: size.width - radius * 0.7, y: topArcCenterY))
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
        context.setLineWidth(2)
        context.setLineCap(.round)
        context.addPath(topHighlightPath)
        context.strokePath()
        context.restoreGState()

        guard let cgImage = context.makeImage() else {
            return NSImage(size: size)
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    // MARK: - Screen Inset Calculation

    /// Calculate the screen area within a device frame.
    /// Returns the inset rect relative to the device frame's bounds.
    func screenInset(for deviceSize: DeviceSize, frameStyle: FrameStyle) -> CGRect {
        let w = CGFloat(deviceSize.width)
        let h = CGFloat(deviceSize.height)
        let isIPad = deviceSize.deviceType == .iPad

        switch frameStyle {
        case .realistic:
            if isIPad {
                // iPad has thinner bezels relative to screen size
                let insetX = w * 0.02
                let insetY = h * 0.015
                return CGRect(x: insetX, y: insetY, width: w - 2 * insetX, height: h - 2 * insetY)
            }
            let insetX = w * 0.03
            let insetY = h * 0.015
            return CGRect(x: insetX, y: insetY, width: w - 2 * insetX, height: h - 2 * insetY)

        case .clay:
            let inset = isIPad ? w * 0.02 : w * 0.025
            return CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset)

        case .minimal:
            let inset = w * 0.01
            return CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset)

        case .none:
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
    }
}
