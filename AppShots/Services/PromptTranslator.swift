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
}
