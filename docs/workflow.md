# AppShots — Workflow & Architecture

## Pipeline Overview

```
① Markdown Input → ② Screenshots → ③ Plan Preview → ④ Background Gen → ⑤ Compose → ⑥ Export
```

Each step maps to a view and a set of services. Users move forward through the sidebar and can go back to any completed step.

---

## Step ① Markdown Input

**View:** `MarkdownInputView`
**Service:** `MarkdownParser` (swift-markdown AST walker)

The user provides a structured Markdown document describing their app. Two paths:

- **Manual:** Write the Markdown directly in the built-in editor
- **LLM-assisted:** Click "Copy Prompt" to get a template prompt, paste it into any LLM with your app description, paste the output back

**Markdown Schema:**

```markdown
# {App Name}
> {Tagline}
- **类别：** {Category}
- **平台：** {iOS / macOS}
- **语言：** {en / zh}
- **风格：** {minimal / playful / professional / bold / elegant}
- **色调：** {#hex1, #hex2}

## 核心卖点
{1–2 sentences driving the hero screenshot}

## 功能亮点
### {Feature A}
{Benefit-driven description}
### {Feature B}
{Benefit-driven description}

## 目标用户
{One-sentence persona}

## 补充说明
{Optional: awards, ratings, social proof}
```

The parser produces an `AppDescriptor` struct with all fields typed.

---

## Step ② Screenshots

**View:** `ScreenshotGalleryView`

Users add 3–6 raw app screenshots via:
- Drag & drop from Finder
- File picker (PNG, JPEG)
- Paste from clipboard / Simulator (⌘V)

Screenshots can be **drag-reordered** — the order maps to features in the Markdown. Users also select target export sizes here (iPhone 6.9", 6.7", etc.).

---

## Step ③ Plan Preview (LLM Call #1)

**View:** `PlanPreviewView` with `ScreenCardView` cards
**Service:** `PlanGenerator` → `LLMService`

The Markdown descriptor + screenshot images are sent to an LLM. The system prompt encodes ASO best practices:

- 5-screenshot narrative framework (hero shot, core features, social proof)
- Headline writing rules (action verbs, 3–7 words, benefit-focused)
- Visual tone mapping (minimal → dark gradients, playful → bright colors, etc.)
- Layout selection guidance

**Output:** `ScreenPlan` JSON containing per-screen config:
- `heading` / `subheading` — benefit-driven copy
- `layout` — center_device / left_device / tilted
- `visual_direction` — natural language description of the ideal background
- `colors` — resolved primary, accent, text, subtext hex values

**User can edit** (zero-cost, no API call):
- Heading / subheading (inline edit on each card)
- Layout mode (toggle between three options)
- Visual direction (sheet editor)
- Screenshot ↔ feature matching

---

## Step ④ Background Generation (LLM Call #2 + Gemini × N)

**View:** `GeneratingView`
**Services:** `PromptTranslator` → `BackgroundGenerator`

Two sub-steps:

### Step 4A — Prompt Translation (LLM Call #2)

Each screen's `visual_direction` is translated into an optimized Gemini image prompt. The LLM converts natural descriptions into precise generation instructions with:
- Specific hex color references
- Composition details (gradient flow, light source)
- Negative prompt (no text, no device, no UI)

**Output:** `ImagePromptSet` — array of `ImagePrompt` per screen.

### Step 4B — Parallel Image Generation (Gemini × N)

All background prompts are sent to Gemini in parallel using `TaskGroup`. Each generates a 1290×2796 abstract background image — **no text, no devices, just backgrounds**.

The view shows a circular progress indicator and per-screen completion status.

---

## Step ⑤ Compose & Adjust

**View:** `CompositePreviewView`
**Services:** `Compositor` (Core Graphics)

Four layers are composited per screenshot:

```
Layer 4 (top)    Text: Heading + Subheading (Core Text, SF Pro Display)
Layer 3          Device Frame (PNG from asset catalog)
Layer 2          Screenshot (affine-transformed into frame bounds)
Layer 1 (bottom) Background image (from Gemini)
→ CGContext composite → NSImage
```

**Layout engine** (`LayoutEngine`) calculates all rects:
- `center_device`: device centered bottom-third, text centered above
- `left_device`: device left 40%, text right-aligned beside it
- `tilted`: device rotated with perspective transform, text above

**Text rendering** (`TextRenderer`) uses Core Text:
- SF Pro Display (system font, no bundling needed)
- Auto-sizing based on heading length
- Colors from `ResolvedColors` (text + subtext)

**Instant adjustments** (no API call, recompose only):
- Edit heading / subheading
- Switch layout
- Change colors

**Costly adjustments** (re-runs Gemini for that screen):
- Edit Gemini prompt
- Regenerate background

---

## Step ⑥ Export

**View:** `ExportView`
**Service:** `Exporter`

Batch export flow:
1. User picks output directory via `NSOpenPanel`
2. Each composed image is resized to every selected device size
3. Encoded as PNG (default) or JPEG with configurable quality
4. If JPEG exceeds 10MB (App Store limit), auto-compresses by reducing quality
5. Files written as `{app_name}_{device}_{index}.png`

Export shows a progress bar and summary with file sizes. "Show in Finder" opens the output folder.

---

## Data Flow

```
Markdown string
    │
    ▼
MarkdownParser ──→ AppDescriptor
                        │
                        ▼
    Screenshots[] ──→ PlanGenerator (LLM #1) ──→ ScreenPlan
                                                      │
                                                      ▼
                                              PromptTranslator (LLM #2) ──→ ImagePrompt[]
                                                                                │
                                                                                ▼
                                                                    BackgroundGenerator (Gemini × N)
                                                                                │
                                                                                ▼
                                                                         CGImage[] backgrounds
                                                                                │
                                    Screenshots[] + ScreenPlan + backgrounds ──→│
                                                                                ▼
                                                                         Compositor (Core Graphics)
                                                                                │
                                                                                ▼
                                                                         NSImage[] composed
                                                                                │
                                                                                ▼
                                                                         Exporter ──→ PNG/JPEG files
```

---

## Key Data Models

| Model | Source | Description |
|---|---|---|
| `AppDescriptor` | Markdown parse | App name, tagline, features, style, colors |
| `ScreenPlan` | LLM Call #1 | Per-screen heading, subheading, layout, visual direction |
| `ScreenConfig` | Part of ScreenPlan | Single screen's configuration |
| `ImagePrompt` | LLM Call #2 | Optimized Gemini prompt + negative prompt |
| `ExportConfig` | User selection | Sizes, format, quality, max file size |

## Project Layout

```
AppShots/
├── AppShotsApp.swift              # App entry point, window + menu commands
├── Models/
│   ├── AppDescriptor.swift        # Markdown parse output + enums (VisualStyle, Platform)
│   ├── ScreenPlan.swift           # LLM Call #1 output (ScreenPlan, ScreenConfig, LayoutType)
│   ├── ImagePrompt.swift          # LLM Call #2 output
│   └── ExportConfig.swift         # Export settings + DeviceSize definitions
├── Services/
│   ├── MarkdownParser.swift       # swift-markdown AST → AppDescriptor
│   ├── LLMService.swift           # OpenAI-compatible HTTP client (async/await)
│   ├── PlanGenerator.swift        # LLM Call #1 orchestration
│   ├── PromptTranslator.swift     # LLM Call #2 orchestration
│   ├── BackgroundGenerator.swift  # Gemini parallel image generation
│   ├── Compositor.swift           # Core Graphics 4-layer composition
│   ├── Exporter.swift             # Multi-size PNG/JPEG export
│   ├── SystemPrompts.swift        # All LLM system prompts + user template
│   └── AppState.swift             # Central @Observable state + step management
├── Views/
│   ├── ContentView.swift          # HSplitView: sidebar + step content
│   ├── MarkdownInputView.swift    # Step 1: editor + Copy Prompt
│   ├── ScreenshotGalleryView.swift # Step 2: drag/drop + reorder + size picker
│   ├── PlanPreviewView.swift      # Step 3: screen cards with inline editing
│   ├── GeneratingView.swift       # Step 4: progress ring + per-screen status
│   ├── CompositePreviewView.swift # Step 5: preview + adjust
│   ├── PromptEditorSheet.swift    # Visual direction editor modal
│   └── ExportView.swift           # Step 6: directory picker + progress + results
├── Compositor/
│   ├── LayoutEngine.swift         # Coordinate/rect calculations per layout type
│   ├── TextRenderer.swift         # Core Text heading/subheading rendering
│   └── DeviceFrame.swift          # Device frame PNG loading + screenshot embedding
└── Settings/
    └── SettingsView.swift         # API endpoint configuration + connection test
```
