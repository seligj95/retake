import SwiftUI
import AVFoundation

@main
struct RetakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var recordingCoordinator = RecordingCoordinator()
    
    var body: some Scene {
        MenuBarExtra("Retake", systemImage: "record.circle") {
            MenuBarView(coordinator: recordingCoordinator)
        }
        .menuBarExtraStyle(.menu)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var onboardingCoordinator: OnboardingCoordinator?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement handled in Info.plist
        
        // Check if we should show onboarding
        Task { @MainActor in
            if await OnboardingCoordinator.shouldShowOnboarding() {
                self.showOnboarding()
            }
        }
        
        // Check for updates in background
        Task {
            await UpdateService.shared.checkForUpdates()
        }
    }
    
    @MainActor
    private func showOnboarding() {
        // Activate app to show onboarding window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let coordinator = OnboardingCoordinator()
        self.onboardingCoordinator = coordinator
        
        let onboardingView = OnboardingWindow(coordinator: coordinator) { [weak self] in
            self?.dismissOnboarding()
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Retake"
        window.center()
        window.contentView = NSHostingView(rootView: onboardingView)
        
        // Make onboarding modal-like (can't be dismissed until screen recording granted)
        window.styleMask.remove(.closable)
        
        window.makeKeyAndOrderFront(nil)
        
        onboardingWindow = window
    }
    
    @MainActor
    private func dismissOnboarding() {
        // Use orderOut instead of close to avoid _NSWindowTransformAnimation
        // dealloc crash (use-after-free during close animation teardown)
        onboardingWindow?.orderOut(nil)
        
        // Return to menu bar only mode
        NSApp.setActivationPolicy(.accessory)
        
        // Defer cleanup to let any pending animations drain
        DispatchQueue.main.async { [weak self] in
            self?.onboardingWindow = nil
            self?.onboardingCoordinator = nil
        }
    }
}

@MainActor
@Observable
final class RecordingCoordinator {
    private(set) var engine = RecordingEngine()
    private var sourcePickerWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var floatingStatusBar: FloatingStatusBarController?
    private var redoPreviewController: RedoPreviewController?
    private var redactionEditorController: RedactionEditorController?
    private var trimEditorController: TrimEditorController?
    let projectStore = ProjectStore()
    
    var isRecording: Bool {
        engine.state.isRecording
    }
    
    var isActive: Bool {
        engine.state.isRecording || engine.state.isRedoing || engine.state.isPaused
    }
    
