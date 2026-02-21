import Foundation
import AVFoundation

/// Represents a Retake project containing a recording and all associated metadata
struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var lastModified: Date
    var rawVideoURL: URL
    var exportSettings: ExportSettings
    let version: String
    
    init(
        id: UUID = UUID(),
        name: String = "Untitled Recording",
        rawVideoURL: URL
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.lastModified = Date()
        self.rawVideoURL = rawVideoURL
        self.exportSettings = .default
        self.version = "1.0"
    }
    
    mutating func markAsModified() {
        lastModified = Date()
    }
}

// MARK: - Export Settings

/// Export configuration for final video output
struct ExportSettings: Codable, Equatable {
    /// Output resolution (width x height)
    var resolution: CGSize
    
    /// Video codec type
    var codec: VideoCodec
    
    /// Export quality preset
    var quality: QualityPreset
    
    /// Frame rate (default: match source)
    var frameRate: Int?
    
    /// Audio bitrate in kbps (default: 192)
    var audioBitrate: Int
    
    static let `default` = ExportSettings(
        resolution: CGSize(width: 1920, height: 1080),
        codec: .hevc,
        quality: .high,
        frameRate: nil,
        audioBitrate: 192
    )
}

/// Video codec options for export
enum VideoCodec: String, Codable {
    case hevc = "hevc"       // H.265 (smaller files, modern)
    case h264 = "h264"       // H.264 (universal compatibility)
    case prores = "prores"   // ProRes (lossless, large files)
    
    var avCodecType: AVVideoCodecType {
        switch self {
        case .hevc: return .hevc
        case .h264: return .h264
        case .prores: return .proRes422
        }
    }
}

/// Quality presets for export
enum QualityPreset: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case lossless = "lossless"
    
    var bitrateMbps: Int? {
        switch self {
        case .low: return 5
        case .medium: return 10
        case .high: return 20
        case .lossless: return nil // Use ProRes
        }
    }
}


