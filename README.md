# AppShots

Drop in screenshots + a Markdown description, get professional App Store screenshots powered by AI. Native macOS app.

## What It Does

AppShots takes your raw app screenshots and a structured Markdown file describing your app, then automatically generates polished App Store marketing screenshots — complete with AI-generated backgrounds, device frames, and benefit-driven headlines.

## Quick Start

1. **Prepare Markdown** — Write a structured description of your app (or use the built-in "Copy Prompt" to have any LLM generate one for you)
2. **Upload Screenshots** — Drag & drop 3–6 raw screenshots from Finder or paste from Simulator (⌘V)
3. **Review Plan** — An LLM analyzes your Markdown + screenshots and proposes headlines, layouts, and background directions
4. **Generate Backgrounds** — Gemini creates custom abstract backgrounds for each screenshot in parallel
5. **Compose & Adjust** — Core Graphics composites four layers (background → screenshot → device frame → text). Tweak headings, layouts, or regenerate backgrounds instantly
6. **Export** — Batch export in multiple device sizes as PNG or JPEG, ready for App Store Connect

## Requirements

- macOS 14 (Sonoma) or later
- An OpenAI-compatible LLM API endpoint (for plan generation + prompt translation)
- A Gemini API endpoint (for background image generation)

## Build

```bash
swift build
```

Or open `Package.swift` in Xcode.

## Configuration

Open **Settings** (⌘,) to configure:
- **LLM API**: Base URL, API key, and model name (OpenAI-compatible)
- **Gemini API**: Base URL, API key, and model name

## Tech Stack

- **SwiftUI** — UI framework
- **Core Graphics / Core Text** — Image composition and text rendering
- **swift-markdown** (Apple) — Markdown parsing to AST
- **URLSession + async/await** — All network calls
- **Zero third-party dependencies** (except swift-markdown)

## Supported Export Sizes

| Device | Pixels | Default |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | Selected |
| iPhone 6.7" | 1290 × 2796 | Selected |
| iPhone 6.5" | 1242 × 2688 | — |
| iPhone 5.5" | 1242 × 2208 | — |
| iPad 13" | 2048 × 2732 | — |

## Layout Templates

- **Center Device** — Device centered, text above. Universal default.
- **Left Device** — Device left, text right. Good for longer copy.
- **Tilted 3D** — Device at perspective angle. Dynamic, modern feel.

## Project Structure

See [docs/workflow.md](docs/workflow.md) for the full pipeline architecture and data flow.
