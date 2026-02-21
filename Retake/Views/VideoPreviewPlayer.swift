import SwiftUI
import AVFoundation
import AVKit

/// AVPlayer wrapper for SwiftUI with playback controls
/// Provides play/pause, seek, frame-step, and J/K/L playback speed
@MainActor
@Observable
final class VideoPreviewPlayerController {
    private(set) var player: AVPlayer
    private(set) var playerItem: AVPlayerItem?
    
    private(set) var currentTime: CMTime = .zero
    private(set) var duration: CMTime = .zero
    private(set) var isPlaying: Bool = false
    
    private var timeObserver: Any?
    private var itemObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    
    init() {
        self.player = AVPlayer()
        setupObservers()
    }
    
    deinit {
        // Deinit is nonisolated in Swift 6, but cleanup needs to happen on MainActor
        // Resources will be cleaned up by ARC when controller is deallocated
    }
    
    // MARK: - Lifecycle
    
    func load(url: URL) {
        cleanup()
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        self.playerItem = item
        player.replaceCurrentItem(with: item)
        
        // Observe item status
        itemObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.duration = item.duration
                }
            }
        }
        
        // Observe rate changes
        rateObserver = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }
        
        // Setup time observer
        let interval = CMTime(seconds: 0.016, preferredTimescale: 600) // ~60fps
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time
            }
        }
    }
    
    private func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        itemObserver?.invalidate()
        itemObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil
        playerItem = nil
    }
    
    // MARK: - Playback Control
    
    func play() {
        player.play()
        isPlaying = true
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: CMTime, toleranceBefore: CMTime = .zero, toleranceAfter: CMTime = .zero) async {
        await player.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
        currentTime = time
    }
    
    func seekToStart() {
        Task {
            await seek(to: .zero)
        }
    }
    
    func seekToEnd() {
        Task {
            await seek(to: duration)
        }
    }
    
    // MARK: - Frame Stepping
    
    /// Step forward by one frame (assuming 60fps)
    func stepForward() {
        guard let item = playerItem else { return }
        item.step(byCount: 1)
        currentTime = player.currentTime()
    }
    
    /// Step backward by one frame (assuming 60fps)
    func stepBackward() {
        guard let item = playerItem else { return }
        item.step(byCount: -1)
        currentTime = player.currentTime()
    }
    
    // MARK: - J/K/L Playback Speed
    
    /// Set playback rate: J = -2x, K = pause, L = normal/2x
    /// - Parameter speed: Rate multiplier (negative for reverse)
    func setPlaybackSpeed(_ speed: Float) {
        player.rate = speed
    }
    
    func jklBackward() {
        // J key: -2x playback (or step backward if at start)
        if currentTime <= CMTime(seconds: 0.1, preferredTimescale: 600) {
            stepBackward()
        } else {
            setPlaybackSpeed(-2.0)
        }
    }
    
    func jklPause() {
        // K key: pause
        pause()
    }
    
    func jklForward() {
        // L key: cycle through 1x → 2x → 1x
        if abs(player.rate - 1.0) < 0.01 {
            setPlaybackSpeed(2.0)
        } else {
            setPlaybackSpeed(1.0)
        }
    }
    
    private func setupObservers() {
        // Initial setup completed in load()
    }
}

/// SwiftUI view wrapper for VideoPreviewPlayerController
struct VideoPreviewPlayer: View {
    let controller: VideoPreviewPlayerController
    @State private var isHoveringControls = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video player layer
                VideoPlayerView(player: controller.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .background(Color.black)
                
                // Overlay controls (appear on hover)
                if isHoveringControls || !controller.isPlaying {
                    PlaybackControlsOverlay(controller: controller)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: isHoveringControls)
                }
            }
            .onHover { hovering in
                isHoveringControls = hovering
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Native AVPlayerView wrapper for SwiftUI
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        view.showsSharingServiceButton = false
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Player is set once, no updates needed
    }
}

/// Minimal playback controls overlay
private struct PlaybackControlsOverlay: View {
    let controller: VideoPreviewPlayerController
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 16) {
                // Play/Pause button
                Button {
                    controller.togglePlayPause()
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help(controller.isPlaying ? "Pause (Space)" : "Play (Space)")
                
                // Current time
                Text(formatTime(controller.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .monospacedDigit()
                
                // Duration
                Text("/ \(formatTime(controller.duration))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
                
                Spacer()
                
                // Frame step controls
                HStack(spacing: 8) {
                    Button {
                        controller.stepBackward()
                    } label: {
                        Image(systemName: "backward.frame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Step Backward (Left Arrow)")
                    
                    Button {
                        controller.stepForward()
                    } label: {
                        Image(systemName: "forward.frame.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .help("Step Forward (Right Arrow)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.8))
            }
        }
    }
    
    private func formatTime(_ time: CMTime) -> String {
        guard time.isValid && !time.isIndefinite else { return "0:00" }
        let totalSeconds = Int(time.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
