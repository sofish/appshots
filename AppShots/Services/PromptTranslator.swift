import Foundation

/// Builds Gemini image generation prompts from ScreenPlan data.
/// The LLM produces `image_prompt` for each screen — we pass it through.
/// Only builds a fallback prompt if the LLM didn't provide one.
struct PromptTranslator {

    func translate(plan: ScreenPlan) -> [ImagePrompt] {
        plan.screens.map { screen in
            let rawPrompt = screen.imagePrompt.isEmpty
                ? buildFallback(screen: screen, plan: plan)
                : screen.imagePrompt
            let prompt = qualityEnhance(prompt: rawPrompt, screen: screen, plan: plan)
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
            let rawPrompt = iPadCfg.imagePrompt.isEmpty
                ? buildIPadFallback(screen: screen, iPadConfig: iPadCfg, plan: plan)
                : iPadCfg.imagePrompt
            let prompt = qualityEnhance(prompt: rawPrompt, screen: screen, plan: plan)
            return ImagePrompt(
                screenIndex: screen.index + 1000,   // Offset to distinguish from iPhone
                prompt: prompt,
                negativePrompt: ""
            )
        }
    }

    // MARK: - Quality Enhancement

    /// Ensures every prompt meets minimum quality standards before image generation.
    private func qualityEnhance(prompt: String, screen: ScreenConfig, plan: ScreenPlan) -> String {
        var enhanced = prompt

        // Append quality marker if missing
        let lowered = enhanced.lowercased()
        if !lowered.contains("quality") && !lowered.contains("premium") && !lowered.contains("professional") {
            enhanced += " Premium App Store quality."
        }

        // Append color guidance if no hex color is referenced
        if !enhanced.contains("#") {
            enhanced += " Colors: \(plan.colors.primary) primary, \(plan.colors.accent) accent."
        }

        // Truncate overly long prompts to keep Gemini focused
        let words = enhanced.split(separator: " ")
        if words.count > 200 {
            enhanced = words.prefix(150).joined(separator: " ") + "..."
        }

        return enhanced
    }

    // MARK: - Fallback prompt (only if LLM didn't provide image_prompt)

    private func buildFallback(screen: ScreenConfig, plan: ScreenPlan) -> String {
        var parts: [String] = []

        // Device presentation with specific angle
        let devicePresentation: String
        if screen.fullBleed {
            devicePresentation = "Full-bleed screenshot filling the entire canvas edge-to-edge with heading overlaid via gradient scrim at the bottom"
        } else if screen.tilt {
            devicePresentation = "Uploaded screenshot displayed inside a floating iPhone mockup tilted at a slight 5-degree angle with a soft drop shadow for depth"
        } else if screen.position == "left" {
            devicePresentation = "Uploaded screenshot inside an iPhone mockup positioned on the left side of the canvas, floating at a slight 5-degree tilt with subtle shadow"
        } else if screen.position == "right" {
            devicePresentation = "Uploaded screenshot inside an iPhone mockup positioned on the right side of the canvas, floating at a slight 5-degree tilt with subtle shadow"
        } else {
            devicePresentation = "Uploaded screenshot displayed inside a centered upright iPhone mockup with a subtle drop shadow, floating slightly above the background"
        }

        parts.append("App Store screenshot showcase for \"\(plan.appName)\". \(devicePresentation).")

        // Text styling with specific placement
        parts.append("Bold white heading text in the top third of the canvas: \"\(screen.heading)\".")
        if !screen.subheading.isEmpty {
            parts.append("Lighter muted subheading beneath: \"\(screen.subheading)\".")
        }

        // Background with quality cues
        if !screen.visualDirection.isEmpty {
            parts.append("Background: \(screen.visualDirection).")
        } else {
            parts.append("Background: \(plan.colors.primary) to \(plan.colors.accent) gradient with subtle ambient glow. \(plan.tone.rawValue.capitalized) aesthetic.")
        }

        // Quality and composition cues
        parts.append("Studio-quality, editorial photography aesthetic. Clean, uncluttered composition. Premium App Store quality.")

        return parts.joined(separator: " ")
    }

