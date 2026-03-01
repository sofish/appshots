import SwiftUI
import AppKit

/// Step 6: Export view.
/// Allows users to select sizes, format, and export location.
/// Supports batch export for multiple device sizes.
struct ExportView: View {
    @Environment(AppState.self) private var appState
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportStartTime: Date?
    @State private var exportDuration: TimeInterval?
    @State private var showExportSuccess = false

    private var hasNoScreenshots: Bool {
        return appState.composedImages.isEmpty && appState.iPadComposedImages.isEmpty
    }

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            if showExportSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Export complete!")
                        .font(.callout.bold())
                    Spacer()
                    Button("Dismiss") {
                        withAnimation { showExportSuccess = false }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.1))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if hasNoScreenshots {
                emptyStateView
            } else {
                exportOptions
                Divider()
                footer
            }
        }
        .onChange(of: appState.isLoading) { _, isLoading in
            if !isLoading && exportStartTime != nil {
                exportDuration = Date().timeIntervalSince(exportStartTime!)
                exportStartTime = nil
                withAnimation { showExportSuccess = true }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No screenshots to export")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Go back and generate screenshots first")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Button("Back to Generate") {
                appState.goToStep(.generating)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// iPad images are always composed at portrait canvas dimensions.
    /// Landscape iPad sizes would distort the output, so we filter them out.
    private var availableSizes: [DeviceSize] {
        DeviceSize.allSizes.filter { size in
            // Exclude landscape iPad sizes — compositor always renders at portrait canvas
            if size.id == "ipad_13_landscape" { return false }
            return true
        }
    }

    /// iPhone sizes from the available list
    private var iPhoneSizes: [DeviceSize] {
        availableSizes.filter { $0.deviceType == .iPhone }
    }

    /// iPad sizes from the available list
    private var iPadSizes: [DeviceSize] {
        availableSizes.filter { $0.deviceType == .iPad }
    }

    /// Whether all iPhone sizes are currently selected
    private var allIPhoneSelected: Bool {
        iPhoneSizes.allSatisfy { appState.selectedSizes.contains($0.id) }
    }

    /// Whether all iPad sizes are currently selected
    private var allIPadSelected: Bool {
        iPadSizes.allSatisfy { appState.selectedSizes.contains($0.id) }
    }

    /// Estimated total file size based on pixel count and format overhead
    private var estimatedTotalFileSize: Int {
        let format = appState.exportConfig.format
        let bytesPerPixel: Double = format == .png ? 4.0 : 0.5

        var totalBytes: Double = 0
        let selectedDeviceSizes = availableSizes.filter { appState.selectedSizes.contains($0.id) }

        for size in selectedDeviceSizes {
            let pixelCount = Double(size.width * size.height)
            let imageCount: Int
            if size.deviceType == .iPad {
                imageCount = appState.iPadComposedImages.count
            } else {
                imageCount = appState.composedImages.count
            }
            totalBytes += pixelCount * bytesPerPixel * Double(imageCount)
        }

        return Int(totalBytes)
    }

    // MARK: - Export Options

    private var exportOptions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Preview strip
                previewStrip

                // Warning banner if no sizes selected
                if appState.selectedSizes.isEmpty {
                    noSizesWarning
                }

                // Size selection
                sizeSelection

                // Estimated file size
                if !appState.selectedSizes.isEmpty {
                    estimatedSizeRow
                }

                // Format selection
                formatSelection

                // Export summary card (after export)
                if !appState.exportResults.isEmpty {
                    exportSummaryCard
                }

                // Export results (if any)
                if !appState.exportResults.isEmpty {
                    exportResults
                }

                // Loading
                if appState.isLoading {
                    exportProgress
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical)
        }
    }

    // MARK: - No Sizes Warning

    private var noSizesWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Select at least one device size to export")
                .font(.callout)
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Estimated Size Row

    private var estimatedSizeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "externaldrive")
                .foregroundStyle(.secondary)
            Text("Estimated total size: \(formatFileSize(estimatedTotalFileSize))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("(\(appState.exportConfig.format == .png ? "PNG ~4 B/px" : "JPEG ~0.5 B/px"))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Preview Strip

    private var previewStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screenshots to Export")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(appState.composedImages.enumerated()), id: \.offset) { index, image in
                        VStack(spacing: 4) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                                .accessibilityLabel("Screenshot \(index + 1)")

                            HStack(spacing: 2) {
                                Image(systemName: "iphone")
                                    .font(.caption2)
                                Text("Screen \(index + 1)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)

                            // Variation thumbnails
                            if appState.variationCount > 1,
                               let variations = appState.backgroundVariations[index],
                               variations.count > 1 {
                                variationThumbnails(
                                    screenIndex: index,
                                    variations: variations,
                                    selectedIndex: appState.selectedVariation[index] ?? 0,
                                    deviceType: .iPhone
                                )
                            }
                        }
                    }

                    if appState.generateIPad {
                        ForEach(Array(appState.iPadComposedImages.enumerated()), id: \.offset) { index, image in
                            VStack(spacing: 4) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                                    .accessibilityLabel("iPad Screenshot \(index + 1)")

                                HStack(spacing: 2) {
                                    Image(systemName: "ipad")
                                        .font(.caption2)
                                    Text("Screen \(index + 1)")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)

                                // iPad variation thumbnails
                                if appState.variationCount > 1,
                                   let variations = appState.iPadBackgroundVariations[index],
                                   variations.count > 1 {
                                    variationThumbnails(
                                        screenIndex: index,
                                        variations: variations,
                                        selectedIndex: appState.selectedIPadVariation[index] ?? 0,
                                        deviceType: .iPad
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Variation Thumbnails

    private func variationThumbnails(
        screenIndex: Int,
        variations: [Int: Data],
        selectedIndex: Int,
        deviceType: DeviceType
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(variations.keys.sorted()), id: \.self) { varIdx in
                if let data = variations[varIdx], let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(varIdx == selectedIndex ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            appState.selectVariation(
                                screenIndex: screenIndex,
                                variationIndex: varIdx,
                                deviceType: deviceType
                            )
                        }
                        .accessibilityLabel("Variation \(varIdx + 1)")
                }
            }
        }
    }

    // MARK: - Size Selection

    private var sizeSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Device Sizes")
                    .font(.headline)

                Spacer()

                Button("Select Recommended") {
                    appState.selectedSizes = Set(DeviceSize.recommendedSizes.map(\.id))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Select which sizes to export. Required sizes are recommended for App Store submission.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                // iPhone section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundStyle(.secondary)
                        Text("iPhone")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(allIPhoneSelected ? "Deselect All iPhone" : "Select All iPhone") {
                            if allIPhoneSelected {
                                for size in iPhoneSizes {
                                    appState.selectedSizes.remove(size.id)
                                }
                            } else {
                                for size in iPhoneSizes {
                                    appState.selectedSizes.insert(size.id)
                                }
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    ForEach(iPhoneSizes, id: \.id) { size in
                        sizeRow(size: size)
                    }
                }

                Divider()

                // iPad section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "ipad")
                            .foregroundStyle(.secondary)
                        Text("iPad")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(allIPadSelected ? "Deselect All iPad" : "Select All iPad") {
                            if allIPadSelected {
                                for size in iPadSizes {
                                    appState.selectedSizes.remove(size.id)
                                }
                            } else {
                                for size in iPadSizes {
                                    appState.selectedSizes.insert(size.id)
                                }
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    ForEach(iPadSizes, id: \.id) { size in
                        sizeRow(size: size)
                    }
                }
            }
        }
    }

    /// A single device size row with checkbox, label, and file count
    private func sizeRow(size: DeviceSize) -> some View {
        let isSelected = appState.selectedSizes.contains(size.id)

        return HStack {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.05) : .clear)
        )
    }

    // MARK: - Format Selection

    @ViewBuilder
    private var formatSelection: some View {
        @Bindable var appState = appState
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
                        HStack {
                            Text("Low")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Slider(value: $appState.exportConfig.jpegQuality, in: 0.5...1.0, step: 0.05)
                                .frame(width: 150)
                            Text("High")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // File count estimate
            let iPhoneSizeCount = availableSizes.filter { $0.deviceType == .iPhone && appState.selectedSizes.contains($0.id) }.count
            let iPadSizeCount = availableSizes.filter { $0.deviceType == .iPad && appState.selectedSizes.contains($0.id) }.count
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
        }
    }

    // MARK: - Export Progress

    private var exportProgress: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.linear)
            Text(appState.loadingMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
    }

    // MARK: - Export Summary Card

    private var exportSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Complete")
                        .font(.headline)
                    if let duration = exportDuration {
                        Text("Completed in \(String(format: "%.1f", duration))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(appState.exportResults.count)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("Files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let totalSize = appState.exportResults.reduce(0) { $0 + $1.fileSize }
                VStack(spacing: 4) {
                    Text(formatFileSize(totalSize))
                        .font(.title2.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("Total Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let duration = exportDuration {
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.1f", duration))s")
                            .font(.title2.bold())
                            .foregroundStyle(Color.accentColor)
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.green.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Export Results

    private var exportResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundStyle(.secondary)
                Text("Exported Files")
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
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.15)))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Back to Preview") {
                appState.goToStep(.composing)
            }
            .buttonStyle(.bordered)

            Spacer()

            if !appState.exportResults.isEmpty {
                Button("Show in Finder") {
                    if let first = appState.exportResults.first {
                        NSWorkspace.shared.activateFileViewerSelecting([first.filePath])
                    }
                }
                .buttonStyle(.bordered)
            }

            if appState.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Exporting...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Export All") {
                startExport()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.selectedSizes.isEmpty || appState.isLoading)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Actions

    private func startExport() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to save your App Store screenshots."

        if panel.runModal() == .OK, let url = panel.url {
            exportStartTime = Date()
            exportDuration = nil
            appState.exportAll(to: url)
        }
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
