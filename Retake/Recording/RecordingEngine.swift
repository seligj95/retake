import Foundation
@preconcurrency import ScreenCaptureKit
import AVFoundation
import Combine

/// Represents one continuous recording segment (a new segment starts after each redo)
struct RecordingSegment {
    let url: URL
    var trimEnd: CMTime?  // If set, only use content up to this point
}

@MainActor
@Observable
final class RecordingEngine {
    enum State {
        case idle
        case preparing
        case recording
        case paused
        case redoing     // Paused for redo preview
        case stitching   // Combining segments after final stop
        case stopped
        case failed(Error)
        
        var isIdle: Bool {
            if case .idle = self { return true }
            return false
        }
        
        var isStopped: Bool {
            if case .stopped = self { return true }
            return false
        }
        
        var isRecording: Bool {
            if case .recording = self { return true }
            return false
        }
        
        var isRedoing: Bool {
            if case .redoing = self { return true }
            return false
        }
        
        var isPaused: Bool {
            if case .paused = self { return true }
            return false
        }
    }
    
    enum RecordingError: LocalizedError {
        case noContentAvailable
        case filterCreationFailed
        case streamCreationFailed
        case alreadyRecording
        case notRecording
        case exportFailed
        
        var errorDescription: String? {
            switch self {
            case .noContentAvailable: return "No displays or windows available for recording"
            case .filterCreationFailed: return "Failed to create content filter"
            case .streamCreationFailed: return "Failed to create screen capture stream"
            case .alreadyRecording: return "Recording already in progress"
            case .notRecording: return "No active recording"
            case .exportFailed: return "Failed to export final video"
            }
        }
    }
    
    enum CaptureMode {
        case fullScreen(displayID: CGDirectDisplayID)
        case window(windowID: CGWindowID)
        case region(displayID: CGDirectDisplayID, rect: CGRect)
    }
    
    struct Configuration {
        var resolution: CGSize = CGSize(width: 1920, height: 1080)
        var frameRate: Int = 60
        var captureAudio: Bool = true
        var captureMicrophone: Bool = true
        var excludeCurrentProcess: Bool = true
        
        static let `default` = Configuration()
    }
    
    private(set) var state: State = .idle
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var streamOutputHandler: StreamOutputHandler?
    private var outputURL: URL?
    private var startTime: Date?
    
    // Segment-based recording for redo support
    private(set) var segments: [RecordingSegment] = []
    private var currentCaptureMode: CaptureMode?
    private var currentConfiguration: Configuration = .default
    private var accumulatedDuration: TimeInterval = 0
    private let recordingDelegate = RecordingDelegate()
    
    var recordingDuration: TimeInterval {
        guard let start = startTime else { return accumulatedDuration }
        return accumulatedDuration + Date().timeIntervalSince(start)
    }
    
    var redoCount: Int { segments.count }
    
    // MARK: - Content Enumeration
    
    func getAvailableContent() async throws -> SCShareableContent {
        try await SCShareableContent.current
    }
    
    // MARK: - Recording Lifecycle
    
    func startRecording(mode: CaptureMode, configuration: Configuration = .default) async throws -> URL {
        guard state.isIdle || state.isStopped else {
            throw RecordingError.alreadyRecording
        }
        
        state = .preparing
        
        // Store mode and configuration for potential redo restarts
        self.currentCaptureMode = mode
        self.currentConfiguration = configuration
        self.segments.removeAll()
        self.accumulatedDuration = 0
        
        do {
            // Get shareable content
            let content = try await getAvailableContent()
            
            // Create content filter
            let filter = try createFilter(mode: mode, content: content)
            
            // Configure stream
            let streamConfig = createStreamConfiguration(configuration: configuration)
            
            // Create stream
            let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
            
            // Set up recording output
            let outputURL = createOutputURL()
            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = outputURL
            recordingConfig.videoCodecType = .hevc
            
            let recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: recordingDelegate)
            try stream.addRecordingOutput(recordingOutput)
            
            // Add stream output handler for audio/mic sample buffers
            let outputHandler = StreamOutputHandler()
            try stream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.retake.screen"))
            if configuration.captureAudio {
                try stream.addStreamOutput(outputHandler, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.retake.audio"))
            }
            if configuration.captureMicrophone {
                try stream.addStreamOutput(outputHandler, type: .microphone, sampleHandlerQueue: DispatchQueue(label: "com.retake.mic"))
            }
            
            // Start capture
            try await stream.startCapture()
            
            // Store state
            self.stream = stream
            self.recordingOutput = recordingOutput
            self.streamOutputHandler = outputHandler
            self.outputURL = outputURL
            self.startTime = Date()
            self.state = .recording
            
            return outputURL
            
        } catch {
            state = .failed(error)
            throw error
        }
    }
    
