import SwiftUI

/// Step 3: Preview and edit the screenshot plan.
/// Shows each screen as a card with editable heading/subheading,
/// layout selector, and visual direction preview.
/// Key insight: This step costs zero compute — changes are instant.
struct PlanPreviewView: View {
    @Environment(AppState.self) var appState

    // Iteration 36: Inline color editing
    @State private var editingColor: String? // "primary", "accent", "text", or nil
    @State private var colorEditText: String = ""

    // Iteration 37: Drag-to-reorder screen cards
    @State private var draggingScreenID: UUID?

    // Iteration 38: Shimmer animation
    @State private var shimmerPhase: CGFloat = -1.0

    // Iteration 31: Validation warnings
    @State private var dismissedWarnings: Set<String> = []

    // Collapse/expand all screen card details
    @State private var allCardsCollapsed = false

    // MARK: - Validation Warnings

    private var validationWarnings: [String] {
        var warnings = appState.screenPlan.validate()

        // Additional check: no screen uses tilt
        let tiltCount = appState.screenPlan.screens.filter { $0.tilt }.count
        if tiltCount == 0 && appState.screenPlan.screens.count > 1 {
            warnings.append("Try adding tilt to 1-2 screens for energy")
        }

        // Check for duplicate headings
        let headings = appState.screenPlan.screens.map(\.heading)
        let duplicates = Set(headings.filter { h in headings.filter { $0 == h }.count > 1 })
        for duplicate in duplicates.sorted() where !duplicate.isEmpty {
            warnings.append("Duplicate heading: \"\(duplicate)\"")
        }

        // Filter out dismissed warnings
        return warnings.filter { !dismissedWarnings.contains($0) }
    }

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            header
            Divider()

            // Validation warnings between header and content
            if !validationWarnings.isEmpty && !appState.screenPlan.screens.isEmpty && !appState.isLoading {
                validationWarningBanner
            }

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

    // MARK: - Validation Warning Banner

