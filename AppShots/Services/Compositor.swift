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
        context.saveGState()
        defer { context.restoreGState() }

        if layout.screenshotFillsCanvas {
            drawScreenshotAsBackground(context: context, screenshot: screenshot, size: canvasSize)
            if let scrimRect = layout.gradientScrimRect {
                drawGradientScrim(context: context, rect: scrimRect)
            }
            textRenderer.drawHeadingWithShadow(
                context: context,
                text: config.heading,
                rect: layout.headingRect,
                color: hexToColor(colors.text, isTextColor: true),
                fontSize: layout.headingFontSize
            )
            if !config.subheading.isEmpty {
                textRenderer.drawSubheading(
                    context: context,
                    text: config.subheading,
                    rect: layout.subheadingRect,
                    color: hexToColor(colors.subtext, isTextColor: true),
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
                color: hexToColor(colors.text, isTextColor: true),
                fontSize: layout.headingFontSize
            )
            if !config.subheading.isEmpty {
                textRenderer.drawSubheading(
                    context: context,
                    text: config.subheading,
                    rect: layout.subheadingRect,
                    color: hexToColor(colors.subtext, isTextColor: true),
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
        // Extract RGB components from primary and accent colors for interpolation
        let primaryComponents = primaryColor.components ?? [0, 0, 0, 1]
        let accentComponents = accentColor.components ?? [0.5, 0.5, 0.5, 1]

        let pR = primaryComponents.count >= 3 ? primaryComponents[0] : primaryComponents[0]
        let pG = primaryComponents.count >= 3 ? primaryComponents[1] : primaryComponents[0]
        let pB = primaryComponents.count >= 3 ? primaryComponents[2] : primaryComponents[0]

        let aR = accentComponents.count >= 3 ? accentComponents[0] : accentComponents[0]
        let aG = accentComponents.count >= 3 ? accentComponents[1] : accentComponents[0]
        let aB = accentComponents.count >= 3 ? accentComponents[2] : accentComponents[0]

        // Blended mid-stop: interpolate primary and accent at 50/50
        let midColor = CGColor(red: (pR + aR) / 2.0, green: (pG + aG) / 2.0, blue: (pB + aB) / 2.0, alpha: 1.0)

        // Slightly lighter version of primary for the top stop
        let lighterPrimary = CGColor(
            red: min(pR + 0.12, 1.0),
            green: min(pG + 0.12, 1.0),
            blue: min(pB + 0.12, 1.0),
            alpha: 1.0
        )

        // 3-stop linear gradient: primary (bottom) -> blended mid -> lighter primary (top)
        let colors = [primaryColor, midColor, lighterPrimary] as CFArray
        let locations: [CGFloat] = [0.0, 0.6, 1.0]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }

        let startPoint = CGPoint(x: size.width * 0.5, y: 0)
        let endPoint = CGPoint(x: size.width * 0.5, y: size.height)
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )

        // Subtle radial gradient overlay centered at top-right, simulating a light source
        context.saveGState()
        let diagonal = sqrt(size.width * size.width + size.height * size.height)
        let radialRadius = diagonal * 0.6
        let radialCenter = CGPoint(x: size.width * 0.85, y: size.height * 0.85)

        let radialAccent = CGColor(red: aR, green: aG, blue: aB, alpha: 0.4)
        let radialTransparent = CGColor(red: aR, green: aG, blue: aB, alpha: 0.0)
        let radialColors = [radialAccent, radialTransparent] as CFArray
        let radialLocations: [CGFloat] = [0.0, 1.0]

        guard let radialGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: radialColors,
            locations: radialLocations
        ) else {
            context.restoreGState()
            return
        }

        context.drawRadialGradient(
            radialGradient,
            startCenter: radialCenter, startRadius: 0,
            endCenter: radialCenter, endRadius: radialRadius,
            options: []
        )
        context.restoreGState()
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
        if screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil {
            drawScreenshotInRect(context: context, screenshot: screenshot, screenRect: screenRect,
                                 cornerRadius: screenCornerRadius)
        } else {
            // Draw a light gray placeholder rectangle if screenshot cgImage is nil
            let placeholderPath = CGPath(roundedRect: screenRect,
                                         cornerWidth: screenCornerRadius, cornerHeight: screenCornerRadius,
                                         transform: nil)
            context.setFillColor(CGColor(gray: 0.85, alpha: 1.0))
            context.addPath(placeholderPath)
            context.fillPath()
        }

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

        // Drop shadow (increased blur for softer, more premium look)
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 40,
                          color: CGColor(gray: 0, alpha: 0.35))

        // Draw the screenshot directly with rounded corners
        drawScreenshotInRect(context: context, screenshot: screenshot, screenRect: deviceRect,
                             cornerRadius: cornerRadius)

        // Reset shadow so inner stroke isn't affected
        context.setShadow(offset: .zero, blur: 0, color: nil)

        // Subtle white inner stroke around the screenshot for a glass-edge effect
        let innerStrokeRect = deviceRect.insetBy(dx: 0.25, dy: 0.25)
        let innerStrokePath = CGPath(roundedRect: innerStrokeRect,
                                     cornerWidth: cornerRadius - 0.25,
                                     cornerHeight: cornerRadius - 0.25,
                                     transform: nil)
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1))
        context.setLineWidth(0.5)
        context.addPath(innerStrokePath)
        context.strokePath()

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

        // Subtle inner shadow inside the screen rect for depth
        let innerShadowRect = screenRect.insetBy(dx: 0.5, dy: 0.5)
        let innerShadowPath = CGPath(roundedRect: innerShadowRect,
                                     cornerWidth: screenRadius - 0.5, cornerHeight: screenRadius - 0.5,
                                     transform: nil)
        context.setStrokeColor(CGColor(gray: 0.0, alpha: 0.3))
        context.setLineWidth(0.5)
        context.addPath(innerShadowPath)
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

        // Subtle camera dot on the right side of the Dynamic Island pill
        let cameraDotSize: CGFloat = 4.0
        let cameraDotX = pillRect.maxX - pillHeight / 2  // Centered vertically within the right side
        let cameraDotY = pillRect.midY
        let cameraDotRect = CGRect(
            x: cameraDotX - cameraDotSize / 2,
            y: cameraDotY - cameraDotSize / 2,
            width: cameraDotSize,
            height: cameraDotSize
        )
        let cameraDotPath = CGPath(ellipseIn: cameraDotRect, transform: nil)
        context.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0))
        context.addPath(cameraDotPath)
        context.fillPath()
    }

    // MARK: - Device Reflection

    /// Draws a subtle gradient highlight on the upper-left of the device body,
    /// simulating light reflection — a thin white-to-transparent diagonal stroke.
    private func drawDeviceReflection(context: CGContext, deviceRect: CGRect, cornerRadius: CGFloat) {
        context.saveGState()

        // Clip to the device body so the reflection doesn't bleed outside
        let clipPath = CGPath(roundedRect: deviceRect,
                              cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                              transform: nil)
        context.addPath(clipPath)
        context.clip()

        // Define a diagonal line along the upper-left edge of the device
        let reflectionLength = min(deviceRect.width, deviceRect.height) * 0.5
        let startX = deviceRect.minX + deviceRect.width * 0.05
        let startY = deviceRect.maxY - deviceRect.height * 0.05
        let endX = startX + reflectionLength * 0.7
        let endY = startY - reflectionLength * 0.7

        // Create a gradient from white (subtle) to transparent along the reflection
        let colors = [
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15),
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
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

        // Draw the reflection as a thin stroked path with gradient
        let reflectionPath = CGMutablePath()
        reflectionPath.move(to: CGPoint(x: startX, y: startY))
        reflectionPath.addLine(to: CGPoint(x: endX, y: endY))

        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.addPath(reflectionPath)
        context.replacePathWithStrokedPath()
        context.clip()

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: startX, y: startY),
            end: CGPoint(x: endX, y: endY),
            options: []
        )

        context.restoreGState()
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
        // 3-stop gradient for a more gradual fade that protects text readability better
        let colors = [
            CGColor(gray: 0, alpha: 0.9),   // Bottom: strong black for text contrast
            CGColor(gray: 0, alpha: 0.5),   // Mid: gradual transition
            CGColor(gray: 0, alpha: 0.0)    // Top: fully transparent
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.4, 1.0]
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

    private func hexToColor(_ hex: String, isTextColor: Bool = false) -> CGColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        // If the hex string is empty, return a sensible default
        if hexSanitized.isEmpty {
            return isTextColor ? CGColor(gray: 1.0, alpha: 1.0) : CGColor(gray: 0, alpha: 1.0)
        }

        if hexSanitized.count == 3 {
            hexSanitized = hexSanitized.map { "\($0)\($0)" }.joined()
        }

        guard hexSanitized.count == 6,
              hexSanitized.allSatisfy({ $0.isHexDigit }) else {
            return isTextColor ? CGColor(gray: 1.0, alpha: 1.0) : CGColor(gray: 0, alpha: 1.0)
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
