import SwiftUI

/// Step 3: Preview and edit the screenshot plan.
/// Shows each screen as a card with editable heading/subheading,
/// layout selector, and visual direction preview.
/// Key insight: This step costs zero compute — changes are instant.
struct PlanPreviewView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if appState.isLoading {
                loadingView
            } else if appState.screenPlan.screens.isEmpty {
                emptyView
            } else {
                screenCards
            }

            Divider()
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()

            if !appState.screenPlan.screens.isEmpty {
                HStack(spacing: 12) {
                    // iPad toggle
                    Toggle(isOn: $appState.generateIPad) {
                        Label("iPad", systemImage: "ipad")
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Divider().frame(height: 20)

                    // Global tone and color info
                    HStack(spacing: 8) {
                        Label(appState.screenPlan.tone.displayName, systemImage: "paintpalette")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.quaternary))

                        // Color swatches
                        HStack(spacing: 4) {
                            ColorSwatch(hex: appState.screenPlan.colors.primary, size: 16)
                            ColorSwatch(hex: appState.screenPlan.colors.accent, size: 16)
                            ColorSwatch(hex: appState.screenPlan.colors.text, size: 16)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(appState.loadingMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("The LLM is analyzing your app and screenshots to create an optimized plan...")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No plan generated yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Generate Plan") {
                appState.generatePlan()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Screen Cards

    private var screenCards: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
            ], spacing: 16) {
                ForEach(Array(appState.screenPlan.screens.enumerated()), id: \.element.id) { index, screen in
                    ScreenCardView(
                        screen: binding(for: index),
                        index: index,
                        screenshotItem: index < appState.screenshots.count ? appState.screenshots[index] : nil
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical)
        }
    }

    private func binding(for index: Int) -> Binding<ScreenConfig> {
        Binding(
            get: {
                guard index < appState.screenPlan.screens.count else {
                    return ScreenConfig(index: index, screenshotMatch: 0, heading: "", subheading: "")
                }
                return appState.screenPlan.screens[index]
            },
            set: {
                guard index < appState.screenPlan.screens.count else { return }
                appState.screenPlan.screens[index] = $0
            }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Back") {
                appState.goToStep(.screenshots)
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Regenerate Plan") {
                appState.generatePlan()
            }
            .buttonStyle(.bordered)
            .disabled(appState.isLoading)

            Button("Generate Screenshots") {
                appState.startGeneration()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.screenPlan.screens.isEmpty || appState.isLoading)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

// MARK: - Screen Card View

struct ScreenCardView: View {
    @EnvironmentObject var appState: AppState
    @Binding var screen: ScreenConfig
    let index: Int
    let screenshotItem: ScreenshotItem?
    @State private var showPromptEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "iphone")
                    if appState.generateIPad {
                        Text("+")
                            .font(.caption2)
                        Image(systemName: "ipad")
                    }
                    Text("Screen \(index + 1)")
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)

                Spacer()

                // Hero badge for first screen
                if index == 0 {
                    Text("HERO")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange.opacity(0.2)))
                        .foregroundStyle(.orange)
                }
            }

            // Screenshot thumbnail
            if let item = screenshotItem {
                #if canImport(AppKit)
                Image(nsImage: item.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                #endif
            }

            // Heading (editable)
            VStack(alignment: .leading, spacing: 4) {
                Text("Heading")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                TextField("Heading", text: $screen.heading)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout.bold())
            }

            // Subheading (editable)
            VStack(alignment: .leading, spacing: 4) {
                Text("Subheading")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                TextField("Subheading", text: $screen.subheading)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            // Layout modifiers
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Toggle("Tilt", isOn: $screen.tilt)
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    Toggle("Full Bleed", isOn: $screen.fullBleed)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .font(.caption)

                Picker("Position", selection: $screen.position) {
                    Text("Left").tag("left")
                    Text("Center").tag("center")
                    Text("Right").tag("right")
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }

            // Image prompt (sent to Gemini)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Image Prompt")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Edit") {
                        showPromptEditor = true
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Text(screen.imagePrompt.isEmpty ? screen.visualDirection : screen.imagePrompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
            }

            // iPad layout config (shown when iPad generation is enabled)
            if appState.generateIPad {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("iPad Layout", systemImage: "ipad")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Picker("Layout", selection: iPadLayoutBinding) {
                        // Show fully implemented layouts
                        ForEach(iPadLayoutType.supportedCases) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)

                    Picker("Orientation", selection: iPadOrientationBinding) {
                        Text("Portrait").tag("portrait")
                        Text("Landscape").tag("landscape")
                    }
                    .pickerStyle(.segmented)
                    .disabled(screen.resolvedIPadConfig.layoutType == .uiForward)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showPromptEditor) {
            PromptEditorSheet(imagePrompt: $screen.imagePrompt)
        }
    }

    // MARK: - iPad Bindings

    /// Ensure iPadConfig exists, preserving any existing values.
    private func ensureIPadConfig() {
        if screen.iPadConfig == nil {
            let resolved = screen.resolvedIPadConfig
            screen.iPadConfig = iPadScreenConfig(
                layoutType: resolved.layoutType,
                orientation: resolved.orientation,
                imagePrompt: resolved.imagePrompt,
                visualDirection: resolved.visualDirection
            )
        }
    }

    private var iPadLayoutBinding: Binding<iPadLayoutType> {
        Binding(
            get: { screen.resolvedIPadConfig.layoutType },
            set: { newLayout in
                ensureIPadConfig()
                screen.iPadConfig?.layoutType = newLayout
            }
        )
    }

    private var iPadOrientationBinding: Binding<String> {
        Binding(
            get: { screen.resolvedIPadConfig.orientation },
            set: { newOrientation in
                ensureIPadConfig()
                screen.iPadConfig?.orientation = newOrientation
            }
        )
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    let hex: String
    var size: CGFloat = 20

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(.quaternary, lineWidth: 1))
    }
}

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        // Expand 3-digit hex (e.g. "f0a" → "ff00aa")
        if hexSanitized.count == 3 {
            hexSanitized = hexSanitized.map { "\($0)\($0)" }.joined()
        }

        guard hexSanitized.count == 6,
              hexSanitized.allSatisfy({ $0.isHexDigit }) else {
            self.init(red: 0, green: 0, blue: 0)
            return
        }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
