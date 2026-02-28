import Foundation
import CoreGraphics

/// Calculates layout coordinates for all elements in a screenshot composition.
///
/// Design principles:
/// - Device defaults to BIG (80% canvas width for iPhone, 70% for iPad) for maximum impact
/// - 3 keyword modifiers: tilt (rotation), position (center/left/right), fullBleed (no frame)
/// - iPad adds: frameless, headlineDominant, and other iPad-specific layout types
/// - Text compact around content, minimal gap between text and device
/// - Device extends below canvas (bottom-clipped) to maximize visible screen area
struct LayoutEngine {

    /// Result of a layout calculation — all rects and sizes needed for composition.
    struct LayoutResult {
        let headingRect: CGRect
        let subheadingRect: CGRect
        let deviceRect: CGRect
        let screenInset: CGRect       // Relative to deviceRect origin
        let headingFontSize: CGFloat
        let subheadingFontSize: CGFloat
        let rotationAngle: CGFloat    // degrees, 0 for non-tilted
        var deviceType: DeviceType = .iPhone

        var screenshotFillsCanvas: Bool = false     // fullBleed: screenshot as background
        var gradientScrimRect: CGRect? = nil        // fullBleed: gradient overlay area
        var isFrameless: Bool = false               // frameless: rounded corners + shadow, no bezel
    }

    // MARK: - Shared Constants

    private let frameBorderRatio: CGFloat = 0.04      // Bezel relative to device width
    private let hMargin: CGFloat = 0.06               // Horizontal margin as ratio of width

    // MARK: - Calculate Layout (iPhone)

    func calculate(
        tilt: Bool,
        position: String,
        fullBleed: Bool,
        canvasSize: CGSize,
        hasSubheading: Bool,
        deviceType: DeviceType = .iPhone
    ) -> LayoutResult {
        let deviceAspect = deviceType.aspectRatio

        if deviceType == .iPad {
            return calculateIPad(
                tilt: tilt,
                position: position,
                fullBleed: fullBleed,
                canvasSize: canvasSize,
                hasSubheading: hasSubheading,
                deviceAspect: deviceAspect
            )
        }

        if fullBleed {
            return calculateFullBleed(canvasSize: canvasSize, hasSubheading: hasSubheading)
        }
        return calculateStandard(
            tilt: tilt,
            position: position,
            canvasSize: canvasSize,
            hasSubheading: hasSubheading,
            deviceAspect: deviceAspect
        )
    }

    // MARK: - Calculate Layout (iPad with layout type)

    func calculateIPadLayout(
        layoutType: iPadLayoutType,
        tilt: Bool,
        canvasSize: CGSize,
        hasSubheading: Bool
    ) -> LayoutResult {
        let deviceAspect = DeviceType.iPad.aspectRatio

        switch layoutType {
        case .standard:
            return calculateIPadStandard(canvasSize: canvasSize, hasSubheading: hasSubheading, deviceAspect: deviceAspect)

        case .angled:
            return calculateIPadAngled(canvasSize: canvasSize, hasSubheading: hasSubheading, deviceAspect: deviceAspect)

        case .frameless:
            return calculateIPadFrameless(canvasSize: canvasSize, hasSubheading: hasSubheading, deviceAspect: deviceAspect)

        case .headlineDominant:
            return calculateIPadHeadlineDominant(canvasSize: canvasSize, hasSubheading: hasSubheading, deviceAspect: deviceAspect)

        case .uiForward:
            var result = calculateFullBleed(canvasSize: canvasSize, hasSubheading: hasSubheading)
            result.deviceType = .iPad
            return result

        case .multiOrientation, .darkLightDual, .splitPanel, .beforeAfter:
            // Tier 2 layouts — fall back to standard for now
            return calculateIPadStandard(canvasSize: canvasSize, hasSubheading: hasSubheading, deviceAspect: deviceAspect)
        }
    }

    // MARK: - Helpers

    /// Build a device rect + screen inset from width, position, and aspect ratio.
    private func makeDevice(width: CGFloat, x: CGFloat, y: CGFloat, deviceAspect: CGFloat) -> (rect: CGRect, inset: CGRect) {
        let height = width * deviceAspect
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let border = width * frameBorderRatio
        let inset = CGRect(x: border, y: border, width: width - 2 * border, height: height - 2 * border)
        return (rect, inset)
    }

    /// Position heading + subheading compactly in a text zone.
    private func makeTextRects(
        canvasSize: CGSize,
        topY: CGFloat,
        textWidth: CGFloat,
        textX: CGFloat,
        hasSubheading: Bool,
        headingScale: CGFloat = 0.08,
        subheadingScale: CGFloat = 0.04
    ) -> (CGRect, CGRect, CGFloat, CGFloat) {
        let w = canvasSize.width
        let headingFontSize = w * headingScale
        let subheadingFontSize = w * subheadingScale

        let headingHeight = headingFontSize * 3.0
        let subheadingHeight = hasSubheading ? subheadingFontSize * 2.5 : 0
        let gap = hasSubheading ? headingFontSize * 0.3 : 0

        let headingRect = CGRect(
            x: textX,
            y: topY - headingHeight,
            width: textWidth,
            height: headingHeight
        )

        let subheadingRect = CGRect(
            x: textX + w * 0.02,
            y: headingRect.minY - gap - subheadingHeight,
            width: textWidth - w * 0.04,
            height: subheadingHeight
        )

        return (headingRect, subheadingRect, headingFontSize, subheadingFontSize)
    }

