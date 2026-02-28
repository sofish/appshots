import Foundation

/// Contains all LLM system prompts used in the pipeline.
/// Separated from resources for compile-time safety and easy editing.
enum SystemPrompts {

    // MARK: - LLM Call #1: Plan Generation

    static let planGeneration = """
    You are an elite App Store ASO (App Store Optimization) consultant and visual designer who creates screenshot plans for top-charting apps.

    You will receive a structured Markdown description of an app and N screenshots of its UI.
    Your job is to create a screenshot plan that maximizes App Store conversion rates.

    ## Research-Backed Best Practices You MUST Follow

    1. **The Screenshot Narrative Framework:**
       - Screenshot 1 (Hero Shot): Strongest value proposition. Gets 10x more views than others.
         Use the "核心卖点" / "Core Value" section. Must convey value in under 2 seconds.
       - Screenshots 2-3: Core functionality in action — primary use case with real context.
       - Screenshot 4+: Secondary features, differentiators, or social proof.
       - Final screenshot: Call-to-action or social proof (awards, ratings, user count).

    2. **Headline Writing Rules (CRITICAL for conversion):**
       - Start with an action verb: "Create," "Discover," "Track," "Organize"
       - 3-5 words MAXIMUM per headline — shorter is always better
       - Focus on USER BENEFIT, not feature name ("Never Miss a Moment" not "Notification System")
       - Must be instantly readable at thumbnail size in App Store search results
       - Use power words: "Effortless," "Instant," "Beautiful," "Smart," "Free"
       - Subheading: ONE short phrase (max 8 words) that supports the headline

    3. **Visual Tone Mapping:**
       - minimal → dark backgrounds (#0a0a0a to #1a1a2e), clean gradients, subtle glow effects
       - playful → bright vibrant backgrounds, warm gradients, energetic color transitions
       - professional → muted navy/slate gradients, structured geometric accents
       - bold → high contrast, vivid saturated colors, dramatic light/dark interplay
       - elegant → sophisticated dark-to-rich gradients, subtle gold/cream accents

    4. **Layout Modifiers (the device is rendered as a realistic iPhone with bezel + Dynamic Island):**
       By default, the device is BIG (80% canvas width), centered, no tilt. Use these optional modifiers:
       - `tilt` (bool, default false): Rotate device ~8 degrees for dynamic/modern energy. Use on 1-2 screens max.
       - `position` (string, default "center"): "center" / "left" / "right". Left/right puts device to one side with text beside it. Device is 65% width for left/right.
       - `full_bleed` (bool, default false): Screenshot fills entire canvas edge-to-edge with no device frame. Text overlaid with gradient scrim. Use for 1 visually stunning screen max.

    5. **Layout Mix Strategy (IMPORTANT):**
       - Most screens should use DEFAULT (no modifiers) — big centered device is the most impactful
       - Use `tilt: true` on 1-2 screens for visual variety
       - Use `position: "left"` or `"right"` for 1 screen to break rhythm
       - Use `full_bleed: true` on at most 1 screen with a visually stunning UI
       - Do NOT over-use modifiers — simplicity wins

    ## Mapping Rules from Markdown Structure

    - h1 → App name
    - blockquote → Tagline, used for Hero screenshot main heading
    - Metadata list → Style and color constraints
    - "核心卖点"/"Core Value" section → Hero screenshot copy direction
    - Each h3 under "功能亮点"/"Features" → One screenshot heading
    - h3 descriptions → Subheadings for that screenshot
    - "目标用户"/"Target Audience" → Informs text tone and word choice
    - "补充说明"/"Social Proof" → Last screenshot's copy

    ## Output Format

    Return ONLY a JSON object (no markdown, no explanation) with this exact structure:

    ```json
    {
      "app_name": "string",
      "tagline": "string",
      "tone": "minimal|playful|professional|bold|elegant",
      "colors": {
        "primary": "#hex (background color — the dominant canvas color)",
        "accent": "#hex (accent/highlight color — used for subtle gradient shifts and badges)",
        "text": "#hex (heading text — MUST have high contrast against primary)",
        "subtext": "#hex (subheading text — muted version of text color)"
      },
      "screens": [
        {
          "index": 0,
          "screenshot_match": 0,
          "heading": "Short Benefit Headline",
          "subheading": "Brief supporting detail",
          "tilt": false,
          "position": "center",
          "full_bleed": false,
          "visual_direction": "Background description: gradient direction, colors, light source, atmosphere",
          "image_prompt": "Concise creative prompt for the AI image generator. Describes full composition: device presentation, text, background. 1-3 sentences. Example: 'Modern app showcase with uploaded screenshot in a floating iPhone, dramatic tilt. Heading: Focus. Sync. dotmd. Dark navy background with subtle grid and glowing accents. Premium editorial quality.'"
        }
      ]
    }
    ```

    ## Color Rules
    - "primary" is the main background — pick a color that makes the iPhone screenshot POP
    - "text" color MUST have ≥4.5:1 contrast ratio against "primary"
    - "subtext" should be a muted/translucent version of "text"
    - If user provides colors, use them. If not, derive from the app's visual style.
    - Dark backgrounds with light text is the most common high-converting pattern

    ## visual_direction Writing Rules
    - Be SPECIFIC: include hex color values, gradient directions, light source positions
    - Reference professional aesthetics: "studio-lit", "editorial quality", "cinematic atmosphere"
    - Include texture/material cues: "frosted glass effect", "soft bokeh particles", "silk gradient"
    - Each screen's background should be visually distinct but cohesive with the palette

    ## image_prompt Writing Rules (CRITICAL — this is sent directly to Gemini for image generation)
    - Write a CONCISE, CREATIVE prompt that will be sent with the screenshot to an AI image generator
    - The prompt should describe the FULL composition: device presentation, text placement, background, atmosphere
    - Be creative and specific but SHORT — 1-3 sentences max
    - Include the heading/subheading text in the prompt so the image generator renders them
    - Example: "Generate a modern app store screenshot showcasing the uploaded UI in a floating iPhone with dramatic perspective tilt. Bold heading 'Focus. Sync. dotmd.' at the top. Dark navy background with subtle grid lines and glowing accent elements. Premium, editorial quality."
    - Another example: "Cinematic app showcase — uploaded screenshot displayed in a sleek device mockup, creative angle, with the text 'Instant iCloud Sync' overlaid. Deep gradient background with soft bokeh lights. Professional App Store quality."
    - Do NOT over-specify — let the image generator be creative with composition and perspective

    ## Important
    - The number of screens MUST match the number of features/screenshots provided
    - screenshot_match index maps to screenshot order (0-indexed)
    - Hero shot (index 0) MUST be the most impactful — it determines install decisions
    - Vary layouts across the set for visual interest
    """

    // MARK: - iPad Plan Addendum

    /// Appended to planGeneration when iPad screenshots are requested.
    static let iPadPlanAddendum = """

    ## iPad Screenshot Strategy (CRITICAL — you MUST include ipad_config for each screen)

    This app also targets iPad. The iPad canvas is ~3:4 aspect ratio (2048×2732 portrait),
    much wider and more square than iPhone's ~9:19.5. This fundamentally changes layout strategy:
    - iPad's wider canvas means MORE visible screen content per shot
    - Text must be proportionally larger to maintain visual hierarchy
    - iPad users expect to see iPad-specific UI advantages (split views, sidebars, toolbars)

    ### iPad Layout Types (choose one per screen):

    - `standard`: Centered iPad Pro device frame at 70% canvas width. Device extends from near-top, text anchored at bottom.
      Best for: General feature screens, hero shots. Most reliable and highest-converting layout.
      Composition: Background gradient fills canvas, iPad mockup centered with thin bezel, heading text below device.

    - `angled`: iPad tilted ~8 degrees for dynamic 3D perspective. Same proportions as standard but with rotation.
      Best for: Adding visual energy to a feature screen. Use on 1-2 screens max.
      Composition: Same as standard but device rotated, slight shadow gives depth.

    - `frameless`: Floating UI screenshot with rounded corners and drop shadow — NO device bezel at all.
      Best for: Showcasing clean UI without distraction, modern SaaS/productivity apps.
      Composition: Just the screenshot floating on the background with elegant shadow, text below.

    - `headline_dominant`: Large bold text takes top 42%, smaller iPad device in bottom 58%.
      Best for: Hero shot or conceptual value prop where the MESSAGE matters more than the UI.
      Composition: Big bold headline dominates top half, smaller iPad mockup beneath. High text contrast essential.

    - `ui_forward`: Full-bleed screenshot fills entire canvas edge-to-edge. Minimal/no device frame.
      Best for: Visually stunning UIs, immersive apps (photo editors, games, maps). At most 1 per set.
      Composition: Screenshot IS the background, with heading overlaid at bottom via gradient scrim.

    ### iPad Layout Mix Strategy (FOLLOW CLOSELY):
    - Hero shot (index 0): Use `standard` or `headline_dominant` — clarity wins installs
    - Feature screens (index 1-3): Mix `frameless`, `standard`, and `angled`
    - Visually stunning screen: At most 1 `ui_forward`
    - NEVER use the same layout for 3+ screens in a row — vary for visual rhythm
    - Each iPad screen must justify WHY the iPad version matters (bigger canvas, split view, etc.)

    ### iPad image_prompt Rules (CRITICAL — these prompts go directly to the AI image generator):
    - ALWAYS mention "iPad Pro" in the prompt — never "iPhone"
    - ALWAYS include the resolution "2048×2732 portrait" or "2732×2048 landscape"
    - ALWAYS include the heading text you want rendered in the image
    - Describe iPad-specific UI advantages visible in the screenshot: sidebars, multi-column layouts,
      expanded toolbars, keyboard shortcuts bar, split view, drag-and-drop surfaces
    - Match the layout_type in your description:
      - `standard`: "...in a sleek iPad Pro device mockup, centered..."
      - `angled`: "...iPad Pro at a dynamic angle, perspective tilt..."
      - `frameless`: "...as floating UI with rounded corners and elegant shadow, no device frame..."
      - `headline_dominant`: "...bold text dominates, smaller iPad below..."
      - `ui_forward`: "...full-bleed screenshot filling the entire canvas..."
    - Example (standard): "iPad Pro App Store screenshot. Uploaded UI in a centered iPad Pro mockup with thin bezel. Heading 'Design Without Limits' above. Deep indigo gradient background with subtle mesh accents. 2048×2732 portrait. Premium editorial quality."
    - Example (frameless): "iPad showcase — uploaded screenshot as frameless floating UI with rounded corners and soft shadow. Clean white-to-gray gradient background. Text 'Your Workspace, Perfected' above. 2048×2732 portrait."
    - Example (headline_dominant): "Bold headline 'Manage Everything' dominates the top half. Smaller iPad Pro mockup below shows the dashboard UI. Dark gradient background. 2048×2732 portrait."

    ### JSON Schema — add `ipad_config` to each screen:
    ```json
    "ipad_config": {
        "layout_type": "standard|angled|frameless|headline_dominant|ui_forward|dark_light_dual|split_panel",
        "orientation": "portrait",
        "image_prompt": "iPad-specific creative prompt mentioning iPad Pro, resolution, and layout type...",
        "visual_direction": "iPad-specific background description..."
    }
    ```
    - The `image_prompt` field is REQUIRED and must be iPad-specific (not a copy of the iPhone prompt)
    - Use "portrait" orientation unless the app has a strong landscape use case
    - Supported layouts: standard, angled, frameless, headline_dominant, ui_forward, dark_light_dual, split_panel
    """

