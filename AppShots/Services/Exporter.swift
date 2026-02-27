import Foundation
#if canImport(AppKit)
import AppKit
import CoreImage

/// Exports composed screenshots to files in multiple sizes and formats.
struct Exporter {

    enum ExporterError: LocalizedError {
        case noImages
        case bitmapCreationFailed
        case writeFailed(String)
        case fileTooLarge(String, Double)

        var errorDescription: String? {
            switch self {
            case .noImages: return "No images to export."
            case .bitmapCreationFailed: return "Failed to create bitmap representation."
            case .writeFailed(let path): return "Failed to write to \(path)."
            case .fileTooLarge(let name, let mb):
                return "\(name) is \(String(format: "%.1f", mb))MB — exceeds the App Store 10MB limit."
            }
        }
    }

    struct ExportResult {
        let filePath: URL
        let fileName: String
        let fileSize: Int
        let deviceSize: DeviceSize
    }

    // MARK: - Export All

    func exportAll(
        images: [NSImage],
        appName: String,
        config: ExportConfig,
        outputDirectory: URL,
        onProgress: @escaping (Int, Int) -> Void
    ) throws -> [ExportResult] {
        guard !images.isEmpty else { throw ExporterError.noImages }

        var results: [ExportResult] = []
        let total = images.count * config.sizes.count
        var completed = 0

        for (index, image) in images.enumerated() {
            for size in config.sizes {
                let resized = resize(image: image, to: size)
                var data = try encode(image: resized, format: config.format, quality: config.jpegQuality)

                let fileName = "\(sanitizeFileName(appName))_\(size.id)_\(index).\(config.format.fileExtension)"
                let filePath = outputDirectory.appendingPathComponent(fileName)

                // Compress before writing if file exceeds size limit
                let fileSizeMB = Double(data.count) / (1024 * 1024)
                if fileSizeMB > config.maxFileSizeMB && config.format == .jpeg {
                    data = try compressToFit(
                        image: resized,
                        maxMB: config.maxFileSizeMB,
                        initialQuality: config.jpegQuality
                    )
                }

                try data.write(to: filePath)

                let result = ExportResult(
                    filePath: filePath,
                    fileName: fileName,
                    fileSize: data.count,
                    deviceSize: size
                )
                results.append(result)

                completed += 1
                onProgress(completed, total)
            }
        }

        return results
    }

    // MARK: - Single Export

    func exportSingle(
        image: NSImage,
        appName: String,
        index: Int,
        size: DeviceSize,
        format: ExportFormat,
        quality: Double,
        outputDirectory: URL
    ) throws -> ExportResult {
        let resized = resize(image: image, to: size)
        let data = try encode(image: resized, format: format, quality: quality)

        let fileName = "\(sanitizeFileName(appName))_\(size.id)_\(index).\(format.fileExtension)"
        let filePath = outputDirectory.appendingPathComponent(fileName)
        try data.write(to: filePath)

        return ExportResult(
            filePath: filePath,
            fileName: fileName,
            fileSize: data.count,
            deviceSize: size
        )
    }

    // MARK: - Image Processing

    private func resize(image: NSImage, to deviceSize: DeviceSize) -> NSImage {
        let targetWidth = deviceSize.width
        let targetHeight = deviceSize.height

        // If image is already the correct pixel size, return as-is
        let imagePixelSize = image.pixelSize
        if Int(imagePixelSize.width) == targetWidth && Int(imagePixelSize.height) == targetHeight {
            return image
        }

        // Use NSBitmapImageRep directly to control exact pixel dimensions
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetWidth,
            pixelsHigh: targetHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return image
        }
        bitmapRep.size = NSSize(width: targetWidth, height: targetHeight)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        let newImage = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        newImage.addRepresentation(bitmapRep)
        return newImage
    }

    private func encode(image: NSImage, format: ExportFormat, quality: Double) throws -> Data {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ExporterError.bitmapCreationFailed
        }

        let fileType: NSBitmapImageRep.FileType
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]

        switch format {
        case .png:
            fileType = .png
        case .jpeg:
            fileType = .jpeg
            properties[.compressionFactor] = quality
        }

        guard let data = bitmap.representation(using: fileType, properties: properties) else {
            throw ExporterError.bitmapCreationFailed
        }

        return data
    }

    private func compressToFit(image: NSImage, maxMB: Double, initialQuality: Double) throws -> Data {
        let maxBytes = Int(maxMB * 1024 * 1024)
        var quality = initialQuality

        while quality > 0.1 {
            let data = try encode(image: image, format: .jpeg, quality: quality)
            if data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }

        // Last resort: lowest quality
        return try encode(image: image, format: .jpeg, quality: 0.1)
    }

    private func sanitizeFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return name
            .components(separatedBy: allowed.inverted)
            .joined(separator: "_")
            .lowercased()
    }
}

// MARK: - NSImage pixel size helper

private extension NSImage {
    var pixelSize: NSSize {
        guard let rep = representations.first else { return size }
        return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
}
#endif
