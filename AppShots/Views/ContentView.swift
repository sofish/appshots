import SwiftUI

/// Main application view with step-based navigation.
/// Uses a sidebar for step navigation and a main content area for each step.
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HSplitView {
            // Sidebar: Step navigation
            StepSidebar()
                .frame(width: 200)

            // Main content area
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") { appState.dismissError() }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred.")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.currentStep {
        case .markdown:
            MarkdownInputView()
        case .screenshots:
            ScreenshotGalleryView()
        case .planPreview:
            PlanPreviewView()
        case .generating:
            GeneratingView()
        case .composing:
            CompositePreviewView()
        case .export:
            ExportView()
        }
    }
}

// MARK: - Step Sidebar

struct StepSidebar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title
            HStack {
                Image(systemName: "camera.aperture")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("AppShots")
                    .font(.title2.bold())
            }
            .padding()

            Divider()

            // Steps
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(AppState.Step.allCases) { step in
                        StepRow(step: step, isCurrent: appState.currentStep == step)
                            .onTapGesture {
                                if step.rawValue <= appState.currentStep.rawValue {
                                    appState.goToStep(step)
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            Divider()

            // Settings button
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct StepRow: View {
    let step: AppState.Step
    let isCurrent: Bool

    @EnvironmentObject var appState: AppState

    private var isAccessible: Bool {
        step.rawValue <= appState.currentStep.rawValue
    }

    var body: some View {
        HStack(spacing: 10) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.accentColor : isAccessible ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                    .frame(width: 28, height: 28)

                if step.rawValue < appState.currentStep.rawValue {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(isCurrent ? .white : isAccessible ? .accentColor : .secondary)
                }
            }

            // Step title
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.callout)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isAccessible ? .primary : .secondary)
            }

            Spacer()

            // Step icon
            Image(systemName: step.iconName)
                .font(.caption)
                .foregroundStyle(isAccessible ? .secondary : .quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrent ? Color.accentColor.opacity(0.1) : .clear)
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .opacity(isAccessible ? 1 : 0.5)
    }
}
