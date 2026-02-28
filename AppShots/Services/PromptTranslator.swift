import Foundation

/// Builds Gemini image generation prompts from ScreenPlan data.
/// The LLM produces `image_prompt` for each screen — we pass it through.
/// Only builds a fallback prompt if the LLM didn't provide one.
struct PromptTranslator {

    func translate(plan: ScreenPlan) -> [ImagePrompt] {
        plan.screens.map { screen in
            let prompt = screen.imagePrompt.isEmpty
                ? buildFallback(screen: screen, plan: plan)
                : screen.imagePrompt
            return ImagePrompt(
                screenIndex: screen.index,
                prompt: prompt,
                negativePrompt: ""
            )
        }
    }

    // MARK: - iPad Prompt Translation

    /// Translate iPad-specific prompts from the screen plan.
    /// Uses iPadConfig.imagePrompt if available, otherwise builds a fallback.
    /// iPad prompt indices are offset by 1000 to distinguish from iPhone prompts.
    func translateIPad(plan: ScreenPlan) -> [ImagePrompt] {
        plan.screens.map { screen in
            let iPadCfg = screen.resolvedIPadConfig
            let prompt = iPadCfg.imagePrompt.isEmpty
                ? buildIPadFallback(screen: screen, iPadConfig: iPadCfg, plan: plan)
                : iPadCfg.imagePrompt
            return ImagePrompt(
                screenIndex: screen.index + 1000,   // Offset to distinguish from iPhone
                prompt: prompt,
                negativePrompt: ""
            )
        }
    }

    // MARK: - Fallback prompt (only if LLM didn't provide image_prompt)

    private func buildFallback(screen: ScreenConfig, plan: ScreenPlan) -> String {
        var parts: [String] = []

        parts.append("Generate a modern app store screenshot for \"\(plan.appName)\" with the uploaded image inside a device mockup, creative perspective.")

        parts.append("Heading: \"\(screen.heading)\"")
        if !screen.subheading.isEmpty {
            parts.append("Subheading: \"\(screen.subheading)\"")
        }

        parts.append("Style: \(plan.tone.rawValue), colors: \(plan.colors.primary) / \(plan.colors.accent)")

        if !screen.visualDirection.isEmpty {
            parts.append("Background: \(screen.visualDirection)")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - iPad Fallback Prompt

    private func buildIPadFallback(screen: ScreenConfig, iPadConfig: iPadScreenConfig, plan: ScreenPlan) -> String {
        var parts: [String] = []

        let layoutDesc: String
        let compositionHint: String
        switch iPadConfig.layoutType {
        case .standard:
            layoutDesc = "centered iPad Pro device mockup with thin bezel"
            compositionHint = "Show the uploaded UI inside a sleek iPad Pro frame, centered on the canvas."
        case .angled:
            layoutDesc = "iPad Pro mockup with dynamic 3D perspective tilt (~8 degrees)"
            compositionHint = "Show the uploaded UI in an iPad Pro at a dynamic angle for visual energy."
        case .frameless:
            layoutDesc = "frameless floating UI with rounded corners and elegant drop shadow, no device bezel"
            compositionHint = "Display the uploaded UI as floating content with rounded corners and soft shadow — no device frame."
        case .headlineDominant:
            layoutDesc = "large bold headline dominating the top 40%, smaller iPad Pro mockup below"
            compositionHint = "Make the heading text the visual hero. Smaller iPad device shows the UI beneath."
        case .uiForward:
            layoutDesc = "full-bleed UI filling entire canvas edge-to-edge"
            compositionHint = "The uploaded screenshot fills the entire canvas. Overlay heading at bottom with gradient scrim."
        case .multiOrientation:
            layoutDesc = "iPad shown in both portrait and landscape orientations"
            compositionHint = "Show the uploaded UI inside a centered iPad Pro frame."
        case .darkLightDual:
            layoutDesc = "split view showing dark and light mode variants"
            compositionHint = "Show the uploaded UI inside a centered iPad Pro frame."
        case .splitPanel:
            layoutDesc = "multiple app views shown in side-by-side panels"
            compositionHint = "Show the uploaded UI inside a centered iPad Pro frame."
        case .beforeAfter:
            layoutDesc = "before/after transformation split"
            compositionHint = "Show the uploaded UI inside a centered iPad Pro frame."
        }

        let resolution = iPadConfig.orientation == "landscape" ? "2732×2048" : "2048×2732"

        parts.append("Generate an iPad Pro App Store screenshot (\(resolution), \(iPadConfig.orientation)) for \"\(plan.appName)\".")
        parts.append("Layout: \(layoutDesc).")
        parts.append(compositionHint)
        parts.append("Heading: \"\(screen.heading)\"")

        if !screen.subheading.isEmpty {
            parts.append("Subheading: \"\(screen.subheading)\"")
        }

        parts.append("Style: \(plan.tone.rawValue). Background colors: \(plan.colors.primary) primary, \(plan.colors.accent) accent. Text: \(plan.colors.text) on \(plan.colors.primary).")

        if !iPadConfig.visualDirection.isEmpty {
            parts.append("Visual direction: \(iPadConfig.visualDirection)")
        } else if !screen.visualDirection.isEmpty {
            parts.append("Visual direction: \(screen.visualDirection)")
        }

        parts.append("Emphasize iPad-specific UI advantages: wider canvas, expanded toolbars, sidebars, or split views if visible in the screenshot.")
        parts.append("Premium editorial App Store quality.")

        return parts.joined(separator: " ")
    }
}
