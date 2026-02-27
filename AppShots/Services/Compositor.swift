import Foundation
#if canImport(AppKit)
import AppKit
import CoreGraphics
import CoreText

/// Composites the final App Store screenshot from 4 layers:
///   Layer 1 (bottom): AI-generated background
///   Layer 2: Screenshot embedded in device frame
///   Layer 3: Device frame overlay
///   Layer 4 (top): Heading + Subheading text
struct Compositor {

    struct CompositeInput {
        let config: ScreenConfig
        let screenshot: NSImage
        let backgroundImage: NSImage
        let colors: ResolvedColors
        let targetSize: DeviceSize
    }

    enum CompositorError: LocalizedError {
        case contextCreationFailed
        case imageRenderFailed

        var errorDescription: String? {
            switch self {
            case .contextCreationFailed: return "Failed to create graphics context."
            case .imageRenderFailed: return "Failed to render composite image."
            }
        }
    }

    private let layoutEngine = LayoutEngine()
    private let textRenderer = TextRenderer()
    private let deviceFrame = DeviceFrame()

    // MARK: - Main Composition

    func compose(input: CompositeInput) throws -> NSImage {
        let width = input.targetSize.width
        let height = input.targetSize.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw CompositorError.contextCreationFailed
        }

        let canvasSize = CGSize(width: width, height: height)
        let layout = layoutEngine.calculate(
            layout: input.config.layout,
            canvasSize: canvasSize,
            hasSubheading: !input.config.subheading.isEmpty
        )

        // Layer 1: Background
        drawBackground(context: context, image: input.backgroundImage, size: canvasSize)

        // Layer 2 & 3: Device with screenshot
        drawDevice(
            context: context,
            screenshot: input.screenshot,
            deviceRect: layout.deviceRect,
            screenInset: layout.screenInset,
            rotation: layout.rotationAngle
        )

        // Layer 4: Text
        textRenderer.drawHeading(
            context: context,
            text: input.config.heading,
            rect: layout.headingRect,
            color: hexToColor(input.colors.text),
            fontSize: layout.headingFontSize
        )

        if !input.config.subheading.isEmpty {
            textRenderer.drawSubheading(
                context: context,
                text: input.config.subheading,
                rect: layout.subheadingRect,
                color: hexToColor(input.colors.subtext),
                fontSize: layout.subheadingFontSize
            )
        }

        guard let cgImage = context.makeImage() else {
            throw CompositorError.imageRenderFailed
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Compose with fallback gradient background

    func composeWithGradient(
        config: ScreenConfig,
        screenshot: NSImage,
        colors: ResolvedColors,
        targetSize: DeviceSize
    ) throws -> NSImage {
        let width = targetSize.width
        let height = targetSize.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw CompositorError.contextCreationFailed
        }

        let canvasSize = CGSize(width: width, height: height)
        let layout = layoutEngine.calculate(
            layout: config.layout,
            canvasSize: canvasSize,
            hasSubheading: !config.subheading.isEmpty
        )

        // Layer 1: Gradient background
        drawGradientBackground(
            context: context,
            size: canvasSize,
            primaryColor: hexToColor(colors.primary),
            accentColor: hexToColor(colors.accent)
        )

        // Layer 2 & 3: Device with screenshot
        drawDevice(
            context: context,
            screenshot: screenshot,
            deviceRect: layout.deviceRect,
            screenInset: layout.screenInset,
            rotation: layout.rotationAngle
        )

        // Layer 4: Text
        textRenderer.drawHeading(
            context: context,
            text: config.heading,
            rect: layout.headingRect,
            color: hexToColor(colors.text),
            fontSize: layout.headingFontSize
        )

        if !config.subheading.isEmpty {
            textRenderer.drawSubheading(
                context: context,
                text: config.subheading,
                rect: layout.subheadingRect,
                color: hexToColor(colors.subtext),
                fontSize: layout.subheadingFontSize
            )
        }

        guard let cgImage = context.makeImage() else {
            throw CompositorError.imageRenderFailed
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Drawing Helpers

    private func drawBackground(context: CGContext, image: NSImage, size: CGSize) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    }

    private func drawGradientBackground(
        context: CGContext,
        size: CGSize,
        primaryColor: CGColor,
        accentColor: CGColor
    ) {
        let colors = [primaryColor, accentColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }

        let startPoint = CGPoint(x: size.width * 0.5, y: size.height)
        let endPoint = CGPoint(x: size.width * 0.5, y: 0)
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private func drawDevice(
        context: CGContext,
        screenshot: NSImage,
        deviceRect: CGRect,
        screenInset: CGRect,
        rotation: CGFloat
    ) {
        context.saveGState()

        if rotation != 0 {
            let centerX = deviceRect.midX
            let centerY = deviceRect.midY
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: rotation * .pi / 180)
            context.translateBy(x: -centerX, y: -centerY)
        }

        // Draw screenshot inside the device area
        if let cgScreenshot = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let screenRect = CGRect(
                x: deviceRect.origin.x + screenInset.origin.x,
                y: deviceRect.origin.y + screenInset.origin.y,
                width: screenInset.width,
                height: screenInset.height
            )

            // Clip to rounded rect for screen (save/restore state to undo clip)
            context.saveGState()
            let cornerRadius: CGFloat = 20
            let clipPath = CGPath(roundedRect: screenRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(clipPath)
            context.clip()
            context.draw(cgScreenshot, in: screenRect)
            context.restoreGState()
        }

        // Draw device frame overlay (if available)
        if let frameImage = deviceFrame.loadFrame()?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(frameImage, in: deviceRect)
        } else {
            // Fallback: draw a simple device bezel
            drawSimpleDeviceBezel(context: context, rect: deviceRect)
        }

        context.restoreGState()
    }

    private func drawSimpleDeviceBezel(context: CGContext, rect: CGRect) {
        let cornerRadius: CGFloat = rect.width * 0.08
        let bezelPath = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        // Outer bezel
        context.setStrokeColor(CGColor(gray: 0.2, alpha: 0.8))
        context.setLineWidth(4)
        context.addPath(bezelPath)
        context.strokePath()

        // Inner shadow effect
        let insetRect = rect.insetBy(dx: 2, dy: 2)
        let innerPath = CGPath(
            roundedRect: insetRect,
            cornerWidth: cornerRadius - 2,
            cornerHeight: cornerRadius - 2,
            transform: nil
        )
        context.setStrokeColor(CGColor(gray: 0.3, alpha: 0.5))
        context.setLineWidth(1)
        context.addPath(innerPath)
        context.strokePath()
    }

    // MARK: - Color Conversion

    private func hexToColor(_ hex: String) -> CGColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif
