import SwiftUI

/// Step 4: Background generation progress view.
/// Shows progress as Gemini generates backgrounds in parallel.
struct GeneratingView: View {
    @Environment(AppState.self) var appState
    @State private var elapsedSeconds: Int = 0
    @State private var currentTipIndex: Int = 0
    @State private var progressStallSeconds: Int = 0
    @State private var lastProgress: Double = 0

    private let tips: [String] = [
        "Generation usually takes 10-30 seconds per screenshot",
        "Each screenshot is generated in parallel for speed",
        "You can edit headings and regenerate individual screens later",
        "Pro tip: The hero screenshot gets 10x more views than others"
    ]

    private var elapsedFormatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var estimatedRemaining: String? {
        let progress = appState.generationProgress
        guard progress > 0.05 && progress < 1.0 && elapsedSeconds > 2 else { return nil }
        let totalEstimate = Double(elapsedSeconds) / progress
        let remaining = Int(totalEstimate * (1.0 - progress))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "~%d:%02d remaining", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            progressContent
                .padding(.horizontal, 20)
            Divider()
            footer
        }
        .task(id: appState.isLoading) {
            guard appState.isLoading else { return }
            elapsedSeconds = 0
            currentTipIndex = 0
            progressStallSeconds = 0
            lastProgress = appState.generationProgress
            while !Task.isCancelled && appState.isLoading {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                elapsedSeconds += 1
                // Track how long progress has been stalled
                let currentProgress = appState.generationProgress
                if abs(currentProgress - lastProgress) < 0.001 {
                    progressStallSeconds += 1
                } else {
                    progressStallSeconds = 0
                    lastProgress = currentProgress
                }
                if elapsedSeconds % 5 == 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentTipIndex = (currentTipIndex + 1) % tips.count
                    }
                }
            }
        }
    }

    // MARK: - Progress Content

    private var progressContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // Main progress indicator
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: appState.generationProgress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: appState.generationProgress)
                        .opacity(progressStallSeconds > 3 ? 0.6 : 1.0)
                        .animation(
                            progressStallSeconds > 3
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: progressStallSeconds > 3
                        )

                    VStack(spacing: 2) {
                        Text("\(Int(appState.generationProgress * 100))%")
                            .font(.title2.bold().monospacedDigit())
                        Text("complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("Generation progress: \(Int(appState.generationProgress * 100)) percent")

                Text(appState.loadingMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Elapsed time and estimated remaining
                HStack(spacing: 16) {
                    Label("Elapsed: \(elapsedFormatted)", systemImage: "clock")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if let remaining = estimatedRemaining {
                        Text(remaining)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }

                if appState.generateIPad {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "iphone")
                            Text("\(appState.backgroundImages.count)/\(appState.screenPlan.screens.count)")
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "ipad")
                            Text("\(appState.iPadBackgroundImages.count)/\(appState.screenPlan.screens.count)")
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // Rotating tips
                if appState.isLoading {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(tips[currentTipIndex])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .id(currentTipIndex)
                            .transition(.opacity)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
                }
            }

            // Per-screen progress
            if !appState.screenPlan.screens.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)
                ], spacing: 12) {
                    ForEach(appState.screenPlan.screens) { screen in
                        screenProgressCard(screen)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    private func screenProgressCard(_ screen: ScreenConfig) -> some View {
        let iPhoneComplete = appState.backgroundImages[screen.index] != nil
        let iPadComplete = appState.iPadBackgroundImages[screen.index] != nil
        let allComplete = iPhoneComplete && (!appState.generateIPad || iPadComplete)
        let screenshotItem: ScreenshotItem? = screen.screenshotMatch >= 0 && screen.screenshotMatch < appState.screenshots.count ? appState.screenshots[screen.screenshotMatch] : nil

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(allComplete ? Color.green.opacity(0.1) : Color.gray.opacity(0.15))
                    .frame(height: 70)

                if allComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else if appState.isLoading {
                    VStack(spacing: 4) {
                        // Show miniature screenshot thumbnail
                        if let item = screenshotItem {
                            Image(nsImage: item.nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .opacity(0.5)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                )
                        } else {
                            ProgressView()
                        }
                        if appState.generateIPad {
                            HStack(spacing: 4) {
                                Image(systemName: "iphone")
                                    .font(.caption2)
                                    .foregroundStyle(iPhoneComplete ? .green : .secondary)
                                Image(systemName: "ipad")
                                    .font(.caption2)
                                    .foregroundStyle(iPadComplete ? .green : .secondary)
                            }
                        }
                    }
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                }
            }

            Text("Screen \(screen.index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Screen \(screen.index + 1): \(allComplete ? "Complete" : "In progress")")
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Back to Plan") {
                appState.goToStep(.planPreview)
            }
            .buttonStyle(.bordered)

            Spacer()

            if appState.isLoading {
                Button("Cancel Generation") {
                    appState.cancelGeneration()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .help("Stop generating screenshots")
            }

            // Allow advancing when generation is done or has partial results
            if !appState.isLoading && !appState.backgroundImages.isEmpty {
                Button(appState.generationProgress >= 1.0 ? "Continue to Export" : "Continue with \(appState.backgroundImages.count) screenshots") {
                    appState.goToStep(.export)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
