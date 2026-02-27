import SwiftUI
#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif

/// Step 2: Screenshot upload and management.
/// Supports drag & drop, paste (Cmd+V), and file picker.
/// Users can reorder screenshots and select export sizes.
struct ScreenshotGalleryView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDragOver = false
    @State private var draggingItemID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            mainContent
            Divider()
            footer
        }
        .onDrop(of: [UTType.image], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Screenshots")
                    .font(.title2.bold())
                Text("Add 3-6 app screenshots. Drag to reorder. Order matches your Markdown features.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(appState.screenshots.count) screenshot\(appState.screenshots.count == 1 ? "" : "s")")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.quaternary))
        }
        .padding()
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if appState.screenshots.isEmpty {
            dropZone
        } else {
            screenshotGrid
        }
    }

    // MARK: - Drop Zone (empty state)

    private var dropZone: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(isDragOver ? .accent : .quaternary)

            VStack(spacing: 8) {
                Text("Drop screenshots here")
                    .font(.title3.bold())
                    .foregroundStyle(isDragOver ? .primary : .secondary)

                Text("or")
                    .foregroundStyle(.tertiary)

                HStack(spacing: 16) {
                    Button("Choose Files") {
                        openFilePicker()
                    }
                    .buttonStyle(.bordered)

                    Button("Paste (⌘V)") {
                        pasteFromClipboard()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Supports PNG, JPEG. Drag from Finder or paste from Simulator.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDragOver ? Color.accentColor : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .background(RoundedRectangle(cornerRadius: 12).fill(isDragOver ? Color.accentColor.opacity(0.05) : .clear))
                .padding()
        )
        .onPasteCommand(of: [UTType.image]) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Screenshot Grid

    private var screenshotGrid: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Screenshots
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
                ], spacing: 16) {
                    ForEach(Array(appState.screenshots.enumerated()), id: \.element.id) { index, item in
                        ScreenshotCard(item: item, index: index)
                            .opacity(draggingItemID == item.id ? 0.4 : 1.0)
                            .onDrag {
                                draggingItemID = item.id
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: ScreenshotReorderDelegate(
                                item: item,
                                items: $appState.screenshots,
                                draggingItemID: $draggingItemID
                            ))
                    }

                    // Add more button
                    addMoreCard
                }

                // Size selection
                sizeSelector
            }
            .padding()
        }
    }

    private var addMoreCard: some View {
        Button {
            openFilePicker()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.title)
                Text("Add More")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(width: 160, height: 280)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Size Selector

    private var sizeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export Sizes")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(DeviceSize.allSizes, id: \.id) { size in
                    let isSelected = appState.selectedSizes.contains(size.id)
                    Button {
                        if isSelected {
                            appState.selectedSizes.remove(size.id)
                        } else {
                            appState.selectedSizes.insert(size.id)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(size.displayName)
                                .font(.callout.bold())
                            Text(size.pixelSize)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if size.isRequired {
                                Text("Required")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.3)))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Back") {
                appState.goToStep(.markdown)
            }
            .buttonStyle(.bordered)

            Spacer()

            if !appState.screenshots.isEmpty {
                Button("Clear All") {
                    appState.screenshots.removeAll()
                }
                .foregroundStyle(.red)
            }

            Button("Generate Plan") {
                appState.proceedToPlanning()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.screenshots.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    // MARK: - Actions

    private func openFilePicker() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let data = try? Data(contentsOf: url) {
                    let item = ScreenshotItem(imageData: data, fileName: url.lastPathComponent)
                    appState.screenshots.append(item)
                }
            }
        }
        #endif
    }

    private func pasteFromClipboard() {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png) {
            let item = ScreenshotItem(imageData: data, fileName: "pasted.png")
            appState.screenshots.append(item)
        } else if let data = pasteboard.data(forType: .tiff),
                  let image = NSImage(data: data),
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let png = bitmap.representation(using: .png, properties: [:]) {
            let item = ScreenshotItem(imageData: png, fileName: "pasted.png")
            appState.screenshots.append(item)
        }
        #endif
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        let item = ScreenshotItem(imageData: data, fileName: "dropped.png")
                        appState.screenshots.append(item)
                    }
                }
            }
        }
    }
}

// MARK: - Reorder Delegate

struct ScreenshotReorderDelegate: DropDelegate {
    let item: ScreenshotItem
    @Binding var items: [ScreenshotItem]
    @Binding var draggingItemID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingItemID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = draggingItemID,
              dragID != item.id,
              let fromIndex = items.firstIndex(where: { $0.id == dragID }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        withAnimation(.default) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Screenshot Card

struct ScreenshotCard: View {
    let item: ScreenshotItem
    let index: Int
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail
            #if canImport(AppKit)
            Image(nsImage: item.nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            #endif

            // Label
            HStack {
                Text("#\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // Delete button
                Button {
                    appState.screenshots.removeAll { $0.id == item.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Feature name from descriptor (if available)
            if index < appState.descriptor.features.count {
                Text(appState.descriptor.features[index].name)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
