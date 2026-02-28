import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Step 1: Markdown input view.
/// Users can type/paste Markdown or import from a file.
/// Includes a "Copy Prompt" button for the LLM prompt template.
struct MarkdownInputView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCopiedToast = false
    @State private var parsedDescriptor: AppDescriptor?
    @State private var parseDebounceTask: Task<Void, Never>?
    @State private var borderGlowActive = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Main content: editor + preview side by side
            HSplitView {
                // Editor
                editorPane
                    .frame(minWidth: 300)

                // Live preview
                previewPane
                    .frame(minWidth: 280)
            }
            .padding(.horizontal, 20)

            Divider()

            // Footer with action button
            footer
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green.opacity(borderGlowActive ? 0.5 : 0.0), lineWidth: 3)
                .blur(radius: borderGlowActive ? 6 : 0)
                .animation(.easeInOut(duration: 1.0), value: borderGlowActive)
        )
        .onChange(of: appState.markdownText) { _, _ in
            parseDebounceTask?.cancel()
            parseDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                let parser = MarkdownParser()
                let result = try? parser.parse(appState.markdownText)
                parsedDescriptor = result
                // Trigger border glow on successful parse
                if result != nil {
                    borderGlowActive = true
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s glow
                    guard !Task.isCancelled else { return }
                    borderGlowActive = false
                } else {
                    borderGlowActive = false
                }
            }
        }
        .onAppear {
            if !appState.markdownText.isEmpty {
                let parser = MarkdownParser()
                parsedDescriptor = try? parser.parse(appState.markdownText)
            }
        }
        .onDisappear {
            parseDebounceTask?.cancel()
            parseDebounceTask = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()

            // Copy Prompt button
            Button {
                copyPromptTemplate()
            } label: {
                Label(showCopiedToast ? "Copied!" : "Copy Prompt", systemImage: showCopiedToast ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)

            // Import file
            Button {
                importMarkdownFile()
            } label: {
                Label("Import", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)

            // Load sample
            Button {
                loadSampleMarkdown()
            } label: {
                Label("Sample", systemImage: "text.document")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Editor Pane

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Markdown Editor")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            TextEditor(text: $appState.markdownText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)

            // Character count footer
            HStack {
                Text("\(appState.markdownText.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Parsed Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                if appState.markdownText.isEmpty {
                    emptyPreview
                } else {
                    parsedPreview
                }
            }
            .padding(8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyPreview: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Start typing or paste your Markdown")
                .foregroundStyle(.secondary)
            Text("Use the \"Copy Prompt\" button to get a template for generating the Markdown with any LLM.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var parsedPreview: some View {
        if let desc = parsedDescriptor {
            VStack(alignment: .leading, spacing: 12) {
                // App Name in blue
                coloredPreviewField("App Name", desc.name, color: .blue)
                // Tagline in purple
                coloredPreviewField("Tagline", desc.tagline, color: .purple)
                previewField("Category", desc.category)
                previewField("Platforms", desc.platforms.map(\.rawValue).joined(separator: ", "))
                previewField("Style", desc.style.displayName)
                previewField("Colors", "\(desc.colors.primary), \(desc.colors.accent)")
                previewField("Core Pitch", desc.corePitch)

                Divider()

                // Features section with count and color
                HStack {
                    Text("Features (\(desc.features.count))")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(desc.features.count) features detected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                }

                ForEach(desc.features) { feature in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.name)
                            .font(.callout.bold())
                            .foregroundStyle(.green)
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                if !desc.targetAudience.isEmpty {
                    Divider()
                    previewField("Target Audience", desc.targetAudience)
                }

                if let proof = desc.socialProof {
                    previewField("Social Proof", proof)
                }
            }
            .padding()
        } else {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text("Could not parse Markdown")
                    .font(.callout)
                Text("Make sure your Markdown follows the expected format.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func previewField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.callout)
        }
    }

    private func coloredPreviewField(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.callout)
                .foregroundStyle(color)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if !appState.markdownText.isEmpty {
                let isValid = parsedDescriptor != nil
                Label(
                    isValid ? "Valid Markdown" : "Invalid format",
                    systemImage: isValid ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(isValid ? .green : .red)
                .font(.callout)
            }

            Spacer()

            Button {
                appState.parseMarkdown()
            } label: {
                HStack(spacing: 6) {
                    if parsedDescriptor != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text("Continue")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.markdownText.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Actions

    private func copyPromptTemplate() {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(SystemPrompts.userPromptTemplate, forType: .string)
        #endif
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func importMarkdownFile() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                appState.markdownText = content
            }
        }
        #endif
    }

    private func loadSampleMarkdown() {
        appState.markdownText = sampleMarkdown
    }
}

// MARK: - Sample Markdown

private let sampleMarkdown = """
# Momento

> Your life is worth remembering. Momento makes it effortless.

- **类别：** Photography & Lifestyle
- **平台：** iOS / macOS
- **语言：** en
- **风格：** elegant
- **色调：** #1a1a2e, #e8b931

## 核心卖点
Momento transforms your scattered photo library into a beautifully curated life journal. Every photo, every place, every feeling — woven into timelines that feel like opening a window to the past. Preserve your most meaningful moments with zero effort and absolute privacy.

## 功能亮点

### Relive Any Day in a Single Tap
Automatic daily journals crafted from your photos, locations, and notes — beautifully arranged so every ordinary Tuesday feels worth remembering.

### Smart Albums That Actually Understand You
AI-powered organization groups photos by people, places, seasons, and emotions — no manual tagging, no tedious sorting, just memories that find themselves.

### Tell Stories, Not Just Show Photos
Weave photos, handwritten captions, and voice memos into rich visual narratives you can share with loved ones or treasure privately for years to come.

### Private by Design, Beautiful by Default
Every memory stays on-device with end-to-end encrypted iCloud sync. No servers, no tracking, no compromise — just your story, protected and elegantly presented.

### Print-Ready Keepsakes in Minutes
Turn any album into a stunning hardcover photo book or gallery-quality wall print — designed automatically by Momento, delivered to your door.

## 目标用户
Creative individuals who value their memories — photographers, journalers, parents, and travelers who want a beautiful, private way to preserve, organize, and share the moments that matter most.

## 补充说明
Rated 4.9 stars with 100K+ downloads worldwide. Featured in "Apps We Love" on the App Store. Winner of the 2025 Apple Design Award for Delight and Fun. Trusted by professional photographers and everyday memory-keepers alike.
"""
