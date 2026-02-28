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
        .onChange(of: appState.markdownText) { _, _ in
            parseDebounceTask?.cancel()
            parseDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                let parser = MarkdownParser()
                parsedDescriptor = try? parser.parse(appState.markdownText)
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
                previewField("App Name", desc.name)
                previewField("Tagline", desc.tagline)
                previewField("Category", desc.category)
                previewField("Platforms", desc.platforms.map(\.rawValue).joined(separator: ", "))
                previewField("Style", desc.style.displayName)
                previewField("Colors", "\(desc.colors.primary), \(desc.colors.accent)")
                previewField("Core Pitch", desc.corePitch)

                Divider()

                Text("Features (\(desc.features.count))")
                    .font(.headline)
                ForEach(desc.features) { feature in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.name)
                            .font(.callout.bold())
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

            Button("Continue") {
                appState.parseMarkdown()
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
# dotmd

> Your thoughts, locally encrypted, universally synced.

- **类别：** Productivity
- **平台：** iOS / macOS
- **语言：** en
- **风格：** minimal
- **色调：** #0a0a0a, #3b82f6

## 核心卖点
A beautiful Markdown editor that keeps your notes private with end-to-end encryption, while syncing seamlessly across all your Apple devices.

## 功能亮点

### Local-First AI Search
Find any note instantly with on-device AI-powered semantic search. Your data never leaves your device.

### End-to-End Encryption
Every note is encrypted before it leaves your device. Not even we can read your thoughts.

### Universal Sync
Seamlessly sync across iPhone, iPad, and Mac through iCloud with zero configuration.

### Beautiful Editor
A distraction-free writing experience with live Markdown preview and custom themes.

### Smart Organization
Tags, folders, and smart collections that adapt to how you think and work.

## 目标用户
Privacy-conscious writers and note-takers who want a beautiful, secure Markdown editor that works across all Apple devices.

## 补充说明
Featured by Apple as "App of the Day". 4.8 star rating with 2,000+ reviews. 50,000+ downloads.
"""
