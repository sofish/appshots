import SwiftUI

/// Sheet for editing the visual direction / Gemini prompt for a single screen.
/// This is shown when the user clicks "Edit" on a screen card's background direction.
struct PromptEditorSheet: View {
    @Binding var visualDirection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Edit Background Direction")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }

            // Description
            Text("Describe the ideal background for this screenshot. Be specific about colors, gradients, mood, and abstract elements. The background should complement the text and device frame overlay.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Editor
            TextEditor(text: $visualDirection)
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
                Text("Tips for effective backgrounds:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Group {
                    tipRow("Mention specific hex colors from your palette")
                    tipRow("Describe gradient direction (top-to-bottom, radial, etc.)")
                    tipRow("Include mood keywords (calm, energetic, luxurious)")
                    tipRow("Specify abstract shapes or textures if desired")
                    tipRow("Keep it simple — busy backgrounds reduce readability")
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
                .foregroundStyle(.accent)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
