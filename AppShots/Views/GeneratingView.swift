import SwiftUI
import Combine

/// Step 4: Background generation progress view.
/// Shows progress as Gemini generates backgrounds in parallel.
struct GeneratingView: View {
    @EnvironmentObject var appState: AppState
    @State private var elapsedSeconds: Int = 0
    @State private var timerCancellable: AnyCancellable?
    @State private var currentTipIndex: Int = 0
    @State private var tipTimerCancellable: AnyCancellable?

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
        .onAppear {
            startTimers()
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: appState.isLoading) { _, isLoading in
            if !isLoading {
                stopTimers()
            }
        }
    }

    private func startTimers() {
        elapsedSeconds = 0
        currentTipIndex = 0

        // Elapsed time timer (every 1 second)
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if appState.isLoading {
                    elapsedSeconds += 1
                }
            }

        // Tip rotation timer (every 5 seconds)
        tipTimerCancellable = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentTipIndex = (currentTipIndex + 1) % tips.count
                }
            }
    }

    private func stopTimers() {
        timerCancellable?.cancel()
        timerCancellable = nil
        tipTimerCancellable?.cancel()
        tipTimerCancellable = nil
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

                    VStack(spacing: 2) {
                        Text("\(Int(appState.generationProgress * 100))%")
                            .font(.title2.bold().monospacedDigit())
                        Text("complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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
        let screenshotItem: ScreenshotItem? = screen.screenshotMatch < appState.screenshots.count ? appState.screenshots[screen.screenshotMatch] : nil

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
                        #if canImport(AppKit)
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
                        #else
                        ProgressView()
                        #endif
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
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Back to Plan") {
                appState.goToStep(.planPreview)
            }
            .buttonStyle(.bordered)

            Spacer()

            // Allow advancing when generation is done or has partial results
            if !appState.isLoading && !appState.backgroundImages.isEmpty {
                Button(appState.generationProgress >= 1.0 ? "Continue to Export" : "Continue with \(appState.backgroundImages.count) screenshots") {
                    // Skip composing step — Gemini output is used directly as final images
                    appState.currentStep = .export
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