    func showCaptureSourcePicker() {
        // Activate app for window display
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let pickerView = CaptureSourcePicker(
            onStart: { [weak self] mode in
                self?.dismissSourcePicker()
                self?.startRecording(with: mode)
            },
            onCancel: { [weak self] in
                self?.dismissSourcePicker()
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "New Recording"
        window.center()
        window.contentView = NSHostingView(rootView: pickerView)
        window.makeKeyAndOrderFront(nil)
        
        sourcePickerWindow = window
    }
    
    private func dismissSourcePicker() {
        sourcePickerWindow?.orderOut(nil)
        DispatchQueue.main.async { [weak self] in
            self?.sourcePickerWindow = nil
        }
    }
    
    private func startRecording(with mode: RecordingEngine.CaptureMode) {
        Task {
            do {
                // Small delay to let the picker window finish closing
                try await Task.sleep(for: .milliseconds(300))
                
                let outputURL = try await engine.startRecording(mode: mode)
                print("Recording started, output will be at: \(outputURL)")
                
                // Create the floating status bar before policy change
                let statusBar = FloatingStatusBarController(
                    recordingEngine: engine,
                    onStop: { [weak self] in
                        self?.stopRecording()
                    },
                    onRedo: { [weak self] in
                        self?.handleRedo()
                    },
                    onPause: { [weak self] in
                        self?.handlePause()
                    },
                    onCancel: { [weak self] in
                        self?.cancelRecording()
                    }
                )
                floatingStatusBar = statusBar
                
                // Switch to accessory (menu bar only)
                NSApp.setActivationPolicy(.accessory)
                
                // Show the panel after a brief delay to let the policy change settle
                try await Task.sleep(for: .milliseconds(200))
                statusBar.show()
                
                // Re-assert visibility after another run loop cycle
                try await Task.sleep(for: .milliseconds(100))
                statusBar.ensureVisible()
                
            } catch {
                print("Failed to start recording: \(error.localizedDescription)")
                await showError(error)
            }
        }
    }
    
    func cancelRecording() {
        Task {
            // Hide floating status bar
            floatingStatusBar?.hide()
            floatingStatusBar = nil
            
            await engine.cancelRecording()
            print("Recording cancelled, all files deleted")
        }
    }
    
    func stopRecording() {
        Task {
            do {
                let outputURL = try await engine.stopRecording()
                print("Recording stopped, saved to: \(outputURL)")
                
                // Hide floating status bar
                floatingStatusBar?.hide()
                floatingStatusBar = nil
                
                // Ask if user wants to add redactions
                let shouldRedact = showRedactionPrompt()
                if shouldRedact {
                    showRedactionEditor(videoURL: outputURL)
                } else {
                    showTrimEditor(videoURL: outputURL)
                }
            } catch {
                print("Failed to stop recording: \(error.localizedDescription)")
                await showError(error)
            }
        }
    }
    
    private func showRedactionPrompt() -> Bool {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = "Add Redactions?"
        alert.informativeText = "Would you like to redact any areas of the recording before saving?"
        alert.addButton(withTitle: "Add Redactions")
        alert.addButton(withTitle: "Skip")
        alert.alertStyle = .informational
        
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    private func showRedactionEditor(videoURL: URL) {
        let editor = RedactionEditorController()
        redactionEditorController = editor
        
        editor.show(
            videoURL: videoURL,
            onApply: { [weak self] regions in
                self?.applyRedactions(to: videoURL, regions: regions)
            },
            onCancel: { [weak self] in
                self?.redactionEditorController = nil
                self?.showTrimEditor(videoURL: videoURL)
            }
        )
    }
    
    private func applyRedactions(to videoURL: URL, regions: [RedactionRegion]) {
        redactionEditorController = nil
        
        Task {
            do {
                print("Applying \(regions.count) redaction(s)...")
                let redactedURL = try await RedactionCompositor.apply(regions: regions, to: videoURL)
                print("Redacted video saved to: \(redactedURL)")
                
                // Remove the original since the redacted version replaces it
                try? FileManager.default.removeItem(at: videoURL)
                
                showTrimEditor(videoURL: redactedURL)
            } catch {
                print("Failed to apply redactions: \(error.localizedDescription)")
                await showError(error)
                // Fall back to trim with original
                showTrimEditor(videoURL: videoURL)
            }
        }
    }
    
    private func showTrimEditor(videoURL: URL) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let editor = TrimEditorController()
        trimEditorController = editor
        
        editor.show(
            videoURL: videoURL,
            onSave: { [weak self] inPoint, outPoint in
                self?.applyTrim(to: videoURL, inPoint: inPoint, outPoint: outPoint)
            },
            onSkip: { [weak self] in
                self?.trimEditorController = nil
                NSWorkspace.shared.activateFileViewerSelecting([videoURL])
            }
        )
    }
    
    private func applyTrim(to videoURL: URL, inPoint: CMTime, outPoint: CMTime) {
        trimEditorController = nil
        
        Task {
            do {
                let asset = AVURLAsset(url: videoURL)
                let composition = AVMutableComposition()
                let timeRange = CMTimeRange(start: inPoint, end: outPoint)
                
                if let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
                   let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try compVideo.insertTimeRange(timeRange, of: videoTrack, at: .zero)
                }
                if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
                   let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try compAudio.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                }
                
                let format = ExportFormat.current
                let baseName = videoURL.deletingPathExtension().lastPathComponent
                let trimmedURL = videoURL.deletingLastPathComponent()
                    .appendingPathComponent("\(baseName) (Trimmed).\(format.fileExtension)")
                try? FileManager.default.removeItem(at: trimmedURL)
                
                guard let exportSession = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetHEVCHighestQuality
                ) else {
                    throw NSError(domain: "Retake", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
                }
                
                exportSession.outputURL = trimmedURL
                exportSession.outputFileType = format.avFileType
                await exportSession.export()
                
                guard exportSession.status == .completed else {
                    throw NSError(domain: "Retake", code: -1, userInfo: [NSLocalizedDescriptionKey: exportSession.error?.localizedDescription ?? "Export failed"])
                }
                
                print("Trimmed video saved to: \(trimmedURL)")
                
                // Remove the pre-trim file (original or redacted) since the trimmed version replaces it
                try? FileManager.default.removeItem(at: videoURL)
                
                NSWorkspace.shared.activateFileViewerSelecting([trimmedURL])
            } catch {
                print("Failed to trim: \(error.localizedDescription)")
                await showError(error)
                NSWorkspace.shared.activateFileViewerSelecting([videoURL])
            }
        }
    }
    
