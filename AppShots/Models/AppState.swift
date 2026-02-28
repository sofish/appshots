import Foundation
#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

/// Central state management for the AppShots pipeline.
/// Drives the UI through the 6-step workflow:
/// ① Markdown → ② Screenshots → ③ Preview Plan → ④ Generate Backgrounds → ⑤ Compose → ⑥ Export
@MainActor
final class AppState: ObservableObject {

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

    @Published var currentStep: Step = .markdown
    @Published var markdownText: String = ""
    @Published var descriptor: AppDescriptor = .empty
    @Published var screenshots: [ScreenshotItem] = []
    @Published var screenPlan: ScreenPlan = .empty
    @Published var imagePrompts: [ImagePrompt] = []
    @Published var backgroundImages: [Int: Data] = [:]
    #if canImport(AppKit)
    @Published var composedImages: [NSImage] = []
    #endif
    @Published var exportConfig: ExportConfig = .default
    @Published var selectedSizes: Set<String> = Set(DeviceSize.defaultSizes.map(\.id))

    // iPad state
    @Published var generateIPad: Bool = false
    @Published var iPadBackgroundImages: [Int: Data] = [:]
    #if canImport(AppKit)
    @Published var iPadComposedImages: [NSImage] = []
    #endif

    // UI State
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var generationProgress: Double = 0
    #if canImport(AppKit)
    @Published var exportResults: [Exporter.ExportResult] = []
    #endif

    // MARK: - Services

    private let parser = MarkdownParser()
    private let llmService: LLMService
    private let planGenerator: PlanGenerator
    private let promptTranslator: PromptTranslator
    private let backgroundGenerator: BackgroundGenerator
    #if canImport(AppKit)
    private let compositor = Compositor()
    private let exporter = Exporter()
    #endif

    // MARK: - Settings (persisted)

    @AppStorage("llm_base_url") var llmBaseURL = ""
    @AppStorage("llm_api_key") var llmAPIKey = ""
    @AppStorage("llm_model") var llmModel = ""
    @AppStorage("gemini_base_url") var geminiBaseURL = ""
    @AppStorage("gemini_api_key") var geminiAPIKey = ""
    @AppStorage("gemini_model") var geminiModel = ""

    init() {
        let llm = LLMService()
        self.llmService = llm
        self.planGenerator = PlanGenerator(llmService: llm)
        self.promptTranslator = PromptTranslator()
        self.backgroundGenerator = BackgroundGenerator()
    }

    // MARK: - Update service configs from @AppStorage

    func syncServiceConfigs() async {
        let llmConfig = LLMService.Configuration(
            baseURL: llmBaseURL,
            apiKey: llmAPIKey,
            model: llmModel
        )
        await llmService.updateConfig(llmConfig)

        let geminiConfig = BackgroundGenerator.Configuration(
            baseURL: geminiBaseURL,
            apiKey: geminiAPIKey,
            model: geminiModel
        )
        await backgroundGenerator.updateConfig(geminiConfig)
    }

    // MARK: - Step 1: Parse Markdown

    func parseMarkdown() {
        do {
            descriptor = try parser.parse(markdownText)
            errorMessage = nil
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

    // MARK: - Step 4: Generate Screenshots (Gemini × N)

    func startGeneration() {
        currentStep = .generating
        Task {
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

                // Step B: Build screenshot data map (screenIndex → screenshot data)
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
                #if canImport(AppKit)
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
                #endif

                isLoading = false

                // Show partial results even if some failed
                if !backgroundImages.isEmpty {
                    currentStep = .export
                }

                // Report error for failed images
                if let error = generationError {
                    let successCount = backgroundImages.count + iPadBackgroundImages.count
                    if successCount > 0 {
                        showError("Some images failed to generate (\(successCount)/\(Int(total)) succeeded): \(error.localizedDescription)")
                    } else {
                        showError(error.localizedDescription)
                    }
                }
            } catch {
                isLoading = false
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Step 5: Compose (Core Graphics, no LLM)

    #if canImport(AppKit)
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
                let iPadSizes = allSelectedSizes.filter { $0.deviceType == .iPad }

                var allResults: [Exporter.ExportResult] = []

                // Export iPhone images to iPhone sizes
                if !iPhoneSizes.isEmpty && !composedImages.isEmpty {
                    let iPhoneConfig = ExportConfig(
                        sizes: iPhoneSizes,
                        format: exportConfig.format,
                        jpegQuality: exportConfig.jpegQuality
                    )
                    let iPhoneResults = try exporter.exportAll(
                        images: composedImages,
                        appName: screenPlan.appName,
                        config: iPhoneConfig,
                        outputDirectory: directory
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
                    let iPadResults = try exporter.exportAll(
                        images: iPadComposedImages,
                        appName: screenPlan.appName,
                        config: iPadConfig,
                        outputDirectory: directory
                    ) { completed, total in
                        Task { @MainActor in
                            self.loadingMessage = "Exporting iPad \(completed)/\(total)"
                        }
                    }
                    allResults.append(contentsOf: iPadResults)
                }

                // Warn if iPad sizes selected but no iPad images
                if !iPadSizes.isEmpty && iPadComposedImages.isEmpty {
                    errorMessage = "iPad sizes selected but no iPad images generated. Only iPhone images were exported."
                    showError = true
                }

                exportResults = allResults
                isLoading = false
            } catch {
                isLoading = false
                showError(error.localizedDescription)
            }
        }
    }
    #endif

    // MARK: - Recompose Single Screen

    #if canImport(AppKit)
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
    #endif

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
                #if canImport(AppKit)
                if let image = NSImage(data: data), screenIndex < composedImages.count {
                    composedImages[screenIndex] = image
                }
                #endif
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Navigation

    func goToStep(_ step: Step) {
        currentStep = step
    }

    func canAdvance(from step: Step) -> Bool {
        switch step {
        case .markdown: return !descriptor.name.isEmpty
        case .screenshots: return !screenshots.isEmpty
        case .planPreview: return !screenPlan.screens.isEmpty
        case .generating: return !backgroundImages.isEmpty
        #if canImport(AppKit)
        case .composing: return !composedImages.isEmpty
        #else
        case .composing: return false
        #endif
        case .export: return true
        }
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
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

    #if canImport(AppKit)
    var nsImage: NSImage {
        NSImage(data: imageData) ?? NSImage()
    }
    #endif

    init(id: UUID = UUID(), imageData: Data, fileName: String = "screenshot.png") {
        self.id = id
        self.imageData = imageData
        self.fileName = fileName
    }

    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        lhs.id == rhs.id
    }
}
