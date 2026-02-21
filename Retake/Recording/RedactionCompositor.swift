import Foundation
import AVFoundation
import CoreImage

enum RedactionCompositor {
    enum CompositorError: LocalizedError {
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .exportFailed(let detail): return "Failed to export redacted video: \(detail)"
            }
        }
    }

    static func apply(regions: [RedactionRegion], to videoURL: URL) async throws -> URL {
        guard !regions.isEmpty else { return videoURL }

        let asset = AVURLAsset(url: videoURL)
        let capturedRegions = regions

        let videoComposition = AVMutableVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            var output = request.sourceImage
            let extent = output.extent

            let active = capturedRegions.filter { $0.isActive(at: request.compositionTime) }
            guard !active.isEmpty else {
                request.finish(with: output, context: nil)
                return
            }

            output = output.clampedToExtent()

            for region in active {
                // Convert normalized rect (top-left origin) to CIImage rect (bottom-left origin)
                let ciRect = CGRect(
                    x: region.rect.origin.x * extent.width,
                    y: (1 - region.rect.origin.y - region.rect.height) * extent.height,
                    width: region.rect.width * extent.width,
                    height: region.rect.height * extent.height
                ).integral

                guard ciRect.width > 0, ciRect.height > 0 else { continue }

                switch region.style {
                case .blur:
                    let cropped = output.cropped(to: ciRect)
                    let blurred = cropped.clampedToExtent()
                        .applyingGaussianBlur(sigma: 30)
                        .cropped(to: ciRect)
                    output = blurred.composited(over: output)

                case .blackFill:
                    let black = CIImage(color: .black).cropped(to: ciRect)
                    output = black.composited(over: output)
                }
            }

            request.finish(with: output.cropped(to: extent), context: nil)
        })

        // Create output URL next to the original
        let format = ExportFormat.current
        let baseName = videoURL.deletingPathExtension().lastPathComponent
        let outputURL = videoURL.deletingLastPathComponent()
            .appendingPathComponent("\(baseName) (Redacted).\(format.fileExtension)")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHEVCHighestQuality
        ) else {
            throw CompositorError.exportFailed("Could not create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = format.avFileType
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        guard exportSession.status == .completed else {
            let detail = exportSession.error?.localizedDescription ?? "Unknown error"
            throw CompositorError.exportFailed(detail)
        }

        return outputURL
    }
}
