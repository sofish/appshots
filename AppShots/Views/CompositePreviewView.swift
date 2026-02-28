import SwiftUI

/// Step 5: Preview composed screenshots.
/// Shows the final composited images and allows quick adjustments.
/// Adjustments that don't need re-generation (text, layout, colors) are instant.
struct CompositePreviewView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScreenIndex: Int = 0
    @State private var showAdjustments = false
    @State private var previewDeviceType: DeviceType = .iPhone

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if appState.isLoading {
                loadingView
            } else {
                contentView
            }

            Divider()
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.title2.bold())
                Text("Review your composed screenshots. Quick adjustments are instant.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            #if canImport(AppKit)
            if appState.generateIPad && !appState.iPadComposedImages.isEmpty {
                Picker("Device", selection: $previewDeviceType) {
                    Text("iPhone").tag(DeviceType.iPhone)
                    Text("iPad").tag(DeviceType.iPad)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .onChange(of: previewDeviceType) { _, _ in
                    selectedScreenIndex = 0
                }
            }

            Text("\(currentImages.count) screenshots")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.quaternary))
            #endif
        }
        .padding()
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(appState.loadingMessage)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var contentView: some View {
        HSplitView {
            // Main preview
            mainPreview
                .frame(minWidth: 300)

            // Side panel: thumbnails + adjustments
            sidePanel
                .frame(width: 260)
        }
    }

    #if canImport(AppKit)
    /// Images for the currently selected device type.
    private var currentImages: [NSImage] {
        previewDeviceType == .iPad ? appState.iPadComposedImages : appState.composedImages
    }
    #endif

    // MARK: - Main Preview

    private var mainPreview: some View {
        VStack {
            #if canImport(AppKit)
            if selectedScreenIndex < currentImages.count {
                let image = currentImages[selectedScreenIndex]
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 600)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .padding()
            } else {
                Text("No preview available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #endif
        }
    }

    // MARK: - Side Panel

    private var sidePanel: some View {
        VStack(spacing: 0) {
            // Thumbnail strip
            Text("Screens")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 8) {
                    #if canImport(AppKit)
                    ForEach(Array(currentImages.enumerated()), id: \.offset) { index, image in
                        thumbnailCard(image: image, index: index)
                    }
                    #endif
                }
                .padding(8)
            }

            Divider()

            // Quick adjustments
            if selectedScreenIndex < appState.screenPlan.screens.count {
                quickAdjustments
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    #if canImport(AppKit)
    private func thumbnailCard(image: NSImage, index: Int) -> some View {
        let isSelected = selectedScreenIndex == index
        return Button {
            selectedScreenIndex = index
        } label: {
            VStack(spacing: 4) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    )

                HStack {
                    if index == 0 {
                        Text("HERO")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                    Text("Screen \(index + 1)")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - Quick Adjustments

    private var quickAdjustments: some View {
        let screenBinding = Binding<ScreenConfig>(
            get: {
                guard selectedScreenIndex < appState.screenPlan.screens.count else {
                    return ScreenConfig(index: 0, screenshotMatch: 0, heading: "", subheading: "")
                }
                return appState.screenPlan.screens[selectedScreenIndex]
            },
            set: { newValue in
                guard selectedScreenIndex < appState.screenPlan.screens.count else { return }
                appState.screenPlan.screens[selectedScreenIndex] = newValue
            }
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text("Quick Adjust")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            // Heading
            TextField("Heading", text: screenBinding.heading)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            // Subheading
            TextField("Subheading", text: screenBinding.subheading)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            // Layout modifiers
            Toggle("Tilt", isOn: screenBinding.tilt)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("Full Bleed", isOn: screenBinding.fullBleed)
                .toggleStyle(.switch)
                .controlSize(.small)

            Picker("Position", selection: screenBinding.position) {
                Text("Left").tag("left")
                Text("Center").tag("center")
                Text("Right").tag("right")
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            // Recompose button (instant, no LLM)
            Button("Recompose") {
                #if canImport(AppKit)
                appState.recomposeSingle(screenIndex: selectedScreenIndex, deviceType: previewDeviceType)
                #endif
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Re-render with current settings (instant, no AI)")

            // Regenerate background (costs compute)
            Button("Regenerate Background") {
                appState.regenerateBackground(screenIndex: selectedScreenIndex)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundStyle(.orange)
            .help("Generate a new AI background (~10s)")
        }
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Back to Plan") {
                appState.goToStep(.planPreview)
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Recompose All") {
                #if canImport(AppKit)
                appState.composeAll()
                #endif
            }
            .buttonStyle(.bordered)

            Button("Export") {
                appState.currentStep = .export
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
}