    func handlePause() {
        Task {
            do {
                if engine.state.isPaused {
                    try await engine.unpauseRecording()
                    print("Recording resumed from pause")
                } else {
                    try await engine.pauseRecording()
                    print("Recording paused")
                }
            } catch {
                print("Failed to pause/resume: \(error.localizedDescription)")
                await showError(error)
            }
        }
    }
    
    func handleRedo() {
        Task {
            do {
                let segmentURL = try await engine.pauseForRedo()
                print("Paused for redo, segment at: \(segmentURL)")
                
                // Hide floating bar during redo preview
                floatingStatusBar?.hide()
                
                // Show the redo preview window
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                
                let preview = RedoPreviewController()
                redoPreviewController = preview
                
                preview.show(
                    segmentURL: segmentURL,
                    onResume: { [weak self] trimTime in
                        self?.resumeAfterRedo(trimEnd: trimTime)
                    },
                    onCancel: { [weak self] in
                        self?.resumeAfterRedo(trimEnd: nil)
                    }
                )
            } catch {
                print("Failed to pause for redo: \(error.localizedDescription)")
                await showError(error)
            }
        }
    }
    
    private func resumeAfterRedo(trimEnd: CMTime?) {
        Task {
            do {
                redoPreviewController = nil
                
                try await engine.resumeRecording(trimEnd: trimEnd)
                print("Recording resumed after redo")
                
                // Switch back to accessory mode
                NSApp.setActivationPolicy(.accessory)
                
                // Re-show floating bar
                try await Task.sleep(for: .milliseconds(200))
                floatingStatusBar?.show()
                
                try await Task.sleep(for: .milliseconds(100))
                floatingStatusBar?.ensureVisible()
            } catch {
                print("Failed to resume recording: \(error.localizedDescription)")
                await showError(error)
            }
        }
    }
    
    private func showError(_ error: Error) async {
        let alert = NSAlert()
        alert.messageText = "Recording Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func openPreferences() {
        // Activate app for window display
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let prefsView = PreferencesWindow()
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: prefsView)
        window.makeKeyAndOrderFront(nil)
        
        preferencesWindow = window
    }
    
    func openRecentProject(at url: URL) {
        Task {
            do {
                let project = try await projectStore.load(from: url)
                print("Loaded project: \(project.name)")
                // Reveal the raw video in Finder
                NSWorkspace.shared.activateFileViewerSelecting([project.rawVideoURL])
            } catch {
                await showProjectLoadError(url: url, error: error)
            }
        }
    }
    
    private func showProjectLoadError(url: URL, error: Error) async {
        let alert = NSAlert()
        alert.messageText = "Failed to Open Project"
        alert.informativeText = "Could not load project at \(url.lastPathComponent): \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func playHotkeyFeedback() {
        NSSound.beep()
    }
}

struct MenuBarView: View {
    let coordinator: RecordingCoordinator
    @ObservedObject private var updateService = UpdateService.shared
    
    var body: some View {
        if coordinator.isActive {
            Button("⏹ Stop Recording") {
                coordinator.stopRecording()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!coordinator.isRecording && !coordinator.engine.state.isPaused)
            
            Button("✕ Cancel Recording") {
                coordinator.cancelRecording()
            }
            .disabled(!coordinator.isRecording && !coordinator.engine.state.isPaused)
            
            Button(coordinator.engine.state.isPaused ? "▶️ Resume" : "⏸ Pause") {
                coordinator.handlePause()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!coordinator.isRecording && !coordinator.engine.state.isPaused)
            
            Button("↩️ Redo") {
                coordinator.handleRedo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!coordinator.isRecording)
        } else {
            Button("New Recording") {
                coordinator.showCaptureSourcePicker()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        
        Divider()
        
        Menu("Open Recent") {
            if coordinator.projectStore.recentProjects.isEmpty {
                Text("No recent recordings")
                    .disabled(true)
            } else {
                ForEach(coordinator.projectStore.recentProjects, id: \.self) { projectURL in
                    Button(projectURL.deletingPathExtension().lastPathComponent) {
                        coordinator.openRecentProject(at: projectURL)
                    }
                }
            }
        }
        
        Divider()
        
        Button("Preferences…") {
            coordinator.openPreferences()
        }
        .keyboardShortcut(",", modifiers: .command)
        
        if updateService.updateAvailable {
            Button("Update Available: v\(updateService.latestVersion ?? "")") {
                Task { await updateService.downloadAndInstall() }
            }
        } else {
            Button("Check for Updates…") {
                Task { await updateService.checkForUpdates() }
            }
        }
        
        Divider()
        
        Button("Quit Retake") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
