import SwiftUI
import AVFoundation
import AVKit

// MARK: - Controller

@MainActor
final class TrimEditorController {
    private var window: NSWindow?

    func show(videoURL: URL, onSave: @escaping (CMTime, CMTime) -> Void, onSkip: @escaping () -> Void) {
        guard window == nil else { return }

        let editorView = TrimEditorView(
            videoURL: videoURL,
            onSave: { [weak self] inPoint, outPoint in
                self?.hide()
                onSave(inPoint, outPoint)
            },
            onSkip: { [weak self] in
                self?.hide()
                onSkip()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Trim Recording"
        window.center()
        window.minSize = NSSize(width: 600, height: 440)
        window.contentView = NSHostingView(rootView: editorView)
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - Trim Editor View

private struct TrimEditorView: View {
    let videoURL: URL
    let onSave: (CMTime, CMTime) -> Void
    let onSkip: () -> Void

    @State private var playerController = VideoPreviewPlayerController()
    @State private var duration: CMTime = .zero
    @State private var inFraction: Double = 0
    @State private var outFraction: Double = 1
    @State private var scrubFraction: Double = 0
    @State private var isUserScrubbing = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Trim your recording")
                    .font(.headline)
                Text("Drag the handles to set the start and end points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Video preview
            VideoPreviewPlayer(controller: playerController)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Playback scrubber
            HStack(spacing: 12) {
                Button {
                    playerController.togglePlayPause()
                } label: {
                    Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 20)
                }
                .buttonStyle(.plain)

                Button { playerController.stepBackward() } label: {
                    Image(systemName: "backward.frame.fill")
                }
                .buttonStyle(.plain)

                Button { playerController.stepForward() } label: {
                    Image(systemName: "forward.frame.fill")
                }
                .buttonStyle(.plain)

                Slider(value: $scrubFraction, in: 0...1) { editing in
                    isUserScrubbing = editing
                    if editing { playerController.pause() }
                }

                Text(formatTime(playerController.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 50)
            }

            // Trim range controls
            VStack(spacing: 8) {
                Text("Trim Range")
                    .font(.subheadline.weight(.medium))

                TrimRangeSlider(
                    inFraction: $inFraction,
                    outFraction: $outFraction
                )
                .frame(height: 28)

                HStack {
                    // In point
                    HStack(spacing: 6) {
                        Text("Start:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(inTime))
                            .font(.system(size: 12, design: .monospaced))
                            .monospacedDigit()
                        Button("Set to Current") {
                            guard duration.seconds > 0 else { return }
                            inFraction = playerController.currentTime.seconds / duration.seconds
                        }
                        .controlSize(.mini)
                    }

                    Spacer()

                    // Out point
                    HStack(spacing: 6) {
                        Text("End:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(outTime))
                            .font(.system(size: 12, design: .monospaced))
                            .monospacedDigit()
                        Button("Set to Current") {
                            guard duration.seconds > 0 else { return }
                            outFraction = playerController.currentTime.seconds / duration.seconds
                        }
                        .controlSize(.mini)
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()

            // Action buttons
            HStack {
                Button("Skip Trimming") { onSkip() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Trimmed") {
                    playerController.pause()
                    onSave(inTime, outTime)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!hasTrim)
            }
        }
        .padding(20)
        .onChange(of: scrubFraction) { _, newValue in
            guard isUserScrubbing else { return }
            let time = CMTime(seconds: duration.seconds * newValue, preferredTimescale: 600)
            Task { await playerController.seek(to: time) }
        }
        .task {
            await loadVideo()
        }
    }

    // MARK: - Computed

    private var inTime: CMTime {
        CMTime(seconds: duration.seconds * inFraction, preferredTimescale: 600)
    }

    private var outTime: CMTime {
        CMTime(seconds: duration.seconds * outFraction, preferredTimescale: 600)
    }

    private var hasTrim: Bool {
        inFraction > 0.001 || outFraction < 0.999
    }

    // MARK: - Helpers

    private func loadVideo() async {
        playerController.load(url: videoURL)
        let asset = AVURLAsset(url: videoURL)
        if let dur = try? await asset.load(.duration) {
            duration = dur
        }
    }

    private func formatTime(_ time: CMTime) -> String {
        guard time.isValid && !time.isIndefinite else { return "0:00" }
        let totalSeconds = Int(time.seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Dual-Handle Trim Slider

private struct TrimRangeSlider: View {
    @Binding var inFraction: Double
    @Binding var outFraction: Double

    private let handleWidth: CGFloat = 14
    private let trackHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let usableWidth = geo.size.width - handleWidth
            let inX = inFraction * usableWidth
            let outX = outFraction * usableWidth

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.separatorColor))
                    .frame(height: trackHeight)
                    .padding(.horizontal, handleWidth / 2)

                // Active range
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(width: max(0, outX - inX), height: trackHeight)
                    .offset(x: inX + handleWidth / 2)

                // In handle
                trimHandle(color: .green)
                    .offset(x: inX)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let fraction = max(0, min(value.location.x / usableWidth, outFraction - 0.01))
                                inFraction = fraction
                            }
                    )

                // Out handle
                trimHandle(color: .red)
                    .offset(x: outX)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let fraction = max(inFraction + 0.01, min(value.location.x / usableWidth, 1))
                                outFraction = fraction
                            }
                    )
            }
        }
    }

    private func trimHandle(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: handleWidth, height: 24)
            .shadow(radius: 2)
    }
}
