import SwiftUI

/// Sheet for editing the image prompt for a single screen.
/// This is shown when the user clicks "Edit" on a screen card's image prompt.
struct PromptEditorSheet: View {
    @Binding var imagePrompt: String
    @Environment(\.dismiss) private var dismiss

    /// The original prompt text, captured on first appearance for "Reset to Default"
    @State private var originalPrompt: String = ""
    @State private var hasSetOriginal = false

    private let maxCharacters = 500

    /// Word count of the current prompt
    private var wordCount: Int {
        imagePrompt.split(separator: " ", omittingEmptySubsequences: true).count
    }

    /// Character count of the current prompt
    private var characterCount: Int {
        imagePrompt.count
    }

    /// Word count feedback label
    private var wordCountLabel: String {
        if wordCount < 20 {
            return "\(wordCount) words (ideal: 20-50) -- could be longer"
        } else if wordCount > 50 {
            return "\(wordCount) words (ideal: 20-50) -- consider trimming"
        } else {
            return "\(wordCount) words (ideal: 20-50)"
        }
    }

    /// Word count color
    private var wordCountColor: Color {
        if wordCount >= 20 && wordCount <= 50 {
            return .green
        } else if wordCount >= 10 && wordCount <= 70 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Edit Image Prompt")
                    .font(.headline)
                Spacer()

                Button("Clear") {
                    imagePrompt = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(imagePrompt.isEmpty)

                Button("Reset to Default") {
                    imagePrompt = originalPrompt
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(imagePrompt == originalPrompt)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }

            // Description
            Text("This prompt is sent directly to the AI image generator along with the screenshot. Describe the full composition: device presentation, text placement, background, and atmosphere.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Quick Templates
            quickTemplates

            // Editor
            TextEditor(text: $imagePrompt)
                .font(.body)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                )

            // Character and word count
            HStack {
                Text("\(characterCount) / \(maxCharacters) characters")
                    .font(.caption)
                    .foregroundStyle(characterCount > maxCharacters ? .red : .secondary)

                Spacer()

                Text(wordCountLabel)
                    .font(.caption)
                    .foregroundStyle(wordCountColor)
            }

            // Tips
            VStack(alignment: .leading, spacing: 6) {
                Text("Tips for effective prompts:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Group {
                    tipRow("Be concise -- 1-3 sentences work best")
                    tipRow("Describe the creative perspective and device angle")
                    tipRow("Include the heading text you want rendered")
                    tipRow("Mention colors, mood, and atmosphere")
                    tipRow("Let the AI be creative -- don't over-specify")
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
        }
        .padding(24)
        .frame(width: 600, height: 550)
        .onAppear {
            if !hasSetOriginal {
                originalPrompt = imagePrompt
                hasSetOriginal = true
            }
        }
    }

    // MARK: - Quick Templates

    private var quickTemplates: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Templates")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    imagePrompt = modernMinimalTemplate
                } label: {
                    Label("Modern Minimal", systemImage: "square.grid.2x2")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    imagePrompt = dramaticHeroTemplate
                } label: {
                    Label("Dramatic Hero", systemImage: "bolt.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    imagePrompt = editorialShowcaseTemplate
                } label: {
                    Label("Editorial Showcase", systemImage: "book.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Template Strings

    private var modernMinimalTemplate: String {
        "Clean white background with subtle light gray gradient. The device is centered with a slight floating shadow, tilted 2 degrees. Minimal typography above the device in a thin sans-serif font. Generous whitespace, no decorative elements. Muted accent color used sparingly for the heading text. The overall feel is calm, modern, and premium."
    }

    private var dramaticHeroTemplate: String {
        "Deep dark background with a bold gradient sweeping diagonally from deep navy to vivid accent color. The device is prominently displayed at a dynamic 8-degree tilt with dramatic lighting from the upper left casting a long shadow. Large bold headline text in white with strong contrast. Subtle lens flare and ambient glow behind the device. The mood is powerful, confident, and attention-grabbing."
    }

    private var editorialShowcaseTemplate: String {
        "Elegant editorial layout with a warm neutral background featuring soft paper texture. The device is positioned slightly left of center with refined perspective. Sophisticated serif-style heading text aligned to the right of the device. Subtle golden accent highlights. Thin decorative lines frame the composition. The aesthetic is magazine-quality, refined, and aspirational."
    }

    // MARK: - Tip Row

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
