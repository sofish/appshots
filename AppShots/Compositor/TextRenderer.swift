import Foundation
import CoreGraphics
#if canImport(CoreText)
import CoreText
#endif

/// Renders heading and subheading text using Core Text for precise typographic control.
/// Uses SF Pro Display as primary font (macOS system), with fallbacks.
///
/// Best practices from research:
/// - Headlines: 80-120px at 1290×2796, bold weight, must be readable at thumbnail
/// - Subheadlines: 40-60px
/// - Minimum contrast ratio: 4.5:1
/// - Start captions with action verbs
/// - 3-7 words per headline for maximum impact
struct TextRenderer {

    // MARK: - Heading

    func drawHeading(
        context: CGContext,
        text: String,
        rect: CGRect,
        color: CGColor,
        fontSize: CGFloat
    ) {
        let adjustedSize = adaptiveFontSize(text: text, maxSize: fontSize, rect: rect, isBold: true)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: createFont(size: adjustedSize, weight: .bold),
            .foregroundColor: color,
            .kern: adjustedSize * -0.02 as NSNumber  // Tight tracking for headlines
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineHeightMultiple = 1.1

        var allAttributes = attributes
        allAttributes[.paragraphStyle] = paragraphStyle

        let attributedString = NSAttributedString(string: text, attributes: allAttributes)
        drawAttributedString(context: context, string: attributedString, rect: rect)
    }

    // MARK: - Subheading

    func drawSubheading(
        context: CGContext,
        text: String,
        rect: CGRect,
        color: CGColor,
        fontSize: CGFloat
    ) {
        let adjustedSize = adaptiveFontSize(text: text, maxSize: fontSize, rect: rect, isBold: false)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: createFont(size: adjustedSize, weight: .regular),
            .foregroundColor: color,
            .kern: adjustedSize * 0.005 as NSNumber  // Slight positive tracking for readability
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineHeightMultiple = 1.25

        var allAttributes = attributes
        allAttributes[.paragraphStyle] = paragraphStyle

        let attributedString = NSAttributedString(string: text, attributes: allAttributes)
        drawAttributedString(context: context, string: attributedString, rect: rect)
    }

    // MARK: - Core Text Drawing

    private func drawAttributedString(context: CGContext, string: NSAttributedString, rect: CGRect) {
        context.saveGState()

        // Core Text uses a flipped coordinate system
        context.textMatrix = .identity

        let framesetter = CTFramesetterCreateWithAttributedString(string as CFAttributedString)

        // Create the text frame path
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)

        // Calculate vertical centering
        let frameLines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(frameLines)
        guard lineCount > 0 else {
            context.restoreGState()
            return
        }

        var origins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

        // Calculate total text height
        var totalHeight: CGFloat = 0
        for i in 0..<lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(frameLines, i), to: CTLine.self)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            totalHeight += ascent + descent + leading
        }

        // Vertical offset to center text in rect
        let verticalOffset = (rect.height - totalHeight) / 2

        // Draw each line
        for i in 0..<lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(frameLines, i), to: CTLine.self)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, nil)

            let lineOrigin = origins[i]
            let x = rect.origin.x + lineOrigin.x
            let y = rect.origin.y + lineOrigin.y + verticalOffset

            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }

        context.restoreGState()
    }

    // MARK: - Font Creation

    private func createFont(size: CGFloat, weight: FontWeight) -> CTFont {
        // Use the system font API which reliably returns SF Pro on macOS
        let ctWeight: CGFloat
        switch weight {
        case .bold: ctWeight = 0.4       // UIFontWeightBold equivalent
        case .semibold: ctWeight = 0.3
        case .medium: ctWeight = 0.23
        case .regular: ctWeight = 0.0
        }

        // CTFontCreateUIFontForLanguage returns the system UI font (SF Pro)
        let baseFont = CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("Helvetica Neue" as CFString, size, nil)

        // Apply weight via traits
        let traits = [kCTFontWeightTrait: ctWeight] as CFDictionary
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [kCTFontTraitsAttribute: traits] as CFDictionary
        )

        return CTFontCreateCopyWithAttributes(baseFont, size, nil, descriptor)
    }

    enum FontWeight {
        case regular, medium, semibold, bold
    }

    // MARK: - Adaptive Font Sizing

    /// Reduces font size if text doesn't fit within the rect.
    /// Research says: headlines should be 3-7 words, readable at thumbnail size.
    private func adaptiveFontSize(text: String, maxSize: CGFloat, rect: CGRect, isBold: Bool) -> CGFloat {
        var size = maxSize
        let minSize = maxSize * 0.5  // Don't go below half the intended size

        while size > minSize {
            let font = createFont(size: size, weight: isBold ? .bold : .regular)
            let attributes = [kCTFontAttributeName: font] as [CFString: Any]
            let attrString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!

            let framesetter = CTFramesetterCreateWithAttributedString(attrString)
            let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: 0),
                nil,
                CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                nil
            )

            if suggestedSize.height <= rect.height {
                return size
            }

            size -= 2  // Step down by 2pt
        }

        return minSize
    }
}
