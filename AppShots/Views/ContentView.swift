import SwiftUI

/// Main application view with step-based navigation.
/// Uses NavigationSplitView for native macOS sidebar.
struct ContentView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: appState.currentStep)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSubtitle(appState.currentStep.title)
        .alert("Error", isPresented: Bindable(appState).showError) {
            Button("OK") { appState.dismissError() }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Sidebar

    /// Completion percentage: steps completed / total steps
    private var completionPercentage: Double {
        let total = Double(AppState.Step.allCases.count)
        let completed = Double(appState.currentStep.rawValue)
        return completed / total
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Mini progress bar at the top
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * completionPercentage, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: completionPercentage)
                }
            }
            .frame(height: 3)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(AppState.Step.allCases) { step in
                        let isLast = step.rawValue == AppState.Step.allCases.count - 1

                        StepRow(step: step, showConnector: !isLast)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if step.rawValue <= appState.currentStep.rawValue {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        appState.goToStep(step)
                                    }
                                }
                            }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
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
    @Environment(AppState.self) var appState
    @State private var pulseScale: CGFloat = 1.0
    @State private var isHovered = false

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

    /// Brief summary for completed steps
    private var completionSummary: String? {
        guard isCompleted else { return nil }
        switch step {
        case .markdown:
            let name = appState.descriptor.name
            return name.isEmpty ? nil : name
        case .screenshots:
            let count = appState.screenshots.count
            return count > 0 ? "\(count) screenshot\(count == 1 ? "" : "s")" : nil
        case .planPreview:
            let count = appState.screenPlan.screens.count
            return count > 0 ? "\(count) screen\(count == 1 ? "" : "s") planned" : nil
        case .generating:
            let count = appState.backgroundImages.count
            return count > 0 ? "\(count) generated" : nil
        case .composing:
            let count = appState.composedImages.count
            return count > 0 ? "\(count) composed" : nil
        case .export:
            return nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: circle + connector line
            VStack(spacing: 0) {
                // Step circle
                ZStack {
                    if isCurrent {
                        // Pulse animation ring behind the current step
                        Circle()
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                            .frame(width: circleSize, height: circleSize)
                            .scaleEffect(pulseScale)
                            .opacity(2.0 - Double(pulseScale))
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                ) {
                                    pulseScale = 1.5
                                }
                            }
                            .onDisappear {
                                pulseScale = 1.0
                            }

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

                // Connector line with gradient
                if showConnector {
                    if isCompleted {
                        // Completed connector: solid accent to accent gradient (effectively solid)
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: connectorWidth)
                        .frame(maxHeight: .infinity)
                    } else if isCurrent {
                        // Current step connector: accent fading to gray
                        LinearGradient(
                            colors: [Color.accentColor, Color.gray.opacity(0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: connectorWidth)
                        .frame(maxHeight: .infinity)
                    } else {
                        // Future connector: plain gray
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(width: connectorWidth)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .frame(width: circleSize)

            // Right column: title + subtitle + completion summary
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.callout)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isAccessible ? .primary : .secondary)

                Text(step.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Completion summary under completed steps
                if let summary = completionSummary {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 1)
                }
            }
            .padding(.top, 6)

            Spacer()

            if isHovered && isAccessible {
                Text("\u{2318}\(step.rawValue + 1)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .frame(minHeight: 60)
        .opacity(isAccessible ? 1 : 0.5)
        .accessibilityLabel("Step \(step.rawValue + 1): \(step.title), \(step.subtitle)")
        .accessibilityHint(isAccessible ? "Double tap to navigate" : "Complete previous steps first")
        .accessibilityValue(isCompleted ? "Completed" : (isCurrent ? "Current" : "Not started"))
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
