import SwiftUI

/// Sheet for editing the image prompt for a single screen.
/// This is shown when the user clicks "Edit" on a screen card's image prompt.
struct PromptEditorSheet: View {
    @Binding var imagePrompt: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Edit Image Prompt")
                    .font(.headline)
                Spacer()
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

            // Editor
            TextEditor(text: $imagePrompt)
                .font(.body)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                )

            // Tips
            VStack(alignment: .leading, spacing: 6) {
                Text("Tips for effective prompts:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Group {
                    tipRow("Be concise — 1-3 sentences work best")
                    tipRow("Describe the creative perspective and device angle")
                    tipRow("Include the heading text you want rendered")
                    tipRow("Mention colors, mood, and atmosphere")
                    tipRow("Let the AI be creative — don't over-specify")
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
        }
        .padding(24)
        .frame(width: 500, height: 450)
    }

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