    func stopRecording() async throws -> URL {
        guard state.isRecording || state.isPaused else {
            throw RecordingError.notRecording
        }
        
        // If paused, the stream is already stopped and segment saved
        if state.isPaused {
            self.startTime = nil
            
            if segments.count == 1 && segments[0].trimEnd == nil {
                let result = segments[0].url
                segments.removeAll()
                state = .stopped
                return result
            }
            
            state = .stitching
            let finalURL = try await stitchSegments()
            segments.removeAll()
            state = .stopped
            return finalURL
        }
        
        guard let stream = stream, let outputURL = outputURL else {
            throw RecordingError.notRecording
        }
        
        do {
            try await stream.stopCapture()
            try await Task.sleep(for: .milliseconds(300))
            
            // Add the final segment
            segments.append(RecordingSegment(url: outputURL, trimEnd: nil))
            
            // Clean up stream state
            self.stream = nil
            self.recordingOutput = nil
            self.streamOutputHandler = nil
            self.startTime = nil
            
            // Single segment with no trims → return it directly
            if segments.count == 1 && segments[0].trimEnd == nil {
                let result = segments[0].url
                segments.removeAll()
                state = .stopped
                return result
            }
            
            // Multiple segments → stitch them together
            state = .stitching
            let finalURL = try await stitchSegments()
            segments.removeAll()
            state = .stopped
            return finalURL
            
        } catch {
            state = .failed(error)
            throw error
        }
    }
    
