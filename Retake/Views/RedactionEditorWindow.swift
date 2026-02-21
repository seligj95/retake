import SwiftUI
import AVFoundation
import AVKit

// MARK: - Controller

@MainActor
final class RedactionEditorController {
    private var window: NSWindow?

    func show(videoURL: URL, onApply: @escaping ([RedactionRegion]) -> Void, onCancel: @escaping () -> Void) {
        guard window == nil else { return }

        let editorView = RedactionEditorView(
            videoURL: videoURL,
            onApply: { [weak self] regions in
                self?.hide()
                onApply(regions)
            },
            onCancel: { [weak self] in
                self?.hide()
                onCancel()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Redact Recording"
        window.center()
        window.minSize = NSSize(width: 700, height: 550)
        window.contentView = NSHostingView(rootView: editorView)
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - Main Editor View

private struct RedactionEditorView: View {
    let videoURL: URL
    let onApply: ([RedactionRegion]) -> Void
    let onCancel: () -> Void

    @State private var playerController = VideoPreviewPlayerController()
    @State private var regions: [RedactionRegion] = []
    @State private var selectedRegionID: UUID?
    @State private var videoNaturalSize: CGSize = CGSize(width: 1920, height: 1080)
    @State private var duration: CMTime = .zero
    @State private var scrubberValue: Double = 0
    @State private var isUserScrubbing = false

    // Drawing state
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    
    // Interaction state for move/resize
    @State private var interactionMode: InteractionMode = .none
    @State private var moveOffset: CGSize = .zero      // offset from drag point to region origin (normalized)
    @State private var resizeAnchor: CGPoint = .zero    // fixed corner during resize (normalized)
    
    private enum InteractionMode: Equatable {
        case none
        case creating
        case moving(UUID)
        case resizing(UUID)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Video area with drawing overlay
            GeometryReader { geo in
                ZStack {
                    VideoPlayerView(player: playerController.player)
                        .background(Color.black)

                    redactionOverlay(viewSize: geo.size)
                }
            }
            .aspectRatio(videoNaturalSize, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Playback controls
            playbackControls

            Divider()

            // Region list
            regionList

            Divider()

            // Action buttons
            actionButtons
        }
        .padding(20)
        .onChange(of: scrubberValue) { _, newValue in
            guard isUserScrubbing else { return }
            let time = CMTime(seconds: duration.seconds * newValue, preferredTimescale: 600)
            Task { await playerController.seek(to: time) }
        }
        .task {
            await loadVideo()
        }
    }

    // MARK: - Drawing Overlay

    @ViewBuilder
    private func redactionOverlay(viewSize: CGSize) -> some View {
        let vRect = videoRect(in: viewSize)
        let currentTime = playerController.currentTime
        let activeRegions = regions.filter { $0.isActive(at: currentTime) }

        Canvas { context, size in
            // Draw active regions
            for region in activeRegions {
                let displayRect = denormalize(region.rect, in: vRect)
                let path = Path(displayRect)

                let fillColor: Color = region.style == .blur ? .blue : .black
                let isSelected = selectedRegionID == region.id
                let strokeColor: Color = isSelected ? .yellow : .red
                let lineWidth: CGFloat = isSelected ? 3 : 2

                context.fill(path, with: .color(fillColor.opacity(0.25)))
                context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

                // Label
                let label = region.style == .blur ? "Blur" : "Black"
                context.draw(
                    Text(label).font(.caption2).foregroundStyle(.white),
                    at: CGPoint(x: displayRect.midX, y: displayRect.midY)
                )

                // Draw resize handles for selected region
                if isSelected {
                    let handleSize: CGFloat = 8
                    let corners = [
                        CGPoint(x: displayRect.minX, y: displayRect.minY),
                        CGPoint(x: displayRect.maxX, y: displayRect.minY),
                        CGPoint(x: displayRect.minX, y: displayRect.maxY),
                        CGPoint(x: displayRect.maxX, y: displayRect.maxY),
                    ]
                    for corner in corners {
                        let handleRect = CGRect(
                            x: corner.x - handleSize / 2,
                            y: corner.y - handleSize / 2,
                            width: handleSize,
                            height: handleSize
                        )
                        context.fill(Path(handleRect), with: .color(.white))
                        context.stroke(Path(handleRect), with: .color(.yellow), lineWidth: 1.5)
                    }
                }
            }

            // Draw current drag rectangle
            if let start = dragStart, let current = dragCurrent {
                let rect = rectFromPoints(start, current)
                let path = Path(rect)
                context.fill(path, with: .color(.red.opacity(0.15)))
                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    playerController.pause()
                    
                    // Determine interaction mode on first change
                    if interactionMode == .none {
                        let startPt = value.startLocation
                        let handleRadius: CGFloat = 10
                        
                        // Hit test active regions (reverse order for z-ordering)
                        var hitRegion = false
                        for region in activeRegions.reversed() {
                            let displayRect = denormalize(region.rect, in: vRect)
                            
                            // Check 4 corner handles for resize
                            let normRect = region.rect
                            let cornerMap: [(CGPoint, CGPoint)] = [
                                // (display corner, normalized anchor = opposite corner)
                                (CGPoint(x: displayRect.minX, y: displayRect.minY),
                                 CGPoint(x: normRect.maxX, y: normRect.maxY)),
                                (CGPoint(x: displayRect.maxX, y: displayRect.minY),
                                 CGPoint(x: normRect.minX, y: normRect.maxY)),
                                (CGPoint(x: displayRect.minX, y: displayRect.maxY),
                                 CGPoint(x: normRect.maxX, y: normRect.minY)),
                                (CGPoint(x: displayRect.maxX, y: displayRect.maxY),
                                 CGPoint(x: normRect.minX, y: normRect.minY)),
                            ]
                            
                            var hitCorner = false
                            for (cornerPt, anchor) in cornerMap {
                                if hypot(startPt.x - cornerPt.x, startPt.y - cornerPt.y) < handleRadius {
                                    resizeAnchor = anchor
                                    interactionMode = .resizing(region.id)
                                    selectedRegionID = region.id
                                    hitCorner = true
                                    break
                                }
                            }
                            if hitCorner { hitRegion = true; break }
                            
                            // Check body for move
                            if displayRect.contains(startPt) {
                                let normStart = CGPoint(
                                    x: (startPt.x - vRect.minX) / vRect.width,
                                    y: (startPt.y - vRect.minY) / vRect.height
                                )
                                moveOffset = CGSize(
                                    width: normStart.x - region.rect.origin.x,
                                    height: normStart.y - region.rect.origin.y
                                )
                                interactionMode = .moving(region.id)
                                selectedRegionID = region.id
                                hitRegion = true
                                break
                            }
                        }
                        
                        if !hitRegion {
                            interactionMode = .creating
                            dragStart = value.startLocation
                        }
                    }
                    
                    // Handle ongoing gesture
                    let normPoint = CGPoint(
                        x: (value.location.x - vRect.minX) / vRect.width,
                        y: (value.location.y - vRect.minY) / vRect.height
                    )
                    
                    switch interactionMode {
                    case .creating:
                        dragCurrent = value.location
                        
                    case .moving(let id):
                        guard let idx = regions.firstIndex(where: { $0.id == id }) else { return }
                        let newOriginX = normPoint.x - moveOffset.width
                        let newOriginY = normPoint.y - moveOffset.height
                        var newRect = regions[idx].rect
                        newRect.origin.x = max(0, min(1 - newRect.width, newOriginX))
                        newRect.origin.y = max(0, min(1 - newRect.height, newOriginY))
                        regions[idx].rect = newRect
                        
                    case .resizing(let id):
                        guard let idx = regions.firstIndex(where: { $0.id == id }) else { return }
                        let clampedPt = CGPoint(
                            x: max(0, min(1, normPoint.x)),
                            y: max(0, min(1, normPoint.y))
                        )
                        let newRect = CGRect(
                            x: min(resizeAnchor.x, clampedPt.x),
                            y: min(resizeAnchor.y, clampedPt.y),
                            width: abs(clampedPt.x - resizeAnchor.x),
                            height: abs(clampedPt.y - resizeAnchor.y)
                        )
                        if newRect.width > 0.01, newRect.height > 0.01 {
                            regions[idx].rect = newRect
                        }
                        
                    case .none:
                        break
                    }
                }
                .onEnded { value in
                    if case .creating = interactionMode {
                        guard let start = dragStart else {
                            interactionMode = .none
                            return
                        }
                        if let normalizedRect = toNormalized(
                            from: start, to: value.location, videoRect: vRect
                        ) {
                            addRegion(rect: normalizedRect)
                        }
                        dragStart = nil
                        dragCurrent = nil
                    }
                    
                    interactionMode = .none
                    moveOffset = .zero
                }
        )
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                playerController.togglePlayPause()
            } label: {
                Image(systemName: playerController.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .help(playerController.isPlaying ? "Pause" : "Play")

            Button {
                playerController.stepBackward()
            } label: {
                Image(systemName: "backward.frame.fill")
            }
            .buttonStyle(.plain)
            .help("Step Backward")

            Button {
                playerController.stepForward()
            } label: {
                Image(systemName: "forward.frame.fill")
            }
            .buttonStyle(.plain)
            .help("Step Forward")

            Text(formatTime(playerController.currentTime))
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .frame(width: 50, alignment: .trailing)

            Slider(value: $scrubberValue, in: 0...1) { editing in
                isUserScrubbing = editing
                if editing { playerController.pause() }
            }

            Text(formatTime(duration))
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
        }
    }

    // MARK: - Region List

    private var regionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Redaction Regions")
                    .font(.headline)
                Spacer()
                Text("Draw rectangles on the video to mark areas for redaction")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if regions.isEmpty {
                Text("No redactions added yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(regions) { region in
                            let index = (regions.firstIndex(where: { $0.id == region.id }) ?? 0) + 1
                            RedactionRegionRow(
                                region: bindingForRegion(id: region.id),
                                index: index,
                                isSelected: selectedRegionID == region.id,
                                currentTime: playerController.currentTime,
                                onSelect: { selectedRegionID = region.id },
                                onDelete: { regions.removeAll { $0.id == region.id } },
                                onSeekTo: { time in seekTo(time) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Apply Redactions") {
                playerController.pause()
                onApply(regions)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(regions.isEmpty)
        }
    }

    // MARK: - Helpers

    private func addRegion(rect: CGRect) {
        guard rect.width > 0.01, rect.height > 0.01 else { return }

        let currentTime = playerController.currentTime
        let defaultEnd = CMTimeAdd(currentTime, CMTime(seconds: 5, preferredTimescale: 600))
        let endTime = duration.seconds > 0 ? CMTimeMinimum(defaultEnd, duration) : defaultEnd

        let region = RedactionRegion(
            rect: rect,
            startTime: currentTime,
            endTime: endTime
        )
        regions.append(region)
        selectedRegionID = region.id
    }

    private func seekTo(_ time: CMTime) {
        playerController.pause()
        isUserScrubbing = false
        scrubberValue = duration.seconds > 0 ? time.seconds / duration.seconds : 0
        Task { await playerController.seek(to: time) }
    }

    private func loadVideo() async {
        playerController.load(url: videoURL)
        let asset = AVURLAsset(url: videoURL)
        if let dur = try? await asset.load(.duration) {
            duration = dur
        }
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let size = try? await track.load(.naturalSize) {
            videoNaturalSize = size
        }
    }

    private func bindingForRegion(id: UUID) -> Binding<RedactionRegion> {
        Binding(
            get: { regions.first { $0.id == id } ?? RedactionRegion(rect: .zero, startTime: .zero, endTime: .zero) },
            set: { newValue in
                if let index = regions.firstIndex(where: { $0.id == id }) {
                    regions[index] = newValue
                }
            }
        )
    }

    // MARK: - Coordinate Conversion

    private func videoRect(in viewSize: CGSize) -> CGRect {
        let videoAspect = videoNaturalSize.width / max(videoNaturalSize.height, 1)
        let viewAspect = viewSize.width / max(viewSize.height, 1)

        if videoAspect > viewAspect {
            let height = viewSize.width / videoAspect
            let y = (viewSize.height - height) / 2
            return CGRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            let width = viewSize.height * videoAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: viewSize.height)
        }
    }

    private func toNormalized(from: CGPoint, to: CGPoint, videoRect: CGRect) -> CGRect? {
        let rawRect = rectFromPoints(from, to)
        let clipped = rawRect.intersection(videoRect)
        guard !clipped.isNull, clipped.width > 5, clipped.height > 5 else { return nil }

        return CGRect(
            x: (clipped.minX - videoRect.minX) / videoRect.width,
            y: (clipped.minY - videoRect.minY) / videoRect.height,
            width: clipped.width / videoRect.width,
            height: clipped.height / videoRect.height
        )
    }

    private func denormalize(_ rect: CGRect, in videoRect: CGRect) -> CGRect {
        CGRect(
            x: videoRect.minX + rect.origin.x * videoRect.width,
            y: videoRect.minY + rect.origin.y * videoRect.height,
            width: rect.width * videoRect.width,
            height: rect.height * videoRect.height
        )
    }

    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }

    private func formatTime(_ time: CMTime) -> String {
        guard time.isValid && !time.isIndefinite else { return "0:00" }
        let totalSeconds = Int(time.seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Region Row

private struct RedactionRegionRow: View {
    @Binding var region: RedactionRegion
    let index: Int
    let isSelected: Bool
    let currentTime: CMTime
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onSeekTo: (CMTime) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(index)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 30)

            // Start time
            HStack(spacing: 4) {
                Text("Start:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatTime(region.startTime))
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                Button("Set") {
                    region.startTime = currentTime
                }
                .controlSize(.mini)
                Button {
                    onSeekTo(region.startTime)
                } label: {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Jump to start time")
            }

            // End time
            HStack(spacing: 4) {
                Text("End:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatTime(region.endTime))
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                Button("Set") {
                    region.endTime = currentTime
                }
                .controlSize(.mini)
                Button {
                    onSeekTo(region.endTime)
                } label: {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Jump to end time")
            }

            Spacer()

            // Style picker
            Picker("", selection: $region.style) {
                ForEach(RedactionRegion.Style.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            // Delete
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete redaction")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }

    private func formatTime(_ time: CMTime) -> String {
        guard time.isValid && !time.isIndefinite else { return "0:00" }
        let totalSeconds = Int(time.seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
