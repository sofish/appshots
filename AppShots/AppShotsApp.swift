import SwiftUI
import AppKit

@main
struct AppShotsApp: App {
    @State private var appState = AppState()
    @State private var showGettingStarted = false
    @AppStorage("hasSeenGettingStarted") private var hasSeenGettingStarted = false

    /// Whether the user can jump to a given step (must have completed all prior steps).
    private func canJumpToStep(_ step: AppState.Step) -> Bool {
        // Always allow jumping to current or earlier steps
        if step.rawValue <= appState.currentStep.rawValue { return true }
        // For forward jumps, check that all intermediate steps can advance
        for i in appState.currentStep.rawValue..<step.rawValue {
            guard let s = AppState.Step(rawValue: i) else { return false }
            if !appState.canAdvance(from: s) { return false }
        }
        return true
    }

    var body: some Scene {
        WindowGroup("AppShots") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 960, minHeight: 640)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }
                    appState.restoreProgress()
                    if !hasSeenGettingStarted {
                        showGettingStarted = true
                        hasSeenGettingStarted = true
                    }
                }
                .sheet(isPresented: $showGettingStarted) {
                    GettingStartedSheet(isPresented: $showGettingStarted)
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .sidebar) {
                Button("Previous Step") {
                    let current = appState.currentStep.rawValue
                    if current > 0, let prev = AppState.Step(rawValue: current - 1) {
                        appState.goToStep(prev)
                    }
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Next Step") {
                    let current = appState.currentStep.rawValue
                    if let next = AppState.Step(rawValue: current + 1) {
                        appState.goToStep(next)
                    }
                }
                .keyboardShortcut("]", modifiers: .command)

                Divider()

                // Jump to specific steps (Cmd+1 through Cmd+6)
                ForEach(AppState.Step.allCases) { step in
                    Button("Go to \(step.title)") {
                        appState.goToStep(step)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(step.rawValue + 1)")), modifiers: .command)
                    .disabled(!canJumpToStep(step))
                }
            }

            CommandGroup(replacing: .help) {
                Button("Getting Started") {
                    showGettingStarted = true
                }
                .keyboardShortcut("?", modifiers: .command)
            }

            CommandMenu("Actions") {
                Button("Regenerate Plan") {
                    if appState.currentStep == .planPreview {
                        appState.generatePlan()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.currentStep != .planPreview || appState.isLoading)

                Button("Generate Screenshots") {
                    if appState.currentStep == .planPreview && !appState.screenPlan.screens.isEmpty {
                        appState.startGeneration()
                    }
                }
                .keyboardShortcut("g", modifiers: .command)
                .disabled(appState.currentStep != .planPreview || appState.screenPlan.screens.isEmpty || appState.isLoading)

                Button("Export") {
                    if appState.currentStep == .export {
                        appState.goToStep(.export)
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.currentStep != .export)

                Divider()

                Button("Reset Workflow") {
                    appState.goToStep(.markdown)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

// MARK: - Getting Started Sheet

struct GettingStartedSheet: View {
    @Binding var isPresented: Bool

    private let steps: [(icon: String, title: String, description: String)] = [
        ("doc.text", "Step 1: Describe Your App", "Paste or write a Markdown description of your app including its name, features, and color palette."),
        ("photo.on.rectangle", "Step 2: Upload Screenshots", "Drag and drop raw screenshots from your app. These will be placed into device frames."),
        ("rectangle.3.group", "Step 3: Review the Plan", "The AI generates a plan with headings, layouts, and visual directions. Edit anything before generating."),
        ("square.and.arrow.up", "Step 4: Generate & Export", "AI creates backgrounds, composites the final images, and exports them in App Store-ready sizes.")
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Text("\u{00d7}")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Getting Started with AppShots")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: step.icon)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, alignment: .center)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.description)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button("Get Started") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 500)
    }
}
