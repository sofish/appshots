import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Step 6: Export view.
/// Allows users to select sizes, format, and export location.
/// Supports batch export for multiple device sizes.
struct ExportView: View {
    @EnvironmentObject var appState: AppState
    @State private var isExporting = false
    @State private var exportComplete = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            exportOptions
            Divider()
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export")
                    .font(.title2.bold())
                Text("Configure export settings and save your App Store screenshots.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Export Options

    private var exportOptions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Preview strip
                previewStrip

                // Size selection
                sizeSelection

                // Format selection
                formatSelection

                // Export results (if any)
                if !appState.exportResults.isEmpty {
                    exportResults
                }

                // Loading
                if appState.isLoading {
                    exportProgress
                }
            }
            .padding()
        }
    }

    // MARK: - Preview Strip

    private var previewStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screenshots to Export")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    #if canImport(AppKit)
                    ForEach(Array(appState.composedImages.enumerated()), id: \.offset) { index, image in
                        VStack(spacing: 4) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)

                            HStack(spacing: 2) {
                                Image(systemName: "iphone")
                                    .font(.caption2)
                                Text("Screen \(index + 1)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // iPad images
                    if appState.generateIPad {
                        ForEach(Array(appState.iPadComposedImages.enumerated()), id: \.offset) { index, image in
                            VStack(spacing: 4) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)

                                HStack(spacing: 2) {
                                    Image(systemName: "ipad")
                                        .font(.caption2)
                                    Text("Screen \(index + 1)")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    #endif
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Size Selection

    private var sizeSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Device Sizes")
                .font(.headline)

            Text("Select which sizes to export. Required sizes are recommended for App Store submission.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(DeviceSize.allSizes, id: \.id) { size in
                    let isSelected = appState.selectedSizes.contains(size.id)

                    HStack {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .onTapGesture {
                                if isSelected {
                                    appState.selectedSizes.remove(size.id)
                                } else {
                                    appState.selectedSizes.insert(size.id)
                                }
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(size.displayName)
                                    .font(.callout.bold())
                                if size.isRequired {
                                    Text("Required")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(.orange.opacity(0.2)))
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text(size.pixelSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        #if canImport(AppKit)
                        let fileCount = size.deviceType == .iPad
                            ? appState.iPadComposedImages.count
                            : appState.composedImages.count
                        if fileCount > 0 {
                            Text("\(fileCount) files")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if size.deviceType == .iPad && isSelected {
                            Text("No iPad images")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        #endif
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.accentColor.opacity(0.05) : .clear)
                    )
                }
            }
        }
    }

    // MARK: - Format Selection

    private var formatSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export Format")
                .font(.headline)

            HStack(spacing: 16) {
                ForEach(ExportFormat.allCases) { format in
                    let isSelected = appState.exportConfig.format == format

                    Button {
                        appState.exportConfig.format = format
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: format == .png ? "doc.zipper" : "photo")
                                .font(.title3)
                            Text(format.rawValue)
                                .font(.callout.bold())
                            Text(format == .png ? "Best quality" : "Smaller files")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.1) : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                if appState.exportConfig.format == .jpeg {
                    VStack(alignment: .leading) {
                        Text("Quality: \(Int(appState.exportConfig.jpegQuality * 100))%")
                            .font(.caption)
                        Slider(value: $appState.exportConfig.jpegQuality, in: 0.5...1.0, step: 0.05)
                            .frame(width: 150)
                    }
                }
            }

            // File count estimate
            #if canImport(AppKit)
            let iPhoneSizeCount = DeviceSize.allSizes.filter { $0.deviceType == .iPhone && appState.selectedSizes.contains($0.id) }.count
            let iPadSizeCount = DeviceSize.allSizes.filter { $0.deviceType == .iPad && appState.selectedSizes.contains($0.id) }.count
            let iPhoneFiles = appState.composedImages.count * iPhoneSizeCount
            let iPadFiles = appState.iPadComposedImages.count * iPadSizeCount
            let totalFiles = iPhoneFiles + iPadFiles
            if iPadFiles > 0 {
                Text("Total: \(totalFiles) files (\(iPhoneFiles) iPhone + \(iPadFiles) iPad)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Total: \(totalFiles) files will be exported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
    }

    // MARK: - Export Progress

    private var exportProgress: some View {
        VStack(spacing: 12) {
            ProgressView(value: appState.generationProgress)
                .progressViewStyle(.linear)
            Text(appState.loadingMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
    }

    // MARK: - Export Results

    private var exportResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Export Complete")
                    .font(.headline)
            }

            ForEach(appState.exportResults, id: \.fileName) { result in
                HStack {
                    Text(result.fileName)
                        .font(.caption.monospaced())
                    Spacer()
                    Text(formatFileSize(result.fileSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Warning if too large
                    if Double(result.fileSize) / (1024 * 1024) > 10 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Exceeds App Store 10MB limit")
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.05)))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Back to Preview") {
                appState.goToStep(.composing)
            }
            .buttonStyle(.bordered)

            Spacer()

            #if canImport(AppKit)
            if !appState.exportResults.isEmpty {
                Button("Show in Finder") {
                    if let first = appState.exportResults.first {
                        NSWorkspace.shared.activateFileViewerSelecting([first.filePath])
                    }
                }
                .buttonStyle(.bordered)
            }
            #endif

            Button("Export All") {
                startExport()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.selectedSizes.isEmpty || appState.isLoading)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    // MARK: - Actions

    private func startExport() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to save your App Store screenshots."

        if panel.runModal() == .OK, let url = panel.url {
            appState.exportAll(to: url)
        }
        #endif
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.0f KB", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}
