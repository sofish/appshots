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
        switch iPadConfig.layoutType {
        case .standard:
            layoutDesc = "centered iPad Pro mockup"
        case .angled:
            layoutDesc = "iPad Pro mockup with dynamic 3D perspective tilt"
        case .frameless:
            layoutDesc = "frameless floating UI with rounded corners and elegant drop shadow, no device bezel"
        case .headlineDominant:
            layoutDesc = "large bold headline taking upper half, smaller iPad mockup below"
        case .uiForward:
            layoutDesc = "full-bleed UI filling entire canvas edge-to-edge, minimal text overlay"
        case .multiOrientation:
            layoutDesc = "iPad shown in both portrait and landscape side by side"
        case .darkLightDual:
            layoutDesc = "split view showing dark mode and light mode variants"
        case .splitPanel:
            layoutDesc = "multiple app views shown in side-by-side panels"
        case .beforeAfter:
            layoutDesc = "diagonal before/after transformation split"
        }

        parts.append("Generate an iPad App Store screenshot (2048×2732, \(iPadConfig.orientation)) for \"\(plan.appName)\".")
        parts.append("Layout: \(layoutDesc).")
        parts.append("Heading: \"\(screen.heading)\"")

        if !screen.subheading.isEmpty {
            parts.append("Subheading: \"\(screen.subheading)\"")
        }

        parts.append("Style: \(plan.tone.rawValue), colors: \(plan.colors.primary) / \(plan.colors.accent)")

        if !iPadConfig.visualDirection.isEmpty {
            parts.append("Background: \(iPadConfig.visualDirection)")
        } else if !screen.visualDirection.isEmpty {
            parts.append("Background: \(screen.visualDirection)")
        }

        parts.append("Premium editorial quality.")

        return parts.joined(separator: "\n")
    }
}