    // MARK: - Standard Layout (center / left / right, optional tilt)

    /// Default big device layout. 80% width centered, 65% for left/right with text beside.
    private func calculateStandard(
        tilt: Bool,
        position: String,
        canvasSize: CGSize,
        hasSubheading: Bool,
        deviceAspect: CGFloat
    ) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * hMargin

        switch position {
        case "left":
            // Device on left, text on right
            let deviceWidth = w * 0.65
            let (deviceRect, screenInset) = makeDevice(
                width: deviceWidth,
                x: -deviceWidth * 0.06,
                y: -h * 0.05,
                deviceAspect: deviceAspect
            )

            let textX = deviceRect.maxX + margin
            let textWidth = w - textX - margin
            let textTopY = h * 0.68

            let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
                canvasSize: canvasSize,
                topY: textTopY,
                textWidth: textWidth,
                textX: textX,
                hasSubheading: hasSubheading,
                headingScale: 0.065,
                subheadingScale: 0.035
            )

            return LayoutResult(
                headingRect: headingRect,
                subheadingRect: subheadingRect,
                deviceRect: deviceRect,
                screenInset: screenInset,
                headingFontSize: headingFS,
                subheadingFontSize: subheadingFS,
                rotationAngle: tilt ? -8 : 0
            )

        case "right":
            // Device on right, text on left
            let deviceWidth = w * 0.65
            let deviceX = w - deviceWidth + deviceWidth * 0.06
            let (deviceRect, screenInset) = makeDevice(
                width: deviceWidth,
                x: deviceX,
                y: -h * 0.05,
                deviceAspect: deviceAspect
            )

            let textX = margin
            let textWidth = deviceRect.minX - margin - textX

            let textTopY = h * 0.68

