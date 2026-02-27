import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct AppShotsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 960, minHeight: 640)
                .onAppear {
                    #if canImport(AppKit)
                    NSApp.setActivationPolicy(.regular)
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    }
                    #endif
                }
        }
        .windowStyle(.titleBar)
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
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}
