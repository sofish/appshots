import SwiftUI

/// Main application view with step-based navigation.
/// Uses NavigationSplitView for native macOS sidebar.
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") { appState.dismissError() }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(AppState.Step.allCases) { step in
                    let isLast = step.rawValue == AppState.Step.allCases.count - 1

                    StepRow(step: step, showConnector: !isLast)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if step.rawValue <= appState.currentStep.rawValue {
                                appState.goToStep(step)
                            }
                        }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .padding(.trailing, 20)
        .safeAreaInset(edge: .bottom) {
            SettingsButton()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Detail

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

// MARK: - Step Row (Vertical Stepper)

struct StepRow: View {
    let step: AppState.Step
    let showConnector: Bool
    @EnvironmentObject var appState: AppState

    private var isCompleted: Bool {
        step.rawValue < appState.currentStep.rawValue
    }

    private var isCurrent: Bool {
        step == appState.currentStep
    }

    private var isAccessible: Bool {
        step.rawValue <= appState.currentStep.rawValue
    }

    private let circleSize: CGFloat = 32
    private let connectorWidth: CGFloat = 2

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: circle + connector line
            VStack(spacing: 0) {
                // Step circle
                ZStack {
                    if isCurrent {
                        // Current: outlined ring
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2)
                            .frame(width: circleSize, height: circleSize)
                        Text("\(step.rawValue + 1)")
                            .font(.callout.bold())
                            .foregroundStyle(Color.accentColor)
                    } else if isCompleted {
                        // Completed: filled accent with checkmark
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: circleSize, height: circleSize)
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else {
                        // Future: light gray fill
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: circleSize, height: circleSize)
                        Text("\(step.rawValue + 1)")
                            .font(.callout.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: circleSize, height: circleSize)

                // Connector line
                if showConnector {
                    Rectangle()
                        .fill(isCompleted ? Color.accentColor : Color.gray.opacity(0.25))
                        .frame(width: connectorWidth)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: circleSize)

            // Right column: title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.callout)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isAccessible ? .primary : .secondary)

                Text(step.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            Spacer()
        }
        .frame(minHeight: 60)
        .opacity(isAccessible ? 1 : 0.5)
    }
}

// MARK: - Settings Button

struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            openSettings()
        } label: {
            Label("Settings", systemImage: "gear")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