    /// Cancel the recording and delete all segment files
    func cancelRecording() async {
        // Stop the active stream if running
        if let stream = stream {
            try? await stream.stopCapture()
            try? await Task.sleep(for: .milliseconds(200))
        }
        
        // Collect all files to delete
        var filesToDelete = segments.map(\.url)
        if let outputURL = outputURL {
            filesToDelete.append(outputURL)
        }
        
        // Clean up state
        self.stream = nil
        self.recordingOutput = nil
        self.streamOutputHandler = nil
        self.startTime = nil
        self.accumulatedDuration = 0
        self.segments.removeAll()
        self.outputURL = nil
        self.currentCaptureMode = nil
        self.state = .idle
        
        // Delete all intermediate files
        for url in filesToDelete {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Pause / Resume
    
    /// Pause recording: stops the current stream and saves the segment
    func pauseRecording() async throws {
        guard state.isRecording else { throw RecordingError.notRecording }
        guard let stream = stream, let outputURL = outputURL else { throw RecordingError.notRecording }
        
        try await stream.stopCapture()
        try await Task.sleep(for: .milliseconds(300))
        
        // Accumulate the duration of this segment before clearing startTime
        if let start = startTime {
            accumulatedDuration += Date().timeIntervalSince(start)
        }
        
        segments.append(RecordingSegment(url: outputURL, trimEnd: nil))
        
        self.stream = nil
        self.recordingOutput = nil
        self.streamOutputHandler = nil
        self.startTime = nil
        self.state = .paused
    }
    
    /// Resume from pause: starts a new recording segment
    func unpauseRecording() async throws {
        guard state.isPaused else { return }
        guard let captureMode = currentCaptureMode else { throw RecordingError.notRecording }
        
        state = .preparing
        
        let content = try await getAvailableContent()
        let filter = try createFilter(mode: captureMode, content: content)
        let streamConfig = createStreamConfiguration(configuration: currentConfiguration)
        let newStream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        
        let newOutputURL = createOutputURL()
        let recordingConfig = SCRecordingOutputConfiguration()
        recordingConfig.outputURL = newOutputURL
        recordingConfig.videoCodecType = .hevc
        
        let newRecordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: recordingDelegate)
        try newStream.addRecordingOutput(newRecordingOutput)
        
        let outputHandler = StreamOutputHandler()
        try newStream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.retake.screen"))
        if currentConfiguration.captureAudio {
            try newStream.addStreamOutput(outputHandler, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.retake.audio"))
        }
        if currentConfiguration.captureMicrophone {
            try newStream.addStreamOutput(outputHandler, type: .microphone, sampleHandlerQueue: DispatchQueue(label: "com.retake.mic"))
        }
        
        try await newStream.startCapture()
        
        self.stream = newStream
        self.recordingOutput = newRecordingOutput
        self.streamOutputHandler = outputHandler
        self.outputURL = newOutputURL
        self.startTime = Date()
        self.state = .recording
    }
    
    // MARK: - Redo Support
    
    /// Pause recording for redo: stops the current segment, stitches all segments into
    /// a single preview file, and returns it so the user can pick any point in the full recording
    func pauseForRedo() async throws -> URL {
        guard state.isRecording else { throw RecordingError.notRecording }
        guard let stream = stream, let outputURL = outputURL else { throw RecordingError.notRecording }
        
        try await stream.stopCapture()
        try await Task.sleep(for: .milliseconds(300))
        
        segments.append(RecordingSegment(url: outputURL, trimEnd: nil))
        
        self.stream = nil
        self.recordingOutput = nil
        self.streamOutputHandler = nil
        
        // If multiple segments (e.g. from prior pauses), stitch into a single preview
        let previewURL: URL
        if segments.count > 1 {
            previewURL = try await stitchSegments()
            // Replace all segments with the single stitched file
            segments = [RecordingSegment(url: previewURL, trimEnd: nil)]
        } else {
            previewURL = outputURL
        }
        
        self.state = .redoing
        return previewURL
    }
    
    /// Resume recording after redo, optionally trimming the last segment
    func resumeRecording(trimEnd: CMTime? = nil) async throws {
        guard case .redoing = state else { return }
        guard let captureMode = currentCaptureMode else { throw RecordingError.notRecording }
        
        // Apply trim to last segment if specified
        if let trimEnd, !segments.isEmpty {
            segments[segments.count - 1].trimEnd = trimEnd
        }
        
        // Recalculate accumulated duration
        accumulatedDuration = 0
        for segment in segments {
            if let trim = segment.trimEnd {
                accumulatedDuration += trim.seconds
            } else {
                let asset = AVURLAsset(url: segment.url)
                if let dur = try? await asset.load(.duration) {
                    accumulatedDuration += dur.seconds
                }
            }
        }
        
        // Start a new recording segment
        state = .preparing
        
        let content = try await getAvailableContent()
        let filter = try createFilter(mode: captureMode, content: content)
        let streamConfig = createStreamConfiguration(configuration: currentConfiguration)
        let newStream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        
        let newOutputURL = createOutputURL()
        let recordingConfig = SCRecordingOutputConfiguration()
        recordingConfig.outputURL = newOutputURL
        recordingConfig.videoCodecType = .hevc
        
        let newRecordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: recordingDelegate)
        try newStream.addRecordingOutput(newRecordingOutput)
        
        let outputHandler = StreamOutputHandler()
        try newStream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.retake.screen"))
        if currentConfiguration.captureAudio {
            try newStream.addStreamOutput(outputHandler, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.retake.audio"))
        }
        if currentConfiguration.captureMicrophone {
            try newStream.addStreamOutput(outputHandler, type: .microphone, sampleHandlerQueue: DispatchQueue(label: "com.retake.mic"))
        }
        
        try await newStream.startCapture()
        
        self.stream = newStream
        self.recordingOutput = newRecordingOutput
        self.streamOutputHandler = outputHandler
        self.outputURL = newOutputURL
        self.startTime = Date()
        self.state = .recording
    }
    
    /// Stitch all segments into a single video file
    private func stitchSegments() async throws -> URL {
        let composition = AVMutableComposition()
        
        guard let compVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RecordingError.exportFailed
        }
        
        let compAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        var insertionTime: CMTime = .zero
        
        for segment in segments {
            let asset = AVURLAsset(url: segment.url)
            let assetDuration = try await asset.load(.duration)
            let endTime = segment.trimEnd ?? assetDuration
            let timeRange = CMTimeRange(start: .zero, end: endTime)
            
            if let sourceVideo = try await asset.loadTracks(withMediaType: .video).first {
                try compVideoTrack.insertTimeRange(timeRange, of: sourceVideo, at: insertionTime)
            }
            
            if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                try compAudioTrack?.insertTimeRange(timeRange, of: sourceAudio, at: insertionTime)
            }
            
            insertionTime = insertionTime + timeRange.duration
        }
        
        let finalURL = createOutputURL()
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHEVC1920x1080
        ) else {
            throw RecordingError.exportFailed
        }
        
