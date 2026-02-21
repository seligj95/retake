import SwiftUI
import AppKit
import AVFoundation

// Panel subclass that stays visible even when app is .accessory
private class RecordingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    // Prevent the panel from drawing any default background
    override var contentView: NSView? {
        didSet {
            contentView?.wantsLayer = true
            contentView?.layer?.backgroundColor = .clear
        }
    }
}

@MainActor
final class FloatingStatusBarController {
    private var panel: NSPanel?
    private let recordingEngine: RecordingEngine
    private let onStop: () -> Void
    private let onRedo: () -> Void
    private let onPause: () -> Void
    private let onCancel: () -> Void
    
    init(recordingEngine: RecordingEngine, onStop: @escaping () -> Void, onRedo: @escaping () -> Void, onPause: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.recordingEngine = recordingEngine
        self.onStop = onStop
        self.onRedo = onRedo
        self.onPause = onPause
        self.onCancel = onCancel
    }
    
    func show() {
        guard panel == nil else { return }
        
        let panelSize = NSRect(x: 0, y: 0, width: 420, height: 48)
        
        let panel = RecordingPanel(
            contentRect: panelSize,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Use NSVisualEffectView for the blur background (avoids NSHostingView opacity issues)
        let effectView = NSVisualEffectView(frame: panelSize)
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.masksToBounds = true
        
        let contentView = FloatingStatusBarView(
            recordingEngine: recordingEngine,
            onStop: onStop,
            onRedo: onRedo,
            onPause: onPause,
            onCancel: onCancel
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panelSize
        hostingView.autoresizingMask = [.width, .height]
        // Make the SwiftUI layer fully transparent so the NSVisualEffectView shows through
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        
        effectView.addSubview(hostingView)
        
        panel.contentView = effectView
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        
        // Position near top-center of main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelRect = panel.frame
            let x = screenRect.midX - panelRect.width / 2
            let y = screenRect.maxY - panelRect.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.panel = panel
        panel.orderFrontRegardless()
    }
    
    /// Re-show the panel (e.g. after activation policy change)
    func ensureVisible() {
        panel?.orderFrontRegardless()
    }
    
    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
    
    var isVisible: Bool {
        panel != nil
    }
}

struct FloatingStatusBarView: View {
    let recordingEngine: RecordingEngine
    let onStop: () -> Void
    let onRedo: () -> Void
    let onPause: () -> Void
    let onCancel: () -> Void
    @State private var elapsed: TimeInterval = 0
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private var isPaused: Bool { recordingEngine.state.isPaused }
    
    var body: some View {
        HStack(spacing: 6) {
            // Recording indicator
            Circle()
                .fill(isPaused ? Color.yellow : Color.red)
                .frame(width: 8, height: 8)
            
            Text(isPaused ? "PAUSED" : "REC")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            
            Text(formatDuration(elapsed))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .monospacedDigit()
            
            Divider()
                .frame(height: 16)
            
            // Pause / Resume button
            Button(action: onPause) {
                HStack(spacing: 3) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12))
                    Text(isPaused ? "Resume" : "Pause")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(height: 24)
                .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
            .help(isPaused ? "Resume recording" : "Pause recording")
            
            // Redo button
            Button(action: onRedo) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                    Text("Redo")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(height: 24)
                .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
            .help("Go back and re-record (⌘⇧Z)")
            .disabled(isPaused)
            
            // Redo count
            if recordingEngine.redoCount > 0 {
                Text("\(recordingEngine.redoCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.blue, in: Circle())
            }
            
            Divider()
                .frame(height: 16)
            
            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Stop recording (⌘⇧R)")
            
            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Cancel recording and discard")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 400, height: 40)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onReceive(timer) { _ in
            elapsed = recordingEngine.recordingDuration
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
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

// MARK: - Preview
// Previews removed due to Swift 6.2 macro incompatibility with SPM builds
// Use Xcode canvas for UI preview
