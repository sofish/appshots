import Foundation

/// Builds Gemini image generation prompts from ScreenPlan data.
/// The LLM produces `image_prompt` for each screen — we pass it through.
/// Only builds a fallback prompt if the LLM didn't provide one.
struct PromptTranslator {

    func translate(plan: ScreenPlan, variationCount: Int = 1) -> [ImagePrompt] {
        plan.screens.flatMap { screen -> [ImagePrompt] in
            var prompts: [ImagePrompt] = []

            // Primary prompt (variation 0)
            let rawPrompt = screen.imagePrompt.isEmpty
                ? buildFallback(screen: screen, plan: plan)
                : screen.imagePrompt
            let prompt = qualityEnhance(prompt: rawPrompt, screen: screen, plan: plan)
            prompts.append(ImagePrompt(
                screenIndex: screen.index * 10 + 0,
                prompt: prompt,
                negativePrompt: ""
            ))

            // Additional variations (1..<variationCount)
            for varIdx in 1..<variationCount {
                let varPrompt: String
                if varIdx - 1 < screen.imagePromptVariations.count {
                    varPrompt = screen.imagePromptVariations[varIdx - 1]
                } else {
                    // Fallback: add a creative modifier to the primary prompt
                    let modifiers = [
                        "Alternative composition with warmer color temperature and soft bokeh atmosphere.",
                        "Cool-toned variation with geometric accents and frosted glass elements.",
                        "Dramatic lighting variation with bold diagonal light streaks and high contrast.",
                        "Soft minimal variation with muted tones and subtle grain texture.",
                        "Vibrant energetic variation with saturated gradients and layered depth."
                    ]
                    let modifier = modifiers[(varIdx - 1) % modifiers.count]
                    varPrompt = rawPrompt + " " + modifier
                }
                let enhanced = qualityEnhance(prompt: varPrompt, screen: screen, plan: plan)
                prompts.append(ImagePrompt(
                    screenIndex: screen.index * 10 + varIdx,
                    prompt: enhanced,
                    negativePrompt: ""
                ))
            }

            return prompts
        }
    }

    // MARK: - iPad Prompt Translation

    /// Translate iPad-specific prompts from the screen plan.
    /// Uses iPadConfig.imagePrompt if available, otherwise builds a fallback.
    /// iPad prompt indices are offset by 1000 to distinguish from iPhone prompts.
    func translateIPad(plan: ScreenPlan, variationCount: Int = 1) -> [ImagePrompt] {
        plan.screens.flatMap { screen -> [ImagePrompt] in
            let iPadCfg = screen.resolvedIPadConfig
            var prompts: [ImagePrompt] = []

            // Primary prompt (variation 0)
            let rawPrompt = iPadCfg.imagePrompt.isEmpty
                ? buildIPadFallback(screen: screen, iPadConfig: iPadCfg, plan: plan)
                : iPadCfg.imagePrompt
            let prompt = qualityEnhance(prompt: rawPrompt, screen: screen, plan: plan)
            prompts.append(ImagePrompt(
                screenIndex: screen.index * 10 + 0 + 1000,
                prompt: prompt,
                negativePrompt: ""
            ))

            // Additional variations (1..<variationCount)
            for varIdx in 1..<variationCount {
                let varPrompt: String
                if varIdx - 1 < screen.imagePromptVariations.count {
                    varPrompt = screen.imagePromptVariations[varIdx - 1]
                } else {
                    let modifiers = [
                        "Alternative composition with warmer color temperature and soft bokeh atmosphere.",
                        "Cool-toned variation with geometric accents and frosted glass elements.",
                        "Dramatic lighting variation with bold diagonal light streaks and high contrast.",
                        "Soft minimal variation with muted tones and subtle grain texture.",
                        "Vibrant energetic variation with saturated gradients and layered depth."
                    ]
                    let modifier = modifiers[(varIdx - 1) % modifiers.count]
                    varPrompt = rawPrompt + " " + modifier
                }
                let enhanced = qualityEnhance(prompt: varPrompt, screen: screen, plan: plan)
                prompts.append(ImagePrompt(
                    screenIndex: screen.index * 10 + varIdx + 1000,
                    prompt: enhanced,
                    negativePrompt: ""
                ))
            }

            return prompts
        }
    }

    // MARK: - Quality Enhancement

    /// Rotating quality cues to ensure variety across screens.
    private static let qualityCues = [
        "Cinematic editorial quality with atmospheric depth and dimension.",
        "Premium studio-lit composition with rich tonal depth.",
        "High-end App Store quality with cinematic color grading.",
        "Modern editorial showcase with layered visual depth.",
        "Studio cinematic composition with premium color science.",
        "Polished creative direction with atmospheric lighting and depth."
    ]

