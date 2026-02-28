import Foundation
import AppKit
import SwiftUI
import Observation

/// Central state management for the AppShots pipeline.
/// Drives the UI through the 6-step workflow:
/// 1 Markdown -> 2 Screenshots -> 3 Preview Plan -> 4 Generate Backgrounds -> 5 Compose -> 6 Export
@MainActor
@Observable final class AppState {

    // MARK: - Workflow Step

    enum Step: Int, CaseIterable, Identifiable {
        case markdown = 0
        case screenshots
        case planPreview
        case generating
        case composing
        case export

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .markdown: return "Markdown"
            case .screenshots: return "Screenshots"
            case .planPreview: return "Preview Plan"
            case .generating: return "Generate"
            case .composing: return "Compose"
            case .export: return "Export"
            }
        }

        var subtitle: String {
            switch self {
            case .markdown: return "Describe your app"
            case .screenshots: return "Upload screenshots"
            case .planPreview: return "Review & edit"
            case .generating: return "AI composition"
            case .composing: return "Quick adjustments"
            case .export: return "Save to disk"
            }
        }

        var iconName: String {
            switch self {
            case .markdown: return "doc.text"
            case .screenshots: return "photo.on.rectangle"
            case .planPreview: return "rectangle.3.group"
            case .generating: return "sparkles"
            case .composing: return "paintbrush"
            case .export: return "square.and.arrow.up"
            }
        }
    }

    // MARK: - Published State

    var currentStep: Step = .markdown
    var markdownText: String = ""
    var descriptor: AppDescriptor = .empty
    var screenshots: [ScreenshotItem] = []
    var screenPlan: ScreenPlan = .empty
    var imagePrompts: [ImagePrompt] = []
    var backgroundImages: [Int: Data] = [:]
    var composedImages: [NSImage] = []
    var exportConfig: ExportConfig = .default
    var selectedSizes: Set<String> = Set(DeviceSize.defaultSizes.map(\.id))

    // iPad state
    var generateIPad: Bool = false
    var iPadBackgroundImages: [Int: Data] = [:]
    var iPadComposedImages: [NSImage] = []

    // UI State
    var isLoading = false
    var loadingMessage = ""
    var errorMessage: String?
    var showError = false
    var generationProgress: Double = 0
    var exportResults: [Exporter.ExportResult] = []

    // MARK: - Retry State

    var retryCount: Int = 0
    let maxRetries: Int = 3

    // MARK: - Computed Properties

    /// Whether the user can export: at least one composed image AND at least one size selected
    var canExport: Bool {
        let hasImages = !composedImages.isEmpty || !iPadComposedImages.isEmpty
        let hasSizes = !selectedSizes.isEmpty
        return hasImages && hasSizes
    }

    var hasUnsavedChanges: Bool {
        !markdownText.isEmpty || !screenshots.isEmpty || !screenPlan.screens.isEmpty
    }

    /// App name for export filenames — falls back to descriptor.name if screenPlan.appName is empty.
    var exportAppName: String {
        let name = screenPlan.appName.isEmpty ? descriptor.name : screenPlan.appName
        return name.isEmpty ? "AppShots" : name
    }

    // MARK: - Services

    private let parser = MarkdownParser()
    private let llmService: LLMService
    private let planGenerator: PlanGenerator
    private let promptTranslator: PromptTranslator
    private let backgroundGenerator: BackgroundGenerator
    private let compositor = Compositor()
    private let exporter = Exporter()

    // MARK: - Generation Task

    private var generationTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?

    // MARK: - Settings (persisted)

    @AppStorage("llm_base_url") var llmBaseURL = ""
    @AppStorage("llm_api_key") var llmAPIKey = ""
    @AppStorage("llm_model") var llmModel = ""
    @AppStorage("gemini_base_url") var geminiBaseURL = ""
    @AppStorage("gemini_api_key") var geminiAPIKey = ""
    @AppStorage("gemini_model") var geminiModel = ""
    @AppStorage("last_markdown") var lastMarkdown = ""

    init() {
        let llm = LLMService()
        self.llmService = llm
        self.planGenerator = PlanGenerator(llmService: llm)
        self.promptTranslator = PromptTranslator()
        self.backgroundGenerator = BackgroundGenerator()
    }

    // MARK: - Update service configs from @AppStorage

    func syncServiceConfigs() async {
        let trimmedLLMURL = llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGeminiURL = geminiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        let llmConfig = LLMService.Configuration(
            baseURL: trimmedLLMURL,
            apiKey: llmAPIKey,
            model: llmModel
        )
        await llmService.updateConfig(llmConfig)

        let geminiConfig = BackgroundGenerator.Configuration(
            baseURL: trimmedGeminiURL,
            apiKey: geminiAPIKey,
            model: geminiModel
        )
        await backgroundGenerator.updateConfig(geminiConfig)
    }

    // MARK: - Progress Persistence

    /// Saves the current markdown text to AppStorage so it persists across app launches.
    func saveProgress() {
        lastMarkdown = markdownText
    }

    /// Restores the last markdown text from AppStorage if the current text is empty.
    func restoreProgress() {
        if markdownText.isEmpty && !lastMarkdown.isEmpty {
            markdownText = lastMarkdown
        }
    }

    // MARK: - Smart Defaults

    /// Applies sensible defaults after parsing Markdown when fields are missing.
    func applySmartDefaults() {
        var applied: [String] = []

        // Default dark theme if no colors specified
        if descriptor.colors.primary.isEmpty && descriptor.colors.accent.isEmpty {
            descriptor.colors = ColorPalette(primary: "#0a0a0a", accent: "#3b82f6")
            applied.append("colors (dark theme: primary=#0a0a0a, accent=#3b82f6)")
        } else if descriptor.colors.primary.isEmpty {
            descriptor.colors.primary = "#0a0a0a"
            applied.append("primary color (#0a0a0a)")
        } else if descriptor.colors.accent.isEmpty {
            descriptor.colors.accent = "#3b82f6"
            applied.append("accent color (#3b82f6)")
        }

        // Default style to .minimal if not explicitly set (name is empty or matches default)
        // Since the parser defaults to .minimal already, we only log if the descriptor has no style hint
        if descriptor.style == .minimal && descriptor.name.isEmpty == false {
            // Style was either explicitly minimal or defaulted — no action needed
        }

        if !applied.isEmpty {
            print("[SmartDefaults] Applied defaults: \(applied.joined(separator: ", "))")
        } else {
            print("[SmartDefaults] No defaults needed — all fields populated")
        }
    }

    // MARK: - API Config Validation

    /// Returns true if both LLM and Gemini API settings are fully configured.
    var hasValidAPIConfig: Bool {
        !llmBaseURL.isEmpty && !llmAPIKey.isEmpty &&
        !geminiBaseURL.isEmpty && !geminiAPIKey.isEmpty
    }

    /// Returns a human-readable message about what API configuration is missing, or nil if all configured.
    var missingConfigMessage: String? {
        var missing: [String] = []

        if llmBaseURL.isEmpty { missing.append("LLM Base URL") }
        if llmAPIKey.isEmpty { missing.append("LLM API Key") }
        if geminiBaseURL.isEmpty { missing.append("Gemini Base URL") }
        if geminiAPIKey.isEmpty { missing.append("Gemini API Key") }

        guard !missing.isEmpty else { return nil }
        return "Missing configuration: \(missing.joined(separator: ", ")). Open Settings (Cmd+,) to configure."
    }

    // MARK: - Step 1: Parse Markdown

    func parseMarkdown() {
        do {
            descriptor = try parser.parse(markdownText)
            applySmartDefaults()
            errorMessage = nil
            saveProgress()
            currentStep = .screenshots
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - Step 2: Screenshots are managed by the view (drag & drop)

    func proceedToPlanning() {
        guard !screenshots.isEmpty else {
            showError("Please add at least one screenshot.")
            return
        }

        guard !descriptor.name.isEmpty else {
            showError("Your app description needs at least an app name. Please go back and check your Markdown.")
            return
        }

        currentStep = .planPreview
        generatePlan()
    }

    // MARK: - Step 3: Generate Plan (LLM Call #1)

    func generatePlan() {
        Task {
            isLoading = true
            loadingMessage = "Generating screenshot plan..."
            await syncServiceConfigs()

            do {
                let screenshotData = screenshots.map(\.imageData)
                screenPlan = try await planGenerator.generate(
                    descriptor: descriptor,
                    screenshotData: screenshotData,
                    includeIPad: generateIPad
                )
                isLoading = false
            } catch {
                isLoading = false
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Step 4: Generate Screenshots (Gemini x N)

    func startGeneration() {
        currentStep = .generating
        retryCount = 0
        generationTask = Task { await performGeneration() }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        isLoading = false
        loadingMessage = "Generation cancelled."
    }

    /// Internal generation logic, supports automatic retry on total failure
    private func performGeneration() async {
        isLoading = true
        loadingMessage = "Building image prompts..."
        await syncServiceConfigs()

        do {
            // Step A: Build prompts from plan data (no LLM call)
            imagePrompts = promptTranslator.translate(plan: screenPlan)

            // Build iPad prompts if iPad generation is enabled
            var iPadPrompts: [ImagePrompt] = []
            if generateIPad {
                iPadPrompts = promptTranslator.translateIPad(plan: screenPlan)
            }

            // Step B: Build screenshot data map (screenIndex -> screenshot data)
            var screenshotDataMap: [Int: Data] = [:]
            for screen in screenPlan.screens {
                if screen.screenshotMatch >= 0 && screen.screenshotMatch < screenshots.count {
                    let ssData = screenshots[screen.screenshotMatch].imageData
                    screenshotDataMap[screen.index] = ssData
                    // iPad prompts use offset indices (index + 1000)
                    if generateIPad {
                        screenshotDataMap[screen.index + 1000] = ssData
                    }
                }
            }

            // Step C: Generate all compositions in parallel (iPhone + iPad simultaneously)
            let allPrompts = imagePrompts + iPadPrompts
            let total = Double(allPrompts.count)
            let iPhoneCount = imagePrompts.count
            let iPadCount = iPadPrompts.count

            if generateIPad {
                loadingMessage = "Generating \(iPhoneCount) iPhone + \(iPadCount) iPad screenshots..."
            } else {
                loadingMessage = "Generating screenshots..."
            }
            generationProgress = 0

            // Generate all images. The onProgress callback routes results incrementally,
            // so even if the TaskGroup throws (one image fails), we keep partial results.
            var generationError: Error?
            do {
                let allResults = try await backgroundGenerator.generateAll(
                    prompts: allPrompts,
                    screenshotDataMap: screenshotDataMap
                ) { [weak self] index, data in
                    Task { @MainActor in
                        if index >= 1000 {
                            self?.iPadBackgroundImages[index - 1000] = data
                        } else {
                            self?.backgroundImages[index] = data
                        }

                        let completed = (self?.backgroundImages.count ?? 0) + (self?.iPadBackgroundImages.count ?? 0)
                        self?.generationProgress = Double(completed) / total
                        self?.loadingMessage = "Generated \(completed)/\(Int(total)) screenshots"
                    }
                }

                // Route final results
                for (index, data) in allResults {
                    if index >= 1000 {
                        iPadBackgroundImages[index - 1000] = data
                    } else {
                        backgroundImages[index] = data
                    }
                }
            } catch {
                generationError = error
            }

            // Step D: Build composed images from whatever we got (partial or full)
            composedImages = screenPlan.screens.sorted(by: { $0.index < $1.index }).compactMap { screen in
                guard let data = backgroundImages[screen.index] else { return nil }
                return NSImage(data: data)
            }

            if generateIPad {
                iPadComposedImages = screenPlan.screens.sorted(by: { $0.index < $1.index }).compactMap { screen in
                    guard let data = iPadBackgroundImages[screen.index] else { return nil }
                    return NSImage(data: data)
                }
            }

            isLoading = false

            // Auto-advance to export with a short delay for smoother transition
            if !backgroundImages.isEmpty {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    if !self.backgroundImages.isEmpty && self.currentStep == .generating {
                        self.currentStep = .export
                    }
                }
            }

            // Report error for failed images, with auto-retry for total failure
            if let error = generationError {
                let successCount = backgroundImages.count + iPadBackgroundImages.count
                if successCount > 0 {
                    showError("Some images failed to generate (\(successCount)/\(Int(total)) succeeded): \(error.localizedDescription)")
                } else {
                    // Total failure: auto-retry once with delay
                    if retryCount < 1 {
                        retryCount += 1
                        loadingMessage = "All images failed. Retrying in 2 seconds (attempt \(retryCount + 1))..."
                        isLoading = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await performGeneration()
                        return
                    } else {
                        showError(error.localizedDescription)
                    }
                }
            }
        } catch {
            isLoading = false
            showError(error.localizedDescription)
        }
    }

    // MARK: - Reset Generation

    /// Clears all generation artifacts for a clean restart
    func resetGeneration() {
        backgroundImages = [:]
        iPadBackgroundImages = [:]
        composedImages = []
        iPadComposedImages = []
        generationProgress = 0
        retryCount = 0
    }

    // MARK: - Step 5: Compose (Core Graphics, no LLM)

    func composeAll(deviceType: DeviceType = .iPhone) {
        Task {
            isLoading = true
            loadingMessage = "Compositing \(deviceType.displayName) screenshots..."

            let targetSize = deviceType.defaultSize
            let bgImages = deviceType == .iPad ? iPadBackgroundImages : backgroundImages
            var results: [NSImage] = []

            for screen in screenPlan.screens {
                guard screen.screenshotMatch < screenshots.count else { continue }

                let screenshot = screenshots[screen.screenshotMatch].nsImage

                do {
                    let composed: NSImage
                    if let bgData = bgImages[screen.index],
                       let bgImage = NSImage(data: bgData) {
                        composed = try compositor.compose(input: .init(
                            config: screen,
                            screenshot: screenshot,
                            backgroundImage: bgImage,
                            colors: screenPlan.colors,
                            targetSize: targetSize
                        ))
                    } else {
                        composed = try compositor.composeWithGradient(
                            config: screen,
                            screenshot: screenshot,
                            colors: screenPlan.colors,
                            targetSize: targetSize
                        )
                    }
                    results.append(composed)
                } catch {
                    showError("Failed to compose screen \(screen.index): \(error.localizedDescription)")
                }
            }

            if deviceType == .iPad {
                iPadComposedImages = results
            } else {
                composedImages = results
            }

            isLoading = false
            if !results.isEmpty {
                currentStep = .export
            }
        }
    }

    // MARK: - Step 6: Export

    func exportAll(to directory: URL) {
        Task {
            isLoading = true
            loadingMessage = "Exporting..."

            do {
                let allSelectedSizes = DeviceSize.allSizes.filter { selectedSizes.contains($0.id) }
                let iPhoneSizes = allSelectedSizes.filter { $0.deviceType == .iPhone }
                // Exclude landscape iPad sizes — compositor always renders portrait canvas
                let iPadSizes = allSelectedSizes.filter { $0.deviceType == .iPad && $0.id != "ipad_13_landscape" }

                var allResults: [Exporter.ExportResult] = []

                // Export iPhone images to iPhone sizes
                if !iPhoneSizes.isEmpty && !composedImages.isEmpty {
                    let iPhoneConfig = ExportConfig(
                        sizes: iPhoneSizes,
                        format: exportConfig.format,
                        jpegQuality: exportConfig.jpegQuality
                    )
                    let headings = screenPlan.screens.sorted(by: { $0.index < $1.index }).map { $0.heading as String? }
                    let iPhoneResults = try exporter.exportAll(
                        images: composedImages,
                        appName: exportAppName,
                        config: iPhoneConfig,
                        outputDirectory: directory,
                        screenHeadings: headings
                    ) { completed, total in
                        Task { @MainActor in
                            self.loadingMessage = "Exporting iPhone \(completed)/\(total)"
                        }
                    }
                    allResults.append(contentsOf: iPhoneResults)
                }

                // Export iPad images to iPad sizes
                if !iPadSizes.isEmpty && !iPadComposedImages.isEmpty {
                    let iPadConfig = ExportConfig(
                        sizes: iPadSizes,
                        format: exportConfig.format,
                        jpegQuality: exportConfig.jpegQuality
                    )
                    let iPadHeadings = screenPlan.screens.sorted(by: { $0.index < $1.index }).map { $0.heading as String? }
                    let iPadResults = try exporter.exportAll(
                        images: iPadComposedImages,
                        appName: exportAppName,
                        config: iPadConfig,
                        outputDirectory: directory,
                        screenHeadings: iPadHeadings
                    ) { completed, total in
                        Task { @MainActor in
                            self.loadingMessage = "Exporting iPad \(completed)/\(total)"
                        }
                    }
                    allResults.append(contentsOf: iPadResults)
                }

                // Warn if iPad sizes selected but no iPad images
                if !iPadSizes.isEmpty && iPadComposedImages.isEmpty {
                    showError("iPad sizes selected but no iPad images generated. Only iPhone images were exported.")
                }

                exportResults = allResults
                isLoading = false
            } catch {
                isLoading = false
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Recompose Single Screen

    func recomposeSingle(screenIndex: Int, deviceType: DeviceType = .iPhone) {
        guard screenIndex < screenPlan.screens.count else { return }
        let screen = screenPlan.screens[screenIndex]
        guard screen.screenshotMatch < screenshots.count else { return }

        let screenshot = screenshots[screen.screenshotMatch].nsImage
        let targetSize = deviceType.defaultSize
        let bgImages = deviceType == .iPad ? iPadBackgroundImages : backgroundImages

        do {
            let composed: NSImage
            if let bgData = bgImages[screen.index],
               let bgImage = NSImage(data: bgData) {
                composed = try compositor.compose(input: .init(
                    config: screen,
                    screenshot: screenshot,
                    backgroundImage: bgImage,
                    colors: screenPlan.colors,
                    targetSize: targetSize
                ))
            } else {
                composed = try compositor.composeWithGradient(
                    config: screen,
                    screenshot: screenshot,
                    colors: screenPlan.colors,
                    targetSize: targetSize
                )
            }

            if deviceType == .iPad {
                if screenIndex < iPadComposedImages.count {
                    iPadComposedImages[screenIndex] = composed
                }
            } else {
                if screenIndex < composedImages.count {
                    composedImages[screenIndex] = composed
                }
            }
        } catch {
            showError("Recompose failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Regenerate single screenshot

    func regenerateBackground(screenIndex: Int) {
        guard screenIndex < screenPlan.screens.count else { return }
        let screen = screenPlan.screens[screenIndex]
        guard screen.index < imagePrompts.count else { return }
        let prompt = imagePrompts.first { $0.screenIndex == screen.index }
            ?? imagePrompts[min(screenIndex, imagePrompts.count - 1)]

        // Get screenshot data for multimodal generation
        let screenshotData: Data? = screen.screenshotMatch < screenshots.count
            ? screenshots[screen.screenshotMatch].imageData
            : nil

        Task {
            loadingMessage = "Regenerating screenshot \(screenIndex)..."
            await syncServiceConfigs()

            do {
                let data = try await backgroundGenerator.generateSingle(prompt: prompt, screenshotData: screenshotData)
                backgroundImages[screen.index] = data
                // Recompose through the Compositor so the new background is properly
                // layered with the device frame, screenshot, and text overlays.
                recomposeSingle(screenIndex: screenIndex)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Navigation

    func goToStep(_ step: Step) {
        guard step.rawValue <= currentStep.rawValue || canAdvanceToStep(step) else { return }
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        currentStep = step
        saveProgress()
    }

    private func canAdvanceToStep(_ step: Step) -> Bool {
        for i in currentStep.rawValue..<step.rawValue {
            guard let s = Step(rawValue: i) else { return false }
            if !canAdvance(from: s) { return false }
        }
        return true
    }

    func resetToStep(_ step: Step) {
        // Cancel any in-flight generation
        generationTask?.cancel()
        generationTask = nil
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        isLoading = false

        currentStep = step
        switch step {
        case .markdown:
            descriptor = .empty
            screenshots.removeAll()
            screenPlan = .empty
            imagePrompts.removeAll()
            backgroundImages.removeAll()
            iPadBackgroundImages.removeAll()
            composedImages.removeAll()
            iPadComposedImages.removeAll()
            exportResults.removeAll()
            generationProgress = 0
        case .screenshots:
            screenPlan = .empty
            imagePrompts.removeAll()
            backgroundImages.removeAll()
            iPadBackgroundImages.removeAll()
            composedImages.removeAll()
            iPadComposedImages.removeAll()
            exportResults.removeAll()
            generationProgress = 0
        case .planPreview:
            imagePrompts.removeAll()
            backgroundImages.removeAll()
            iPadBackgroundImages.removeAll()
            composedImages.removeAll()
            iPadComposedImages.removeAll()
            exportResults.removeAll()
            generationProgress = 0
        case .generating:
            composedImages.removeAll()
            iPadComposedImages.removeAll()
            exportResults.removeAll()
        case .composing:
            exportResults.removeAll()
        case .export:
            exportResults.removeAll()
        }
        saveProgress()
    }

    func canAdvance(from step: Step) -> Bool {
        switch step {
        case .markdown:
            return !markdownText.isEmpty && descriptor.name.count > 0
        case .screenshots:
            return !screenshots.isEmpty
        case .planPreview:
            return !screenPlan.screens.isEmpty && !isLoading
        case .generating:
            return !backgroundImages.isEmpty && !isLoading
        case .composing:
            return !composedImages.isEmpty
        case .export:
            return true
        }
    }

    /// Returns a brief summary of completed work for a given step, or nil if nothing done yet.
    func stepSummary(for step: Step) -> String? {
        switch step {
        case .markdown:
            return descriptor.name.isEmpty ? nil : descriptor.name
        case .screenshots:
            return screenshots.isEmpty ? nil : "\(screenshots.count) screenshots"
        case .planPreview:
            return screenPlan.screens.isEmpty ? nil : "\(screenPlan.screens.count) screens planned"
        case .generating:
            return backgroundImages.isEmpty ? nil : "\(backgroundImages.count) generated"
        case .composing:
            return composedImages.isEmpty ? nil : "\(composedImages.count) composed"
        case .export:
            return exportResults.isEmpty ? nil : "\(exportResults.count) exported"
        }
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func showErrorWithMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }
}

// MARK: - Screenshot Item

struct ScreenshotItem: Identifiable, Equatable {
    let id: UUID
    let imageData: Data
    let fileName: String
    let nsImage: NSImage

    init(id: UUID = UUID(), imageData: Data, fileName: String = "screenshot.png") {
        self.id = id
        self.imageData = imageData
        self.fileName = fileName
        self.nsImage = NSImage(data: imageData) ?? NSImage()
    }

    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.id == rhs.id
    }
}
