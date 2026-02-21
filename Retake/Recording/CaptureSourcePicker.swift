import SwiftUI
@preconcurrency import ScreenCaptureKit

struct CaptureSourcePicker: View {
    @State private var displays: [SCDisplay] = []
    @State private var windows: [SCWindow] = []
    @State private var selectedMode: CaptureMode?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var thumbnails: [String: NSImage] = [:]
    
    enum CaptureMode: Identifiable {
        case display(SCDisplay)
        case window(SCWindow)
        case region
        
        var id: String {
            switch self {
            case .display(let display):
                return "display-\(display.displayID)"
            case .window(let window):
                return "window-\(window.windowID)"
            case .region:
                return "region"
            }
        }
        
        var title: String {
            switch self {
            case .display:
                return "Full Screen"
            case .window(let window):
                return window.title ?? "Untitled Window"
            case .region:
                return "Select Region"
            }
        }
    }
    
    let onStart: (RecordingEngine.CaptureMode) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Choose What to Record")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            Divider()
            
            if isLoading {
                ProgressView("Loading available sources...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Failed to load capture sources")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !displays.isEmpty {
                            Text("Displays")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)], spacing: 16) {
                                ForEach(displays, id: \.displayID) { display in
                                    let mode = CaptureMode.display(display)
                                    SourceThumbnailCard(
                                        title: "Display \(display.displayID)",
                                        subtitle: "\(display.width) × \(display.height)",
                                        icon: "display",
                                        thumbnail: thumbnails[mode.id],
                                        isSelected: selectedModeMatches(mode)
                                    ) {
                                        selectedMode = mode
                                    }
                                }
                            }
                        }
                        
                        if !windows.isEmpty {
                            Text("Windows")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)], spacing: 16) {
                                ForEach(windows, id: \.windowID) { window in
                                    let mode = CaptureMode.window(window)
                                    SourceThumbnailCard(
                                        title: window.title ?? "Untitled Window",
                                        subtitle: window.owningApplication?.applicationName,
                                        icon: "macwindow",
                                        thumbnail: thumbnails[mode.id],
                                        isSelected: selectedModeMatches(mode)
                                    ) {
                                        selectedMode = mode
                                    }
                                }
                            }
                        }
                        
                        Text("Custom")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)], spacing: 16) {
                            SourceThumbnailCard(
                                title: "Select Region",
                                subtitle: "Choose a specific area",
                                icon: "viewfinder",
                                thumbnail: nil,
                                isSelected: selectedModeMatches(.region)
                            ) {
                                selectedMode = .region
                            }
                        }
                    }
                    .padding(20)
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Start Recording") {
                    startRecording()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedMode == nil)
            }
            .padding()
        }
        .frame(width: 700, height: 520)
        .task {
            await loadContent()
        }
    }
    
    private func selectedModeMatches(_ mode: CaptureMode) -> Bool {
        guard let selectedMode = selectedMode else { return false }
        return selectedMode.id == mode.id
    }
    
    private func loadContent() async {
        isLoading = true
        error = nil
        
        do {
            let content = try await SCShareableContent.current
            
            await MainActor.run {
                displays = content.displays
                windows = content.windows.filter { window in
                    // Filter out windows without titles and Retake's own windows
                    guard let title = window.title, !title.isEmpty else { return false }
                    guard let app = window.owningApplication else { return false }
                    return app.bundleIdentifier != Bundle.main.bundleIdentifier
                }
                isLoading = false
                
                // Auto-select primary display
                if let firstDisplay = displays.first {
                    selectedMode = .display(firstDisplay)
                }
            }
            
            // Fetch all thumbnails concurrently
            await loadAllThumbnails()
        } catch {
            await MainActor.run {
                self.error = error
                isLoading = false
            }
        }
    }
    
    private func loadAllThumbnails() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            await withTaskGroup(of: (String, NSImage?).self) { group in
                // Displays
                for display in displays {
                    let modeID = CaptureMode.display(display).id
                    guard let scDisplay = content.displays.first(where: { $0.displayID == display.displayID }) else { continue }
                    group.addTask {
                        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
                        let image = try? await self.capturePreview(filter: filter, width: scDisplay.width, height: scDisplay.height)
                        return (modeID, image)
                    }
                }
                
                // Windows
                for window in windows {
                    let modeID = CaptureMode.window(window).id
                    guard let scWindow = content.windows.first(where: { $0.windowID == window.windowID }) else { continue }
                    group.addTask {
                        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
                        let frame = scWindow.frame
                        let image = try? await self.capturePreview(filter: filter, width: Int(frame.width), height: Int(frame.height))
                        return (modeID, image)
                    }
                }
                
                for await (id, image) in group {
                    if let image {
                        thumbnails[id] = image
                    }
                }
            }
        } catch {
            // Thumbnails are best-effort
        }
    }
    
    private func startRecording() {
        guard let selectedMode = selectedMode else { return }
        
        let engineMode: RecordingEngine.CaptureMode
        
        switch selectedMode {
        case .display(let display):
            engineMode = .fullScreen(displayID: display.displayID)
        case .window(let window):
            engineMode = .window(windowID: window.windowID)
        case .region:
            if let firstDisplay = displays.first {
                engineMode = .fullScreen(displayID: firstDisplay.displayID)
            } else {
                return
            }
        }
        
        onStart(engineMode)
    }
    
    private func capturePreview(filter: SCContentFilter, width: Int, height: Int) async throws -> NSImage? {
        let config = SCStreamConfiguration()
        config.width = min(width, 800)
        config.height = min(height, 600)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = false
        config.showsCursor = true
        
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}

struct SourceThumbnailCard: View {
    let title: String
    var subtitle: String?
    let icon: String
    let thumbnail: NSImage?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Thumbnail area
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.controlBackgroundColor))
                    
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 130)
                
                // Label
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color(.separatorColor), lineWidth: isSelected ? 2.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