    // MARK: - iPad Fallback Prompt

    private func buildIPadFallback(screen: ScreenConfig, iPadConfig: iPadScreenConfig, plan: ScreenPlan) -> String {
        var parts: [String] = []

        let resolution = iPadConfig.orientation == "landscape" ? "2732x2048" : "2048x2732"

        // Device presentation with iPad-specific details per layout type
        let devicePresentation: String
        let compositionHint: String
        switch iPadConfig.layoutType {
        case .standard:
            devicePresentation = "Uploaded UI displayed inside a centered iPad Pro device mockup with thin bezel, floating slightly above the background with a subtle drop shadow"
            compositionHint = "The iPad Pro frame takes up 70% of the wider canvas width, leveraging the expansive 3:4 aspect ratio."
        case .angled:
            devicePresentation = "Uploaded UI inside an iPad Pro mockup tilted at a dynamic 8-degree 3D perspective angle with depth shadow"
            compositionHint = "The angled iPad Pro creates visual energy while showcasing the wider canvas layout."
        case .frameless:
            devicePresentation = "Uploaded UI presented as frameless floating content with rounded corners and an elegant soft drop shadow, no device bezel"
            compositionHint = "Clean, modern presentation that lets the UI speak for itself on the wider iPad canvas."
        case .headlineDominant:
            devicePresentation = "Large bold headline text dominating the top 42% of the canvas, with a smaller iPad Pro mockup showing the uploaded UI in the bottom 58%"
            compositionHint = "The headline is the visual hero — bold, high-contrast, and immediately readable."
        case .uiForward:
            devicePresentation = "Full-bleed uploaded screenshot filling the entire \(resolution) canvas edge-to-edge with heading overlaid at the bottom via gradient scrim"
            compositionHint = "Immersive presentation that maximizes visual impact of the UI across the wide iPad canvas."
        case .multiOrientation:
            devicePresentation = "Uploaded UI inside a centered iPad Pro device mockup showing the wider canvas advantage"
            compositionHint = "Leverage the iPad Pro's expansive display to showcase multi-orientation UI capabilities."
        case .darkLightDual:
            devicePresentation = "Split view showing the uploaded UI in dark and light mode variants inside iPad Pro frames"
            compositionHint = "Side-by-side presentation leverages the wider iPad canvas to show both themes simultaneously."
        case .splitPanel:
            devicePresentation = "Multiple app views shown in side-by-side panels within an iPad Pro presentation"
            compositionHint = "The wider iPad canvas allows panel-based layouts that demonstrate multitasking and split-view capabilities."
        case .beforeAfter:
            devicePresentation = "Before/after transformation split showing the uploaded UI inside an iPad Pro frame"
            compositionHint = "Diagonal split transformation that leverages the wider iPad canvas for dramatic effect."
        }

        parts.append("iPad Pro App Store screenshot (\(resolution), \(iPadConfig.orientation)) for \"\(plan.appName)\". \(devicePresentation).")
        parts.append(compositionHint)

        // Text styling with specific iPad-appropriate placement
        parts.append("Bold white heading text at the top third of the canvas: \"\(screen.heading)\".")
        if !screen.subheading.isEmpty {
            parts.append("Lighter muted subheading beneath: \"\(screen.subheading)\".")
        }

        // Background
        if !iPadConfig.visualDirection.isEmpty {
            parts.append("Background: \(iPadConfig.visualDirection).")
        } else if !screen.visualDirection.isEmpty {
            parts.append("Background: \(screen.visualDirection).")
        } else {
            parts.append("Background: \(plan.colors.primary) to \(plan.colors.accent) gradient. Text: \(plan.colors.text) on \(plan.colors.primary). \(plan.tone.rawValue.capitalized) aesthetic.")
        }

        // iPad-specific advantages and quality
        parts.append("Emphasize iPad-specific UI advantages visible in the screenshot: wider canvas, expanded toolbars, sidebars, split views, or multi-column layouts.")
        parts.append("Studio-quality, editorial photography aesthetic. Clean, uncluttered composition. Premium App Store quality.")

        return parts.joined(separator: " ")
    }
}
