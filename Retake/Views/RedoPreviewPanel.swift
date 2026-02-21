import SwiftUI
import AVFoundation
import AVKit

/// Controller for the redo preview window that appears when the user presses Redo during recording
@MainActor
final class RedoPreviewController {
    private var window: NSWindow?
    
    func show(segmentURL: URL, onResume: @escaping (CMTime) -> Void, onCancel: @escaping () -> Void) {
        guard window == nil else { return }
        
        let contentView = RedoPreviewView(
            segmentURL: segmentURL,
            onResume: { [weak self] time in
                self?.hide()
                onResume(time)
            },
            onCancel: { [weak self] in
                self?.hide()
                onCancel()
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Pick Resume Point"
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        self.window = window
    }
    
    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

/// View for picking where to resume recording after a redo
struct RedoPreviewView: View {
    let segmentURL: URL
    let onResume: (CMTime) -> Void
    let onCancel: () -> Void
    
    @State private var playerController = VideoPreviewPlayerController()
    @State private var duration: CMTime = .zero
    @State private var sliderValue: Double = 1.0
    @State private var isUserDragging = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Pick where to resume recording")
                    .font(.headline)
                Text("Play the video and pause at the point you want to redo from, then click \"Resume from Here\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VideoPreviewPlayer(controller: playerController)
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(spacing: 4) {
                Slider(value: $sliderValue, in: 0...1) { editing in
                    isUserDragging = editing
                    if editing {
                        playerController.pause()
                    }
                }
                
                HStack {
                    Text(formatTime(selectedTime))
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                    Spacer()
                    Text(formatTime(duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Resume from Here") { onResume(selectedTime) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 640)
        .onChange(of: sliderValue) {
            guard isUserDragging else { return }
            Task { await playerController.seek(to: selectedTime) }
        }
        .onChange(of: playerController.currentTime) { _, newTime in
            guard !isUserDragging, duration.seconds > 0 else { return }
            sliderValue = newTime.seconds / duration.seconds
        }
        .task {
            await loadVideo()
        }
    }
    
    private var selectedTime: CMTime {
        guard duration.seconds > 0 else { return .zero }
        return CMTime(seconds: duration.seconds * sliderValue, preferredTimescale: 600)
    }
    
    private func loadVideo() async {
        playerController.load(url: segmentURL)
        let asset = AVURLAsset(url: segmentURL)
        if let dur = try? await asset.load(.duration) {
            duration = dur
            // Start at the end so user can play backward or scrub to find the resume point
            sliderValue = 1.0
            await playerController.seek(to: dur)
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
