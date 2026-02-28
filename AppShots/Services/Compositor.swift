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
        let layout: LayoutEngine.LayoutResult
        if input.targetSize.deviceType == .iPad, let iPadCfg = input.config.iPadConfig {
            layout = layoutEngine.calculateIPadLayout(
                layoutType: iPadCfg.layoutType,
                tilt: input.config.tilt,
                canvasSize: canvasSize,
                hasSubheading: !input.config.subheading.isEmpty,
                orientation: iPadCfg.orientation
            )
        } else {
            layout = layoutEngine.calculate(
                tilt: input.config.tilt,
                position: input.config.position,
                fullBleed: input.config.fullBleed,
                canvasSize: canvasSize,
                hasSubheading: !input.config.subheading.isEmpty,
                deviceType: input.targetSize.deviceType
            )
        }

        renderLayout(
            context: context,
            layout: layout,
            config: input.config,
            screenshot: input.screenshot,
            colors: input.colors,
            canvasSize: canvasSize,
            targetSize: input.targetSize,
            backgroundImage: input.backgroundImage
        )

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
        let layout: LayoutEngine.LayoutResult
        if targetSize.deviceType == .iPad, let iPadCfg = config.iPadConfig {
            layout = layoutEngine.calculateIPadLayout(
                layoutType: iPadCfg.layoutType,
                tilt: config.tilt,
                canvasSize: canvasSize,
                hasSubheading: !config.subheading.isEmpty,
                orientation: iPadCfg.orientation
            )
        } else {
            layout = layoutEngine.calculate(
                tilt: config.tilt,
                position: config.position,
                fullBleed: config.fullBleed,
                canvasSize: canvasSize,
                hasSubheading: !config.subheading.isEmpty,
                deviceType: targetSize.deviceType
            )
        }

        renderLayout(
            context: context,
            layout: layout,
            config: config,
            screenshot: screenshot,
            colors: colors,
            canvasSize: canvasSize,
            targetSize: targetSize,
            backgroundImage: nil
        )

        guard let cgImage = context.makeImage() else {
            throw CompositorError.imageRenderFailed
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Unified Render Layout

    /// Renders a layout to context, handling all device types and layout modes.
    private func renderLayout(
        context: CGContext,
        layout: LayoutEngine.LayoutResult,
        config: ScreenConfig,
        screenshot: NSImage,
        colors: ResolvedColors,
        canvasSize: CGSize,
        targetSize: DeviceSize,
        backgroundImage: NSImage?
    ) {
        if layout.screenshotFillsCanvas {
            drawScreenshotAsBackground(context: context, screenshot: screenshot, size: canvasSize)
            if let scrimRect = layout.gradientScrimRect {
                drawGradientScrim(context: context, rect: scrimRect)
            }
            textRenderer.drawHeadingWithShadow(
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
        } else {
            // Draw background
            if let bgImage = backgroundImage {
                drawBackground(context: context, image: bgImage, size: canvasSize)
            } else {
                drawGradientBackground(
                    context: context,
                    size: canvasSize,
                    primaryColor: hexToColor(colors.primary),
                    accentColor: hexToColor(colors.accent)
                )
            }

            // Draw device (frameless, iPad, or iPhone)
            if layout.isFrameless {
                drawFramelessDevice(
                    context: context,
                    screenshot: screenshot,
                    deviceRect: layout.deviceRect,
                    screenInset: layout.screenInset,
                    rotation: layout.rotationAngle
                )
            } else {
                drawDevice(
                    context: context,
                    screenshot: screenshot,
                    deviceRect: layout.deviceRect,
                    screenInset: layout.screenInset,
                    rotation: layout.rotationAngle,
                    targetSize: targetSize
                )
            }

            // Draw text
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
        }
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
        rotation: CGFloat,
        targetSize: DeviceSize = .iPhone6_7
    ) {
        context.saveGState()

        if rotation != 0 {
            let centerX = deviceRect.midX
            let centerY = deviceRect.midY
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: rotation * .pi / 180)
            context.translateBy(x: -centerX, y: -centerY)
        }

        let screenRect = CGRect(
            x: deviceRect.origin.x + screenInset.origin.x,
            y: deviceRect.origin.y + screenInset.origin.y,
            width: screenInset.width,
            height: screenInset.height
        )
        let isIPad = targetSize.deviceType == .iPad
        let screenCornerRadius = deviceRect.width * (isIPad ? 0.045 : 0.06)
        let bodyCornerRadius = deviceRect.width * (isIPad ? 0.055 : 0.08)

        // 1. Draw device body (solid dark bezel)
        if let frameImage = deviceFrame.loadFrame(for: targetSize)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(frameImage, in: deviceRect)
        } else if isIPad {
            drawIPadFrame(context: context, deviceRect: deviceRect, screenRect: screenRect,
                          bodyRadius: bodyCornerRadius, screenRadius: screenCornerRadius)
        } else {
            drawIPhoneFrame(context: context, deviceRect: deviceRect, screenRect: screenRect,
                            bodyRadius: bodyCornerRadius, screenRadius: screenCornerRadius)
        }

        // 2. Draw screenshot inside the screen area (aspect-fill)
        drawScreenshotInRect(context: context, screenshot: screenshot, screenRect: screenRect,
                             cornerRadius: screenCornerRadius)

        // 3. Draw Dynamic Island (iPhone only)
        if !isIPad && deviceFrame.loadFrame(for: targetSize) == nil {
            drawDynamicIsland(context: context, screenRect: screenRect)
        }

        // 4. Draw home indicator (iPad only, Face ID models)
        if isIPad && deviceFrame.loadFrame(for: targetSize) == nil {
            drawHomeIndicator(context: context, screenRect: screenRect)
        }

        context.restoreGState()
    }

    /// Draw a frameless floating UI — rounded corners + drop shadow, no device bezel.
    private func drawFramelessDevice(
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

        let cornerRadius = deviceRect.width * 0.03

        // Drop shadow
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 30,
                          color: CGColor(gray: 0, alpha: 0.35))

        // Draw the screenshot directly with rounded corners
        drawScreenshotInRect(context: context, screenshot: screenshot, screenRect: deviceRect,
                             cornerRadius: cornerRadius)

        context.restoreGState()
    }

    /// Shared helper to draw a screenshot into a rounded rect with aspect-fill.
    private func drawScreenshotInRect(
        context: CGContext,
        screenshot: NSImage,
        screenRect: CGRect,
        cornerRadius: CGFloat
    ) {
        guard let cgScreenshot = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        context.saveGState()
        let clipPath = CGPath(roundedRect: screenRect,
                              cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                              transform: nil)
        context.addPath(clipPath)
        context.clip()

        let imgW = CGFloat(cgScreenshot.width)
        let imgH = CGFloat(cgScreenshot.height)
        let imgAspect = imgW / imgH
        let screenAspect = screenRect.width / screenRect.height
        var drawRect: CGRect
        if imgAspect > screenAspect {
            let drawHeight = screenRect.height
            let drawWidth = drawHeight * imgAspect
            drawRect = CGRect(x: screenRect.minX + (screenRect.width - drawWidth) / 2,
                              y: screenRect.minY,
                              width: drawWidth, height: drawHeight)
        } else {
            let drawWidth = screenRect.width
            let drawHeight = drawWidth / imgAspect
            drawRect = CGRect(x: screenRect.minX,
                              y: screenRect.minY + (screenRect.height - drawHeight) / 2,
                              width: drawWidth, height: drawHeight)
        }
        context.draw(cgScreenshot, in: drawRect)
        context.restoreGState()
    }

    private func drawIPhoneFrame(
        context: CGContext,
        deviceRect: CGRect,
        screenRect: CGRect,
        bodyRadius: CGFloat,
        screenRadius: CGFloat
    ) {
        let bodyPath = CGPath(roundedRect: deviceRect,
                              cornerWidth: bodyRadius, cornerHeight: bodyRadius,
                              transform: nil)
        context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0))
        context.addPath(bodyPath)
        context.fillPath()

        context.setStrokeColor(CGColor(gray: 0.25, alpha: 0.6))
        context.setLineWidth(1.5)
        context.addPath(bodyPath)
        context.strokePath()

        let grooveRect = screenRect.insetBy(dx: -1.5, dy: -1.5)
        let groovePath = CGPath(roundedRect: grooveRect,
                                cornerWidth: screenRadius + 1.5, cornerHeight: screenRadius + 1.5,
                                transform: nil)
        context.setStrokeColor(CGColor(gray: 0.05, alpha: 0.8))
        context.setLineWidth(1)
        context.addPath(groovePath)
        context.strokePath()

        let buttonWidth: CGFloat = 3
        let buttonHeight = deviceRect.height * 0.06
        let buttonY = deviceRect.origin.y + deviceRect.height * 0.55
        let buttonRect = CGRect(x: deviceRect.maxX - 0.5,
                                y: buttonY, width: buttonWidth, height: buttonHeight)
        context.setFillColor(CGColor(gray: 0.15, alpha: 0.9))
        context.fill(buttonRect)

        let volWidth: CGFloat = 3
        let volHeight = deviceRect.height * 0.04
        for i in 0..<2 {
            let volY = deviceRect.origin.y + deviceRect.height * (0.58 + CGFloat(i) * 0.06)
            let volRect = CGRect(x: deviceRect.minX - volWidth + 0.5,
                                 y: volY, width: volWidth, height: volHeight)
            context.setFillColor(CGColor(gray: 0.15, alpha: 0.9))
            context.fill(volRect)
        }
    }

    /// Draw iPad device frame — thinner bezels, no side buttons, less rounded corners.
    private func drawIPadFrame(
        context: CGContext,
        deviceRect: CGRect,
        screenRect: CGRect,
        bodyRadius: CGFloat,
        screenRadius: CGFloat
    ) {
        // Device body
        let bodyPath = CGPath(roundedRect: deviceRect,
                              cornerWidth: bodyRadius, cornerHeight: bodyRadius,
                              transform: nil)
        context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0))
        context.addPath(bodyPath)
        context.fillPath()

        // Subtle border highlight
        context.setStrokeColor(CGColor(gray: 0.25, alpha: 0.6))
        context.setLineWidth(1.5)
        context.addPath(bodyPath)
        context.strokePath()

        // Screen groove
        let grooveRect = screenRect.insetBy(dx: -1.5, dy: -1.5)
        let groovePath = CGPath(roundedRect: grooveRect,
                                cornerWidth: screenRadius + 1.5, cornerHeight: screenRadius + 1.5,
                                transform: nil)
        context.setStrokeColor(CGColor(gray: 0.05, alpha: 0.8))
        context.setLineWidth(1)
        context.addPath(groovePath)
        context.strokePath()

        // No side buttons for iPad — cleaner silhouette
    }

    /// Draw iPad home indicator bar at the bottom of the screen.
    /// Note: Core Graphics origin is bottom-left, so minY = visual bottom.
    private func drawHomeIndicator(context: CGContext, screenRect: CGRect) {
        let indicatorWidth = screenRect.width * 0.30
        let indicatorHeight = screenRect.width * 0.005
        let indicatorX = screenRect.midX - indicatorWidth / 2
        let indicatorY = screenRect.minY + screenRect.height * 0.008

        let indicatorRect = CGRect(x: indicatorX, y: indicatorY, width: indicatorWidth, height: indicatorHeight)
        let indicatorPath = CGPath(roundedRect: indicatorRect,
                                   cornerWidth: indicatorHeight / 2, cornerHeight: indicatorHeight / 2,
                                   transform: nil)
        context.setFillColor(CGColor(gray: 0.4, alpha: 0.6))
        context.addPath(indicatorPath)
        context.fillPath()
    }

    private func drawDynamicIsland(context: CGContext, screenRect: CGRect) {
        let pillWidth = screenRect.width * 0.25
        let pillHeight = screenRect.width * 0.035
        let pillX = screenRect.midX - pillWidth / 2
        let pillY = screenRect.maxY - pillHeight - screenRect.height * 0.012

        let pillRect = CGRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight)
        let pillPath = CGPath(roundedRect: pillRect,
                              cornerWidth: pillHeight / 2, cornerHeight: pillHeight / 2,
                              transform: nil)
        context.setFillColor(CGColor(gray: 0.0, alpha: 0.95))
        context.addPath(pillPath)
        context.fillPath()
    }

    // MARK: - Full Bleed Drawing Helpers

    private func drawScreenshotAsBackground(context: CGContext, screenshot: NSImage, size: CGSize) {
        guard let cgImage = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let imageAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let canvasAspect = size.width / size.height
        var drawRect: CGRect
        if imageAspect > canvasAspect {
            let drawHeight = size.height
            let drawWidth = drawHeight * imageAspect
            drawRect = CGRect(x: (size.width - drawWidth) / 2, y: 0, width: drawWidth, height: drawHeight)
        } else {
            let drawWidth = size.width
            let drawHeight = drawWidth / imageAspect
            drawRect = CGRect(x: 0, y: (size.height - drawHeight) / 2, width: drawWidth, height: drawHeight)
        }
        context.draw(cgImage, in: drawRect)
    }

    private func drawGradientScrim(context: CGContext, rect: CGRect) {
        context.saveGState()
        let colors = [
            CGColor(gray: 0, alpha: 0.85),
            CGColor(gray: 0, alpha: 0.0)
        ] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else {
            context.restoreGState()
            return
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
        context.restoreGState()
    }

    // MARK: - Color Conversion

    private func hexToColor(_ hex: String) -> CGColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        if hexSanitized.count == 3 {
            hexSanitized = hexSanitized.map { "\($0)\($0)" }.joined()
        }

        guard hexSanitized.count == 6,
              hexSanitized.allSatisfy({ $0.isHexDigit }) else {
            return CGColor(gray: 0, alpha: 1.0)
        }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif
