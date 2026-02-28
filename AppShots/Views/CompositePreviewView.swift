import SwiftUI

/// Step 5: Preview composed screenshots.
/// Shows the final composited images and allows quick adjustments.
/// Adjustments that don't need re-generation (text, layout, colors) are instant.
struct CompositePreviewView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScreenIndex: Int = 0
    @State private var showAdjustments = false
    @State private var previewDeviceType: DeviceType = .iPhone
    @State private var zoomLevel: Double = 100.0
    @State private var showGridOverlay: Bool = false

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
        .onAppear {
            // Set up keyboard monitoring for zoom
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    if event.charactersIgnoringModifiers == "=" || event.charactersIgnoringModifiers == "+" {
                        zoomIn()
                        return nil
                    } else if event.charactersIgnoringModifiers == "-" {
                        zoomOut()
                        return nil
                    }
                }
                return event
            }
        }
    }

    private func zoomIn() {
        zoomLevel = min(200, zoomLevel + 10)
    }

    private func zoomOut() {
        zoomLevel = max(50, zoomLevel - 10)
    }

    private func fitToWindow() {
        // Calculate ideal zoom to fit a 600pt tall area
        #if canImport(AppKit)
        if selectedScreenIndex < currentImages.count {
            let image = currentImages[selectedScreenIndex]
            let imageHeight = image.size.height
            if imageHeight > 0 {
                let targetHeight: Double = 580
                let idealZoom = (targetHeight / imageHeight) * 100.0
                zoomLevel = min(200, max(50, idealZoom))
            }
        }
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            #if canImport(AppKit)
            // Image dimensions display
            if selectedScreenIndex < currentImages.count {
                let image = currentImages[selectedScreenIndex]
                if let rep = image.representations.first {
                    Text("\(rep.pixelsWide) \u{00D7} \(rep.pixelsHigh) px")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
                }
            }
            #endif

            Spacer()

            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Slider(value: $zoomLevel, in: 50...200, step: 5)
                    .frame(width: 120)

                Button {
                    zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("\(Int(zoomLevel))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                Button {
                    fitToWindow()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Fit to window")

                // Grid overlay toggle
                Toggle(isOn: $showGridOverlay) {
                    Image(systemName: "grid")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Toggle App Store safe area grid")
            }

            Divider().frame(height: 20)

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
        .padding(.horizontal, 20)
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
                let scaleFactor = zoomLevel / 100.0
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 600 * scaleFactor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                        // Grid overlay for App Store safe areas
                        if showGridOverlay {
                            GeometryReader { geo in
                                let w = geo.size.width
                                let h = geo.size.height
                                // Status bar zone (top ~5%)
                                Rectangle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: w, height: h * 0.05)
                                    .position(x: w / 2, y: h * 0.025)

                                // Home indicator zone (bottom ~3.5%)
                                Rectangle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: w, height: h * 0.035)
                                    .position(x: w / 2, y: h - h * 0.0175)

                                // Center crosshair
                                Path { path in
                                    path.move(to: CGPoint(x: w / 2, y: 0))
                                    path.addLine(to: CGPoint(x: w / 2, y: h))
                                    path.move(to: CGPoint(x: 0, y: h / 2))
                                    path.addLine(to: CGPoint(x: w, y: h / 2))
                                }
                                .stroke(Color.blue.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

                                // Rule-of-thirds grid
                                Path { path in
                                    path.move(to: CGPoint(x: w / 3, y: 0))
                                    path.addLine(to: CGPoint(x: w / 3, y: h))
                                    path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                                    path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                                    path.move(to: CGPoint(x: 0, y: h / 3))
                                    path.addLine(to: CGPoint(x: w, y: h / 3))
                                    path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                                    path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
                                }
                                .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [6, 6]))
                            }
                            .allowsHitTesting(false)
                        }
                    }
                }
                .padding()
            } else if currentImages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: previewDeviceType == .iPad ? "ipad" : "iphone")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)

                    if previewDeviceType == .iPad {
                        Text("No iPad images generated")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Enable iPad generation in the Plan step and regenerate.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button("Back to Plan") {
                            appState.goToStep(.planPreview)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Text("No iPhone images generated")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Go back to the Generate step to create screenshots.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button("Back to Generate") {
                            appState.goToStep(.generating)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
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
                appState.composeAll(deviceType: previewDeviceType)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
