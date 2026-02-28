import Foundation
import CoreGraphics
#if canImport(CoreText)
import CoreText
#endif
#if canImport(AppKit)
import AppKit
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

        // For ALL CAPS headlines, use positive tracking (caps need more breathing room)
        let isAllCaps = text == text.uppercased() && text != text.lowercased()
        let tracking: CGFloat = isAllCaps ? (adjustedSize * 0.05) : (adjustedSize * -0.02)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: createFont(size: adjustedSize, weight: .bold),
            .foregroundColor: color,
            .kern: tracking as NSNumber
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineHeightMultiple = 1.1

        var allAttributes = attributes
        allAttributes[.paragraphStyle] = paragraphStyle

        let attributedString = NSAttributedString(string: text, attributes: allAttributes)
        drawAttributedString(context: context, string: attributedString, rect: rect)
    }

    // MARK: - Heading Compact (for short 1-3 word headlines)

    func drawHeadingCompact(
        context: CGContext,
        text: String,
        rect: CGRect,
        color: CGColor,
        fontSize: CGFloat
    ) {
        let wordCount = text.split(separator: " ").count
        let adjustedSize = adaptiveFontSize(text: text, maxSize: fontSize, rect: rect, isBold: true)

        // For ALL CAPS headlines, use positive tracking
        let isAllCaps = text == text.uppercased() && text != text.lowercased()
        let tracking: CGFloat = isAllCaps ? (adjustedSize * 0.05) : (adjustedSize * -0.02)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: createFont(size: adjustedSize, weight: .bold),
            .foregroundColor: color,
            .kern: tracking as NSNumber
        ]

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        // Use tighter line spacing for very short headlines (1-3 words) to maximize visual punch
        paragraphStyle.lineHeightMultiple = (wordCount <= 3) ? 1.0 : 1.1

        var allAttributes = attributes
        allAttributes[.paragraphStyle] = paragraphStyle

        let attributedString = NSAttributedString(string: text, attributes: allAttributes)
        drawAttributedString(context: context, string: attributedString, rect: rect)
    }

    // MARK: - Heading with Shadow (for fullBleed — text over image)

    func drawHeadingWithShadow(
        context: CGContext,
        text: String,
        rect: CGRect,
        color: CGColor,
        fontSize: CGFloat
    ) {
        // Draw soft blur shadow by rendering shadow text 3 times at slightly different offsets
        // This creates a gaussian-like shadow effect for improved quality
        let baseOffset: CGFloat = fontSize * 0.04

        // Furthest shadow pass (largest offset, lowest alpha)
        let farShadowRect = rect.offsetBy(dx: baseOffset * 1.5, dy: -baseOffset * 1.5)
        let farShadowColor = CGColor(gray: 0, alpha: 0.3)
        drawHeading(context: context, text: text, rect: farShadowRect, color: farShadowColor, fontSize: fontSize)

        // Middle shadow pass
        let midShadowRect = rect.offsetBy(dx: baseOffset, dy: -baseOffset)
        let midShadowColor = CGColor(gray: 0, alpha: 0.5)
        drawHeading(context: context, text: text, rect: midShadowRect, color: midShadowColor, fontSize: fontSize)

        // Closest shadow pass (smallest offset, highest alpha)
        let nearShadowRect = rect.offsetBy(dx: baseOffset * 0.5, dy: -baseOffset * 0.5)
        let nearShadowColor = CGColor(gray: 0, alpha: 0.7)
        drawHeading(context: context, text: text, rect: nearShadowRect, color: nearShadowColor, fontSize: fontSize)

        // Draw main heading on top
        drawHeading(context: context, text: text, rect: rect, color: color, fontSize: fontSize)
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
            .font: createFont(size: adjustedSize, weight: .medium),
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

        // Get lines as a Swift array for safe access
        let lines: [CTLine] = (0..<lineCount).compactMap { i in
            guard let rawPtr = CFArrayGetValueAtIndex(frameLines, i) else { return nil }
            return unsafeBitCast(rawPtr, to: CTLine.self)
        }
        guard !lines.isEmpty else {
            context.restoreGState()
            return
        }

        // Calculate total text height
        var totalHeight: CGFloat = 0
        for line in lines {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            totalHeight += ascent + descent + leading
        }

        // Vertical offset to center text in rect
        let verticalOffset = (rect.height - totalHeight) / 2

        // Draw each line
        for i in 0..<lines.count {
            let line = lines[i]
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
            guard let attrString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary) else {
                size -= 2
                continue
            }

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