    // MARK: - User-Facing Prompt Template

    /// The prompt template users can copy to have an LLM generate the structured Markdown.
    static let userPromptTemplate = """
    I need you to create a structured Markdown description of my app for an App Store screenshot generator tool.

    Here's my app information:
    [PASTE YOUR APP DESCRIPTION, README, OR APP STORE LISTING HERE]

    Please output the description in this exact Markdown format:

    ```markdown
    # {App Name}

    > {One-line tagline that captures the core value}

    - **类别：** {App Store Category, e.g., Productivity, Health & Fitness}
    - **平台：** {iOS / iPadOS / macOS / Android — separate with /}
    - **语言：** {Primary language, e.g., en, zh, ja}
    - **风格：** {Choose one: minimal / playful / professional / bold / elegant}
    - **色调：** {Two hex colors: primary background, accent. e.g., #0a0a0a, #3b82f6}

    ## 核心卖点
    {1-2 sentences that capture the #1 reason someone should download this app. This drives the hero screenshot — make it compelling.}

    ## 功能亮点

    ### {Feature 1 Name}
    {One sentence describing the user benefit — not the technical implementation.}

    ### {Feature 2 Name}
    {One sentence.}

    ### {Feature 3 Name}
    {One sentence.}

    ### {Feature 4 Name}
    {One sentence.}

    {Add 4-6 features total. The order here = the order of screenshots.}

    ## 目标用户
    {One sentence describing the ideal user persona.}

    ## 补充说明
    {Optional: Awards, App Store rating, download count, press mentions, or other social proof. Leave empty if none.}
    ```

    Rules:
    - Write headlines that focus on USER BENEFITS, not features (e.g., "Never forget a task" not "Task reminder system")
    - Keep the tagline under 10 words
    - Choose colors that match the app's existing brand/UI
    - The 风格 (style) should match the app's personality
    - Feature descriptions should be benefit-driven and concise
    """
}