        exportSession.outputURL = finalURL
        exportSession.outputFileType = ExportFormat.current.avFileType
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw RecordingError.exportFailed
        }
        
        // Clean up individual segment files
        for segment in segments {
            try? FileManager.default.removeItem(at: segment.url)
        }
        
        return finalURL
    }
    
    // MARK: - Private Helpers
    
    private func createFilter(mode: CaptureMode, content: SCShareableContent) throws -> SCContentFilter {
        // Exclude our own app entirely so windows created after recording starts
        // (e.g. the floating status bar) are also excluded
        let ownBundleID = Bundle.main.bundleIdentifier ?? "com.retake"
        let ownApps = content.applications.filter { $0.bundleIdentifier == ownBundleID }
        
        switch mode {
        case .fullScreen(let displayID):
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw RecordingError.filterCreationFailed
            }
            return SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            
        case .window(let windowID):
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw RecordingError.filterCreationFailed
            }
            return SCContentFilter(desktopIndependentWindow: window)
            
        case .region(let displayID, let rect):
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw RecordingError.filterCreationFailed
            }
            return SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        }
    }
    
    private func createStreamConfiguration(configuration: Configuration) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        
        // Video settings
        config.width = Int(configuration.resolution.width)
        config.height = Int(configuration.resolution.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Audio settings
        config.capturesAudio = configuration.captureAudio
        config.captureMicrophone = configuration.captureMicrophone
        config.excludesCurrentProcessAudio = configuration.excludeCurrentProcess
        config.sampleRate = 48000
        config.channelCount = 2
        
        // Performance
        config.queueDepth = 5
        
        return config
    }
    
    // MARK: - Save Location
    
    static var defaultSaveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Movies")
            .appendingPathComponent("Retake")
    }
    
    private func createOutputURL() -> URL {
        let customPath = UserDefaults.standard.string(forKey: "saveLocation") ?? ""
        let saveDir: URL
        if customPath.isEmpty {
            saveDir = Self.defaultSaveDirectory
        } else {
            saveDir = URL(filePath: customPath)
        }
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let ext = ExportFormat.current.fileExtension
        let filename = "Recording \(timestamp).\(ext)"
        return saveDir.appendingPathComponent(filename)
    }
}

// MARK: - Recording Delegate

private final class RecordingDelegate: NSObject, SCRecordingOutputDelegate {
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        print("Recording started")
    }
    
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        print("Recording failed: \(error.localizedDescription)")
    }
    
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        print("Recording finished")
    }
}

// MARK: - Stream Output (handles sample buffers so they aren't dropped)

private final class StreamOutputHandler: NSObject, SCStreamOutput, @unchecked Sendable {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // SCRecordingOutput handles file writing; this handler exists to
        // prevent "streamOutput NOT found" errors for audio/mic frames.
    }
}