    /// Ensures every prompt meets minimum quality standards before image generation.
    private func qualityEnhance(prompt: String, screen: ScreenConfig, plan: ScreenPlan) -> String {
        var enhanced = prompt

        // Append a rotating quality cue based on screen index
        let lowered = enhanced.lowercased()
        if !lowered.contains("quality") && !lowered.contains("premium") && !lowered.contains("cinematic") {
            let cue = Self.qualityCues[screen.index % Self.qualityCues.count]
            enhanced += " \(cue)"
        }

        // Inject grain/texture if missing — prevents flat, sterile output
        if !lowered.contains("grain") && !lowered.contains("texture") && !lowered.contains("noise") {
            enhanced += " Fine film grain texture at 3% opacity for organic depth."
        }

        // Append color guidance if no hex color is referenced
        if !enhanced.contains("#") {
            enhanced += " Colors: \(plan.colors.primary) primary, \(plan.colors.accent) accent glow."
        }

        // Truncate overly long prompts to keep Gemini focused
        let words = enhanced.split(separator: " ")
        if words.count > 200 {
            enhanced = words.prefix(150).joined(separator: " ") + "..."
        }

        return enhanced
    }

    // MARK: - Fallback prompt (only if LLM didn't provide image_prompt)

    /// Tone-specific rich background descriptions for fallback prompts.
    private static let toneBackgrounds: [String: String] = [
        "minimal": "deep midnight (#0c1222) to indigo (#151530) to dark teal (#0f2030) mesh gradient with cool blue (#3b82f6) ambient glow from the top-right, fine film grain at 3% opacity, and faint geometric dot grid at 8% opacity",
        "playful": "vibrant coral (#ff6b6b) to amber (#f59e0b) to magenta (#ec4899) flowing mesh gradient with soft bokeh orbs scattered at varying depths, warm light streaks at 12% opacity, and subtle noise texture",
        "professional": "deep navy (#0c1222) to slate (#1e293b) to charcoal (#1a1a2e) diagonal gradient with structured geometric grid overlay at 10% opacity, steel blue (#3b82f6) ambient glow from bottom-left, and fine film grain",
        "bold": "rich black (#12121a) to electric indigo (#2a1070) to deep violet (#1a0f3e) dramatic gradient with vivid accent light source casting colored ambient glow, diagonal light streak at 15% opacity, and atmospheric depth haze",
        "elegant": "deep plum (#1a0f24) to midnight (#0c1222) to charcoal (#18181b) silk gradient with gold (#d4a574) accent light emanating softly from center, fine photographic grain texture, and scattered subtle bokeh"
    ]

    private func buildFallback(screen: ScreenConfig, plan: ScreenPlan) -> String {
        var parts: [String] = []

        // Creative app showcase — let the image model decide device positioning and composition
        parts.append("Creative app showcase composition for \"\(plan.appName)\". Uploaded screenshot displayed inside a floating iPhone mockup with ambient light and depth.")

        // Text styling with modern typography language
        parts.append("Display-weight white heading in the top third of the canvas with subtle luminous glow behind text: \"\(screen.heading)\".")
        if !screen.subheading.isEmpty {
            parts.append("Light-weight muted subheading with generous spacing beneath: \"\(screen.subheading)\".")
        }

        // Background with rich, tone-specific description
        if !screen.visualDirection.isEmpty {
            parts.append("Background: \(screen.visualDirection).")
        } else {
            let toneKey = plan.tone.rawValue
            let toneBg = Self.toneBackgrounds[toneKey] ?? "deep midnight (#0c1222) to indigo (#151530) to charcoal (#1a1a2e) mesh gradient with \(plan.colors.accent) ambient glow, fine film grain, and soft bokeh depth"
            parts.append("Background: \(toneBg).")
        }

        // Modern quality cues
        parts.append("Cinematic editorial composition with atmospheric depth and layered dimension.")

        return parts.joined(separator: " ")
    }

    // MARK: - iPad Fallback Prompt

    private func buildIPadFallback(screen: ScreenConfig, iPadConfig: iPadScreenConfig, plan: ScreenPlan) -> String {
        var parts: [String] = []

        let resolution = iPadConfig.orientation == "landscape" ? "2732x2048" : "2048x2732"

        // Creative iPad showcase — let the image model decide device positioning and composition
        parts.append("Creative iPad Pro App Store screenshot (\(resolution)) for \"\(plan.appName)\". Uploaded UI displayed inside an iPad Pro mockup with ambient light and depth.")

        // Heading text
        parts.append("Heading: \"\(screen.heading)\".")
        if !screen.subheading.isEmpty {
            parts.append("Subheading: \"\(screen.subheading)\".")
        }

        // Background
        if !iPadConfig.visualDirection.isEmpty {
            parts.append("Background: \(iPadConfig.visualDirection).")
        } else if !screen.visualDirection.isEmpty {
            parts.append("Background: \(screen.visualDirection).")
        } else {
            let toneKey = plan.tone.rawValue
            let toneBg = Self.toneBackgrounds[toneKey] ?? "deep midnight (#0c1222) to indigo (#151530) to charcoal (#1a1a2e) mesh gradient with \(plan.colors.accent) ambient glow, fine film grain, and soft bokeh depth"
            parts.append("Background: \(toneBg).")
        }

        parts.append("Cinematic editorial composition with atmospheric depth and premium color grading.")

        return parts.joined(separator: " ")
    }
}