            let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
                canvasSize: canvasSize,
                topY: textTopY,
                textWidth: textWidth,
                textX: textX,
                hasSubheading: hasSubheading,
                headingScale: 0.065,
                subheadingScale: 0.035
            )

            return LayoutResult(
                headingRect: headingRect,
                subheadingRect: subheadingRect,
                deviceRect: deviceRect,
                screenInset: screenInset,
                headingFontSize: headingFS,
                subheadingFontSize: subheadingFS,
                rotationAngle: tilt ? 8 : 0
            )

        default:
            // Center: big device at 80% width, text above
            let deviceWidth = w * 0.80
            let xOffset = tilt ? w * 0.03 : 0
            let (deviceRect, screenInset) = makeDevice(
                width: deviceWidth,
                x: (w - deviceWidth) / 2 + xOffset,
                y: -h * 0.08,
                deviceAspect: deviceAspect
            )

            let textTopY = min(deviceRect.maxY + h * 0.02, h - h * 0.06)
            let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
                canvasSize: canvasSize,
                topY: textTopY,
                textWidth: w - 2 * margin,
                textX: margin,
                hasSubheading: hasSubheading
            )

            return LayoutResult(
                headingRect: headingRect,
                subheadingRect: subheadingRect,
                deviceRect: deviceRect,
                screenInset: screenInset,
                headingFontSize: headingFS,
                subheadingFontSize: subheadingFS,
                rotationAngle: tilt ? -8 : 0
            )
        }
    }

    // MARK: - Full Bleed Layout

    /// Screenshot fills entire canvas edge-to-edge, no device frame.
    /// Text overlaid at bottom with gradient scrim for readability.
    private func calculateFullBleed(canvasSize: CGSize, hasSubheading: Bool) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * hMargin

        let scrimHeight = h * 0.35
        let scrimRect = CGRect(x: 0, y: 0, width: w, height: scrimHeight)

        let textTopY = scrimHeight * 0.85
        let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
            canvasSize: canvasSize,
            topY: textTopY,
            textWidth: w - 2 * margin,
            textX: margin,
            hasSubheading: hasSubheading,
            headingScale: 0.08,
            subheadingScale: 0.04
        )

        var result = LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: .zero,
            screenInset: .zero,
            headingFontSize: headingFS,
            subheadingFontSize: subheadingFS,
            rotationAngle: 0
        )
        result.screenshotFillsCanvas = true
        result.gradientScrimRect = scrimRect
        return result
    }

    // MARK: - iPad Dispatcher

    /// Route iPad layouts based on iPhone modifiers when no explicit iPadLayoutType is specified.
    private func calculateIPad(
        tilt: Bool,
        position: String,
        fullBleed: Bool,
        canvasSize: CGSize,
        hasSubheading: Bool,
        deviceAspect: CGFloat
    ) -> LayoutResult {
        let layoutType = iPadLayoutType.fromIPhoneModifiers(tilt: tilt, position: position, fullBleed: fullBleed)
        return calculateIPadLayout(
            layoutType: layoutType,
            tilt: tilt,
            canvasSize: canvasSize,
            hasSubheading: hasSubheading
        )
    }

    // MARK: - iPad Standard (centered, 70% width)

    private func calculateIPadStandard(
        canvasSize: CGSize,
        hasSubheading: Bool,
        deviceAspect: CGFloat
    ) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * hMargin

        // iPad: 70% width (not 80%) because the squarer aspect takes more vertical space
        let deviceWidth = w * 0.70
        let (deviceRect, screenInset) = makeDevice(
            width: deviceWidth,
            x: (w - deviceWidth) / 2,
            y: -h * 0.05,
            deviceAspect: deviceAspect
        )

        let textTopY = min(deviceRect.maxY + h * 0.02, h - h * 0.06)
        let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
            canvasSize: canvasSize,
            topY: textTopY,
            textWidth: w - 2 * margin,
            textX: margin,
            hasSubheading: hasSubheading,
            headingScale: 0.065,
            subheadingScale: 0.035
        )

        var result = LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: deviceRect,
            screenInset: screenInset,
            headingFontSize: headingFS,
            subheadingFontSize: subheadingFS,
            rotationAngle: 0
        )
        result.deviceType = .iPad
        return result
    }

    // MARK: - iPad Angled (tilted 3D perspective)

    private func calculateIPadAngled(
        canvasSize: CGSize,
        hasSubheading: Bool,
        deviceAspect: CGFloat
    ) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * hMargin

        let deviceWidth = w * 0.70
        let xOffset = w * 0.03
        let (deviceRect, screenInset) = makeDevice(
            width: deviceWidth,
            x: (w - deviceWidth) / 2 + xOffset,
            y: -h * 0.05,
            deviceAspect: deviceAspect
        )

        let textTopY = min(deviceRect.maxY + h * 0.02, h - h * 0.06)
        let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
            canvasSize: canvasSize,
            topY: textTopY,
            textWidth: w - 2 * margin,
            textX: margin,
            hasSubheading: hasSubheading,
            headingScale: 0.065,
            subheadingScale: 0.035
        )

        var result = LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: deviceRect,
            screenInset: screenInset,
            headingFontSize: headingFS,
            subheadingFontSize: subheadingFS,
            rotationAngle: -8
        )
        result.deviceType = .iPad
        return result
    }

    // MARK: - iPad Frameless (floating UI with rounded corners + shadow)

    private func calculateIPadFrameless(
        canvasSize: CGSize,
        hasSubheading: Bool,
        deviceAspect: CGFloat
    ) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * hMargin

        // Frameless: screenshot displayed at ~75% width with rounded corners and drop shadow
        let screenWidth = w * 0.75
        let screenHeight = screenWidth * deviceAspect
        let screenX = (w - screenWidth) / 2
        let screenY = h * 0.02

        let deviceRect = CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
        // No bezel — screen inset matches device rect (no border offset)
        let screenInset = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight)

        let textTopY = min(deviceRect.maxY + h * 0.02, h - h * 0.06)
        let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
            canvasSize: canvasSize,
            topY: textTopY,
            textWidth: w - 2 * margin,
            textX: margin,
            hasSubheading: hasSubheading,
            headingScale: 0.065,
            subheadingScale: 0.035
        )

        var result = LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: deviceRect,
            screenInset: screenInset,
            headingFontSize: headingFS,
            subheadingFontSize: subheadingFS,
            rotationAngle: 0
        )
        result.deviceType = .iPad
        result.isFrameless = true
        return result
    }

    // MARK: - iPad Headline Dominant (large text 45%, device 55%)

    private func calculateIPadHeadlineDominant(
        canvasSize: CGSize,
        hasSubheading: Bool,
        deviceAspect: CGFloat
    ) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * hMargin

        // Text occupies top 45% of canvas
        let textZoneHeight = h * 0.45

        let (headingRect, subheadingRect, headingFS, subheadingFS) = makeTextRects(
            canvasSize: canvasSize,
            topY: h - margin,    // Start from top with margin
            textWidth: w - 2 * margin,
            textX: margin,
            hasSubheading: hasSubheading,
            headingScale: 0.09,   // Larger heading for dominant text
            subheadingScale: 0.045
        )

        // Device in bottom 55%, smaller (60% width)
        let deviceWidth = w * 0.60
        let deviceY = h - textZoneHeight - h * 0.02
        let (deviceRect, screenInset) = makeDevice(
            width: deviceWidth,
            x: (w - deviceWidth) / 2,
            y: deviceY - deviceWidth * deviceAspect + h * 0.15,
            deviceAspect: deviceAspect
        )

        var result = LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: deviceRect,
            screenInset: screenInset,
            headingFontSize: headingFS,
            subheadingFontSize: subheadingFS,
            rotationAngle: 0
        )
        result.deviceType = .iPad
        return result
    }
}
