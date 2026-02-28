import SwiftUI

/// Step 4: Background generation progress view.
/// Shows progress as Gemini generates backgrounds in parallel.
struct GeneratingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            progressContent
            Divider()
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generating Backgrounds")
                    .font(.title2.bold())
                Text("AI is creating custom backgrounds for each screenshot.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
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

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(allComplete ? Color.green.opacity(0.1) : Color.gray.opacity(0.15))
                    .frame(height: 60)

                if allComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else if appState.isLoading {
                    VStack(spacing: 4) {
                        ProgressView()
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
        .padding()
    }
}
