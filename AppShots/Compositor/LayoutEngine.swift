import Foundation
import CoreGraphics

/// Calculates layout coordinates for all elements in a screenshot composition.
/// Responsible for positioning the device frame, text areas, and managing
/// the spatial relationship between elements for each layout type.
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
    }

    // MARK: - Layout Constants

    /// Margins as proportion of canvas width
    private let horizontalMarginRatio: CGFloat = 0.06
    /// Top safe area ratio
    private let topMarginRatio: CGFloat = 0.04
    /// Spacing between text and device
    private let textDeviceSpacingRatio: CGFloat = 0.02
    /// Device width as proportion of canvas width
    private let deviceWidthRatio: CGFloat = 0.65
    /// Text area height as proportion of canvas height
    private let textAreaRatioWithSub: CGFloat = 0.28
    private let textAreaRatioNoSub: CGFloat = 0.22
    /// Device frame border (bezel) ratio relative to device width
    private let frameBorderRatio: CGFloat = 0.025
    /// Screen corner radius ratio
    private let screenCornerRatio: CGFloat = 0.04

    // MARK: - Calculate Layout

    func calculate(
        layout: LayoutType,
        canvasSize: CGSize,
        hasSubheading: Bool
    ) -> LayoutResult {
        switch layout {
        case .centerDevice:
            return calculateCenterDevice(canvasSize: canvasSize, hasSubheading: hasSubheading)
        case .leftDevice:
            return calculateLeftDevice(canvasSize: canvasSize, hasSubheading: hasSubheading)
        case .tilted:
            return calculateTilted(canvasSize: canvasSize, hasSubheading: hasSubheading)
        }
    }

    // MARK: - Center Device Layout

    /// Device centered horizontally, text above.
    /// Most universal, safe layout — works for any app.
    private func calculateCenterDevice(canvasSize: CGSize, hasSubheading: Bool) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * horizontalMarginRatio
        let topMargin = h * topMarginRatio

        let textAreaRatio = hasSubheading ? textAreaRatioWithSub : textAreaRatioNoSub
        let textAreaHeight = h * textAreaRatio

        // Text rects
        let headingHeight = textAreaHeight * (hasSubheading ? 0.55 : 1.0)
        let headingRect = CGRect(
            x: margin,
            y: h - topMargin - headingHeight,
            width: w - 2 * margin,
            height: headingHeight
        )

        let subheadingHeight = textAreaHeight * 0.35
        let subheadingRect = CGRect(
            x: margin * 1.5,
            y: headingRect.minY - subheadingHeight - h * 0.01,
            width: w - 3 * margin,
            height: subheadingHeight
        )

        // Device
        let deviceWidth = w * deviceWidthRatio
        let deviceAspect: CGFloat = 19.5 / 9.0  // iPhone aspect
        let deviceHeight = deviceWidth * deviceAspect

        let deviceY: CGFloat = 0  // Bottom-anchored, can extend below canvas
        let deviceX = (w - deviceWidth) / 2

        let deviceRect = CGRect(
            x: deviceX,
            y: deviceY,
            width: deviceWidth,
            height: deviceHeight
        )

        let border = deviceWidth * frameBorderRatio
        let screenInset = CGRect(
            x: border,
            y: border,
            width: deviceWidth - 2 * border,
            height: deviceHeight - 2 * border
        )

        // Font sizes (proportional to canvas)
        let headingFontSize = w * 0.07
        let subheadingFontSize = w * 0.04

        return LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: deviceRect,
            screenInset: screenInset,
            headingFontSize: headingFontSize,
            subheadingFontSize: subheadingFontSize,
            rotationAngle: 0
        )
    }

    // MARK: - Left Device Layout

    /// Device on the left, text on the right side.
    /// Good for longer text or when you want asymmetry.
    private func calculateLeftDevice(canvasSize: CGSize, hasSubheading: Bool) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * horizontalMarginRatio

        // Device on the left side
        let deviceWidth = w * 0.52
        let deviceAspect: CGFloat = 19.5 / 9.0
        let deviceHeight = deviceWidth * deviceAspect

        let deviceX = -deviceWidth * 0.08  // Slightly off-screen left
        let deviceY: CGFloat = 0

        let deviceRect = CGRect(
            x: deviceX,
            y: deviceY,
            width: deviceWidth,
            height: deviceHeight
        )

        let border = deviceWidth * frameBorderRatio
        let screenInset = CGRect(
            x: border,
            y: border,
            width: deviceWidth - 2 * border,
            height: deviceHeight - 2 * border
        )

        // Text on the right side, vertically centered
        let textX = deviceX + deviceWidth + margin
        let textWidth = w - textX - margin
        let textCenterY = h * 0.55

        let headingHeight = h * 0.15
        let headingRect = CGRect(
            x: textX,
            y: textCenterY,
            width: textWidth,
            height: headingHeight
        )

        let subheadingHeight = h * 0.12
        let subheadingRect = CGRect(
            x: textX,
            y: textCenterY - subheadingHeight - h * 0.02,
            width: textWidth,
            height: subheadingHeight
        )

        let headingFontSize = w * 0.06
        let subheadingFontSize = w * 0.035

        return LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: deviceRect,
            screenInset: screenInset,
            headingFontSize: headingFontSize,
            subheadingFontSize: subheadingFontSize,
            rotationAngle: 0
        )
    }

    // MARK: - Tilted 3D Layout

    /// Device with 3D perspective tilt, text above.
    /// Creates a dynamic, modern feel.
    private func calculateTilted(canvasSize: CGSize, hasSubheading: Bool) -> LayoutResult {
        let w = canvasSize.width
        let h = canvasSize.height
        let margin = w * horizontalMarginRatio
        let topMargin = h * topMarginRatio

        let textAreaRatio = hasSubheading ? textAreaRatioWithSub : textAreaRatioNoSub
        let textAreaHeight = h * textAreaRatio

        // Text rects (same as center but slightly adjusted)
        let headingHeight = textAreaHeight * (hasSubheading ? 0.55 : 1.0)
        let headingRect = CGRect(
            x: margin,
            y: h - topMargin - headingHeight,
            width: w - 2 * margin,
            height: headingHeight
        )

        let subheadingHeight = textAreaHeight * 0.35
        let subheadingRect = CGRect(
            x: margin * 1.5,
            y: headingRect.minY - subheadingHeight - h * 0.01,
            width: w - 3 * margin,
            height: subheadingHeight
        )

        // Tilted device — slightly larger and offset
        let deviceWidth = w * 0.7
        let deviceAspect: CGFloat = 19.5 / 9.0
        let deviceHeight = deviceWidth * deviceAspect

        let deviceX = (w - deviceWidth) / 2 + w * 0.03
        let deviceY: CGFloat = -h * 0.05

        let deviceRect = CGRect(
            x: deviceX,
            y: deviceY,
            width: deviceWidth,
            height: deviceHeight
        )

        let border = deviceWidth * frameBorderRatio
        let screenInset = CGRect(
            x: border,
            y: border,
            width: deviceWidth - 2 * border,
            height: deviceHeight - 2 * border
        )

        let headingFontSize = w * 0.07
        let subheadingFontSize = w * 0.04

        return LayoutResult(
            headingRect: headingRect,
            subheadingRect: subheadingRect,
            deviceRect: deviceRect,
            screenInset: screenInset,
            headingFontSize: headingFontSize,
            subheadingFontSize: subheadingFontSize,
            rotationAngle: -8  // 8 degrees counter-clockwise tilt
        )
    }
}