    private var validationWarningBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(validationWarnings, id: \.self) { warning in
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(warning)
                            .font(.caption2)
                            .lineLimit(1)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dismissedWarnings.insert(warning)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color.yellow.opacity(0.05))
    }

    // MARK: - Header

    /// Total word count across all screen headings
    private var totalHeadingWordCount: Int {
        appState.screenPlan.screens.reduce(0) { $0 + $1.heading.split(separator: " ").count }
    }

    private var header: some View {
        HStack {
            if !appState.screenPlan.screens.isEmpty {
                Button {
                    withAnimation {
                        allCardsCollapsed.toggle()
                    }
                } label: {
                    Label(allCardsCollapsed ? "Expand All" : "Collapse All",
                          systemImage: allCardsCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("\(totalHeadingWordCount) words total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

                        // Color swatches — tappable for inline editing
                        HStack(spacing: 4) {
                            colorSwatchButton(colorKey: "primary", hex: appState.screenPlan.colors.primary)
                            colorSwatchButton(colorKey: "accent", hex: appState.screenPlan.colors.accent)
                            colorSwatchButton(colorKey: "text", hex: appState.screenPlan.colors.text)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Inline Color Editing

    private func colorSwatchButton(colorKey: String, hex: String) -> some View {
        ColorSwatch(hex: hex, size: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(editingColor == colorKey ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                editingColor = colorKey
                colorEditText = hex
            }
            .popover(isPresented: Binding(
                get: { editingColor == colorKey },
                set: { if !$0 { editingColor = nil } }
            )) {
                VStack(spacing: 8) {
                    Text(colorKey.capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ColorSwatch(hex: colorEditText, size: 24)

                        TextField("#hex", text: $colorEditText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 100)
                            .onSubmit {
                                applyColorEdit(colorKey: colorKey)
                            }
                    }

                    Button("Done") {
                        applyColorEdit(colorKey: colorKey)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
            }
    }

    private func applyColorEdit(colorKey: String) {
        let sanitized = colorEditText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = sanitized.hasPrefix("#") ? sanitized : "#\(sanitized)"

        switch colorKey {
        case "primary":
            appState.screenPlan.colors.primary = hex
        case "accent":
            appState.screenPlan.colors.accent = hex
        case "text":
            appState.screenPlan.colors.text = hex
        default:
            break
        }
        editingColor = nil
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            // Progress indicator with message
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.loadingMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("The LLM is analyzing your app and screenshots to create an optimized plan...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 20)

            // Skeleton cards
            skeletonCards
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var skeletonCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)], spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 300)
                    .redacted(reason: .placeholder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(shimmerOverlay)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.0
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.white.opacity(0.15),
                    Color.clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.4)
            .offset(x: shimmerPhase * geometry.size.width * 1.4 - geometry.size.width * 0.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                        screenshotItem: screen.screenshotMatch >= 0 && screen.screenshotMatch < appState.screenshots.count ? appState.screenshots[screen.screenshotMatch] : nil,
                        isCollapsed: allCardsCollapsed
                    )
                    .opacity(draggingScreenID == screen.id ? 0.4 : 1.0)
                    .onDrag {
                        draggingScreenID = screen.id
                        return NSItemProvider(object: screen.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: ScreenCardReorderDelegate(
                        item: screen,
                        items: $appState.screenPlan.screens,
                        draggingItemID: $draggingScreenID
                    ))
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

            // Batch Edit menu
            if !appState.screenPlan.screens.isEmpty {
                Menu("Batch Edit") {
                    Button("Randomize Layouts") {
                        randomizeLayouts()
                    }
                    Button("Shorten Headlines") {
                        shortenHeadlines()
                    }
                }
                .menuStyle(.borderedButton)
                .disabled(appState.isLoading)
            }

            Button("Regenerate Plan") {
                appState.generatePlan()
            }
            .buttonStyle(.bordered)
            .disabled(appState.isLoading)

            Button {
                appState.startGeneration()
            } label: {
                HStack(spacing: 4) {
                    Text("Generate Screenshots")
                    if !appState.screenPlan.screens.isEmpty {
                        Text("(\(appState.screenPlan.screens.count))")
                            .foregroundStyle(.secondary)
                    }
                }
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

    // MARK: - Batch Actions

    private func randomizeLayouts() {
        let count = appState.screenPlan.screens.count
        guard count > 0 else { return }

        // Reset all to center, no tilt
        for i in 0..<count {
            appState.screenPlan.screens[i].position = "center"
            appState.screenPlan.screens[i].tilt = false
        }

        // Randomly pick 1-2 screens to tilt
        let tiltCount = min(count, Int.random(in: 1...2))
        var tiltIndices = Set<Int>()
        while tiltIndices.count < tiltCount {
            tiltIndices.insert(Int.random(in: 0..<count))
        }
        for i in tiltIndices {
            appState.screenPlan.screens[i].tilt = true
        }

        // Randomly pick 1 screen for left or right (not one already tilted)
        let availableForSide = (0..<count).filter { !tiltIndices.contains($0) }
        if let sideIndex = availableForSide.randomElement() {
            appState.screenPlan.screens[sideIndex].position = Bool.random() ? "left" : "right"
        }
    }

    private func shortenHeadlines() {
        for i in 0..<appState.screenPlan.screens.count {
            let words = appState.screenPlan.screens[i].heading.split(separator: " ")
            if words.count > 5 {
                appState.screenPlan.screens[i].heading = words.prefix(5).joined(separator: " ")
            }
        }
    }
}

// MARK: - Screen Card View

struct ScreenCardView: View {
    @Environment(AppState.self) var appState
    @Binding var screen: ScreenConfig
    let index: Int
    let screenshotItem: ScreenshotItem?
    var isCollapsed: Bool = false
    @State private var showPromptEditor = false
    @State private var isVisualDirectionExpanded = false

    // MARK: - Headline Strength Heuristic

    private var headlineStrength: (label: String, color: Color) {
        let heading = screen.heading.trimmingCharacters(in: .whitespaces)
        guard !heading.isEmpty else { return ("Empty", .gray) }

        let words = heading.split(separator: " ")
        let genericWords: Set<String> = ["the", "a", "an", "your", "our", "my", "app", "new", "best", "great", "good"]
        let firstWord = words.first.map { String($0).lowercased() } ?? ""

        // Check if first word is a verb (simple heuristic: not a generic word and not capitalized article)
        let startsWithVerb = !genericWords.contains(firstWord) && words.count >= 2
        let hasGenericStart = genericWords.contains(firstWord)
        let goodLength = heading.count >= 10 && heading.count <= 40

        if startsWithVerb && goodLength {
            return ("Strong", .green)
        } else if hasGenericStart {
            return ("Weak", .orange)
        } else if goodLength {
            return ("Good", .blue)
        } else if heading.count < 10 {
            return ("Short", .orange)
        } else {
            return ("Good", .blue)
        }
    }

    private func headingCharCountColor(_ count: Int) -> Color {
        if count > 50 { return .red }
        if count > 30 { return .orange }
        return .secondary
    }

    var body: some View {
        @Bindable var appState = appState
        VStack(alignment: .leading, spacing: 12) {
            // Card header with drag handle
            HStack {
                // Drag handle hint
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)

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

                if isCollapsed {
                    Text(screen.heading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            if !isCollapsed {

            // Screenshot thumbnail
            if let item = screenshotItem {
                Image(nsImage: item.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            }

            // Heading (editable) with character count and strength badge
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Heading")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    // Headline strength badge
                    Text(headlineStrength.label)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(headlineStrength.color.opacity(0.15)))
                        .foregroundStyle(headlineStrength.color)

                    // Character count indicator
                    Text("\(screen.heading.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(headingCharCountColor(screen.heading.count))
                }

                HStack(spacing: 6) {
                    // Color preview circle showing heading text color on primary background
                    ZStack {
                        Circle()
                            .fill(Color(hex: appState.screenPlan.colors.primary))
                            .frame(width: 18, height: 18)
                        Text("A")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: appState.screenPlan.colors.text))
                    }
                    .overlay(Circle().stroke(.quaternary, lineWidth: 0.5))

                    TextField("Heading", text: $screen.heading)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout.bold())
                }
            }

            // Subheading (editable) with character count
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Subheading")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(screen.subheading.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(headingCharCountColor(screen.subheading.count))
                }
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

            // Visual direction with expand/collapse
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Visual Direction")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isVisualDirectionExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isVisualDirectionExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

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
                    .lineLimit(isVisualDirectionExpanded ? nil : 2)
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

            } // end if !isCollapsed
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("Screen \(index + 1): \(screen.heading)")
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

// MARK: - Screen Card Reorder Delegate

struct ScreenCardReorderDelegate: DropDelegate {
    let item: ScreenConfig
    @Binding var items: [ScreenConfig]
    @Binding var draggingItemID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingItemID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = draggingItemID,
              dragID != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == dragID }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        withAnimation(.default) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
            .accessibilityLabel("Color: \(hex)")
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
