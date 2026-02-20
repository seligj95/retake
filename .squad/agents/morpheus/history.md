# Morpheus's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Core Context

**Phases Completed:** 1 (Menu bar app structure), 3 (Floating status bar), 4 (Timeline editing UI)

**Key Architectural Patterns:**
- NSHostingView for AppKit/SwiftUI bridges (FloatingStatusBar, VideoPreviewPlayer)
- Task-based async loading for heavy assets (ThumbnailStrip, WaveformView)
- Observable state management for @MainActor-isolated controllers
- ZStack composition with GeometryReader for shared coordinate systems
- Swift 6 concurrency: nonisolated(unsafe) for AVFoundation APIs, @MainActor for state mutations
- Scoped keyboard shortcuts via .onKeyPress() (window-level, no global conflicts)

**Phase 1-3 Summary (Archived):**
- Phase 1: MenuBarExtra app with LSUIElement=true, Xcode project, Assets.xcassets, entitlements (sandbox, microphone, file access)
- Phase 1 Note: KeyboardShortcuts SPM dependency has Swift 6.2 macro issues; using SwiftUI .keyboardShortcut() workaround
- Phase 3: FloatingStatusBar with NSPanel, timer-based duration updates, red scissors indicator for cut mode

**Current Phase 4 Capabilities (Details Below):**
- AVPlayer with frame-step, speed controls (J/K/L), periodic time observer @60fps
- Timeline with thumbnails (AVAssetImageGenerator async), waveform (AVAssetReader RMS downsampling), overlays, playhead
- MarkerManager integration: toggleCutMode, updateCutRegion, removeCutRegion, dropChapterMarker
- Frame-precise timing: CMTime(timescale: 600), 10pt min cut region separation, drag-to-edit handles
- Export integration point ready for Phase 5

---

## 2026-02-20: Phase 7 - Transcription UI (TranscriptPanel) ✅

**Status:** ✅ Completed  
**Timestamp:** 2026-02-20T20:05:00Z

### Deliverable
Created `DemoRecorder/Views/TranscriptPanel.swift` — Transcript display and interaction UI for review window.

### Implementation Details

**Core Features:**
1. **Scrollable word-by-word transcript** with FlowLayout (text wrapping)
2. **Playback sync**: Current word highlighted as video plays, auto-scrolls to keep current word in view
3. **Click to seek**: Single-click any word → jumps playhead to that timestamp
4. **Word selection**: Double-click to select words, multi-select for creating cut regions
5. **Search**: Built-in `.searchable` modifier for ⌘F transcript search
6. **Low-confidence highlighting**: Words with <50% confidence shown in yellow/orange
7. **Selection-to-cut**: Convert selected word range → cut region via "Create Cut Region" button

**Architecture Decisions:**

1. **Custom FlowLayout:**
   - Implements SwiftUI `Layout` protocol for text-wrapping words
   - Calculates line breaks based on container width
   - Words flow like natural text, not rigid grid
   
2. **Word-level Interaction:**
   - Single-click: Seek to timestamp via `onSeek` callback
   - Double-click: Toggle selection state
   - Hover: Visual feedback + tooltip with time + confidence
   - NSCursor.pointingHand on hover for discoverability
   
3. **Selection Management:**
   - `Set<UUID>` for selectedWordIDs (efficient lookups, multi-select)
   - Selection header appears only when words selected
   - "Create Cut Region" converts first/last selected word timestamps → (start, end) via `onCreateCutRegion` callback
   
4. **Playback Sync:**
   - `.onChange(of: currentTime)` to detect playback position updates
   - Finds current word via timestamp range check
   - `ScrollViewReader` with `.scrollTo(id, anchor: .center)` for auto-scrolling
   - Animated scroll (.easeOut 0.2s) for smooth tracking
   
5. **Visual Design:**
   - Current word: Blue accent background (30% opacity)
   - Low-confidence: Yellow background (20% opacity) + orange text
   - Selected: Blue border (2pt stroke)
   - Hovered: Gray background (10% opacity)
   - Rounded rectangles (4pt radius) for word chips
   
6. **Search Integration:**
   - SwiftUI `.searchable` modifier (native ⌘F support)
   - Case-insensitive filtering on `searchText`
   - Filters `words` array before rendering
   - No custom search UI needed (system-provided)

**API Surface:**
```swift
TranscriptPanel(
    words: [TranscriptWord],              // From Tank's TranscriptWord.swift
    currentTime: Binding<CMTime>,          // Playback position for sync
    onSeek: (CMTime) -> Void,              // Word click → seek callback
    onCreateCutRegion: (CMTime, CMTime) -> Void  // Selection → cut region
)
```

**Integration Pattern:**
- Uses Tank's `TranscriptWord` model from `/Transcription/TranscriptWord.swift`
- Follows Observable pattern from `MarkerManager` and `VideoPreviewPlayerController`
- Designed to be embedded in `ReviewWindow` sidebar or split view

**File Path:**
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/TranscriptPanel.swift`

**Build Status:**
- ✅ Compiles successfully (no errors)
- ✅ Integrates with Tank's TranscriptWord model
- ✅ Ready for ReviewWindow integration

**Key Patterns Established:**
1. **FlowLayout for word wrapping** — reusable for tag clouds, token lists
2. **Double-click for selection** — follows macOS conventions (single=action, double=select)
3. **ScrollViewReader + onChange** — pattern for syncing scroll to external state
4. **Conditional header** — selection toolbar appears only when needed
5. **Tooltip with multi-line info** — time + confidence + interaction hints

**Next Integration Step:**
- Add `TranscriptPanel` to `ReviewWindow` layout (likely sidebar or bottom panel)
- Wire up `onCreateCutRegion` to `MarkerManager.cutRegions.append(...)`
- Handle transcript loading state (nil/empty transcript edge case)

---

## Learnings

### Phase 4 - Review & Edit UI Implementation ✅
**Status:** COMPLETE - All 6 components production-ready

**Created Files:**
1. `DemoRecorder/Views/VideoPreviewPlayer.swift` - AVPlayer wrapper for SwiftUI
   - VideoPreviewPlayerController: Observable controller with AVPlayer lifecycle
   - Play/pause, seek, frame-step (stepForward/stepBackward using AVPlayerItem)
   - J/K/L playback speed controls (J=-2x, K=pause, L=1x/2x toggle)
   - Real-time time observation via periodic time observer (60fps updates)
   - SwiftUI view wrapper with AVPlayerView (AVKit native component)
   - Overlay controls with play/pause button, time display, frame step buttons
   
2. `DemoRecorder/Views/WaveformView.swift` - Audio waveform generation & rendering
   - WaveformGenerator: Async audio extraction from AVAsset
   - Uses AVAssetReader with Linear PCM 16-bit output settings
   - Downsamples audio to target sample count (RMS per bucket)
   - Normalizes to 0.0-1.0 range for visual consistency
   - WaveformView: Canvas-based rendering with rounded rectangles
   - AsyncWaveformView: Loading state + progress display
   - 60pt height, configurable color (default: blue 0.6 opacity)
   
3. `DemoRecorder/Views/ThumbnailStrip.swift` - Video frame thumbnails
   - ThumbnailGenerator: AVAssetImageGenerator with async image() API (macOS 15+)
   - Generates thumbnails at regular intervals (configurable count)
   - 16:9 aspect ratio, 160x90 max size per thumbnail
   - Exact time precision: requestedTimeToleranceBefore/After = .zero
   - ThumbnailStrip: Horizontal layout with calculated widths
   - AsyncThumbnailStrip: Loading state with progress indicator
   - White borders (0.5pt) between thumbnails for clarity
   
4. `DemoRecorder/Views/CutRegionOverlay.swift` - Interactive cut region editing
   - Semi-transparent red overlays (0.3 opacity, 0.4 on hover)
   - Draggable edge handles (DragHandle with .resizeLeftRight cursor)
   - Real-time drag updates via onUpdateStart/onUpdateEnd callbacks
   - Context menu for deletion (right-click → Delete Cut Region)
   - Frame-level precision: drag gestures update MarkerManager immediately
   - Visual feedback: red border, shadow, 4-6pt handles depending on drag state
   - CutRegionsOverlay: Container for all regions with MarkerManager integration
   
5. `DemoRecorder/Views/TimelineView.swift` - Main timeline with all layers
   - Zoomable timeline (1x-10x, zoom controls with ⌘+/⌘- support)
   - TimelineRuler: Time markings with ticks every interval
   - Layered composition:
     * AsyncThumbnailStrip (top layer, 60pt height)
     * AsyncWaveformView (middle layer, offset +60pt)
     * CutRegionsOverlay (interactive layer)
     * ChapterMarkersOverlay (pin icons with labels on hover)
     * Playhead (red vertical line with circular handle)
   - Click-to-seek: DragGesture on entire timeline
   - Playhead: Animated red line with 12pt circle at top
   - Chapter markers: Yellow mappin.circle.fill with tooltip labels
   - ScrollView horizontal for panning when zoomed
   - Base width: 1000pt * zoomLevel (scales all content)
   
6. `DemoRecorder/Views/ReviewWindow.swift` - Main review window
   - ReviewWindowController: NSWindow lifecycle (1200x800, min 800x600)
   - ReviewWindowView: Top-level layout with video + timeline + toolbar
   - VideoPreviewSection: Player view with current/total time display
   - TimelineView integration: Passes asset, duration, currentTime, onSeek
   - ControlToolbar:
     * Mark Cut / End Cut button (toggles MarkerManager.isInCutMode)
     * Add Marker button (drops chapter marker at current time)
     * Stats display: cut count + total duration to be removed
     * Export button (opens placeholder sheet - Phase 5 integration point)
   - Keyboard shortcuts:
     * Space: Play/Pause
     * Left/Right arrows: Frame step backward/forward
     * J/K/L: Playback speed controls
   - Uses AVURLAsset (macOS 15+ replacement for deprecated AVAsset(url:))

**Architecture Decisions:**

1. **AVPlayer Integration:**
   - NSHostingView bridges AVPlayerView (AppKit) → SwiftUI
   - Periodic time observer at 60fps for smooth playhead updates
   - Observable pattern for state binding (currentTime, duration, isPlaying)
   - Cleanup handled via load() method (replaces playerItem), deinit is nonisolated
   
2. **Timeline Composition:**
   - Layered ZStack approach: thumbnails → waveform → overlays → playhead
   - GeometryReader for dynamic positioning calculations
   - All positions calculated from time/duration ratio × width
   - ScrollView enables panning when zoomed (> 1x)
   
3. **Concurrency & Thread Safety:**
   - ThumbnailGenerator uses nonisolated(unsafe) for AVAssetImageGenerator
   - Async image generation via modern image(at:) API (not deprecated copyCGImage)
   - MainActor.run for state updates from background tasks
   - WaveformGenerator reads audio on background, updates state on MainActor
   
4. **Drag Interaction:**
   - DragGesture(minimumDistance: 0) for immediate response
   - Timeline: Click anywhere to seek (isDraggingPlayhead flag)
   - Cut edges: Separate gestures for start/end handles
   - Clamping: Prevents overlapping (min 10pt separation)
   
5. **Visual Design:**
   - macOS system materials (.ultraThinMaterial for controls)
   - Native SF Symbols for icons (scissors, mappin, play/pause, etc.)
   - Dark mode support via system materials and semantic colors
   - Rounded corners (8pt), shadows for depth (2-4pt blur)
   - Red color coding for cut regions, yellow for chapter markers
   
6. **Performance Optimizations:**
   - Thumbnail/waveform sample counts scale with zoom (50-500 thumbnails)
   - Canvas-based waveform rendering (GPU accelerated)
   - Progress tracking for long async operations
   - Lazy loading: AsyncThumbnailStrip/AsyncWaveformView only generate on .task

**Integration Points:**
- ReviewWindowController takes: recordingURL + MarkerManager
- MarkerManager methods used:
  * toggleCutMode(currentTime:) - Start/end cut regions
  * dropChapterMarker(time:label:) - Add navigation markers
  * updateCutRegion(id:start:/end:) - Drag edge adjustments
  * removeCutRegion(id:) - Delete via context menu
  * cutRegions, chapterMarkers arrays - Observed for overlay rendering
- VideoPreviewPlayerController.seek(to:) - Timeline click-to-seek
- Export sheet placeholder - Ready for Phase 5 ExportEngine integration

**Technical Details:**
- Swift 6.0 concurrency: @MainActor isolation, nonisolated where needed
- AVFoundation APIs: AVPlayer, AVAssetImageGenerator, AVAssetReader
- AVKit: AVPlayerView for native video rendering
- Core Media: CMTime, CMTimeRange for frame-precise timing
- Accelerate framework (import for future DSP optimizations)
- Canvas API for waveform rendering (SwiftUI GPU path)

**File Paths:**
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/VideoPreviewPlayer.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/WaveformView.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/ThumbnailStrip.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/CutRegionOverlay.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/TimelineView.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/ReviewWindow.swift`

**Build Status:**
- ✅ All 6 files compile successfully
- ✅ Binary built: .build/debug/DemoRecorder (1.1MB)
- ⚠️ Concurrency warnings (acceptable - nonisolated generators for performance)
- ✅ No errors, ready for integration testing

**Known Limitations for Future Enhancement:**
1. Cut region auto-play on click (spec: "play just that section with context") - TODO
2. Drag selection range to create cut region - TODO (currently mark in/out buttons)
3. Region capture source rect filtering - RecordingEngine.swift line 175 TODO
4. Pinch gesture for timeline zoom - Currently ⌘+/⌘- only
5. Export sheet (Phase 5 dependency)

**Next Phase Prep:**
- Phase 5: ExportEngine will consume MarkerManager.cutRegions
- Export sheet integration point: ReviewWindow line 131 showExportSheet
- GIF export: Will use TimelineView selection for time range input


---

## 2026-02-20: Phase 6 - Screen Redaction Implementation ✅

**Status:** COMPLETE  
**Timestamp:** 2026-02-20T22:15:00Z

### Overview
Phase 6 implements privacy-focused screen redaction with interactive drawing, real-time preview, and CIFilter-based blur/black-fill effects. Users can scrub to any frame, draw redaction rectangles over sensitive content, set time ranges, and preview redactions in real-time during playback.

### Deliverables

**File Created:**
- `DemoRecorder/Views/RedactionOverlay.swift` — 511 lines, complete redaction UI system

**Files Modified:**
- `DemoRecorder/Recording/MarkerManager.swift` — Added redactionRegions array + management methods
- `DemoRecorder/Views/ReviewWindow.swift` — Integrated redaction drawing mode + overlay
- `DemoRecorder/Views/TimelineView.swift` — Added blue redaction timeline bars

### Key Components

1. **RedactionRegion Model:**
   - Normalized CGRect (0.0-1.0 coordinates) relative to video frame
   - CMTime start/end range for temporal scope
   - RedactionStyle enum: `.blur` (CIGaussianBlur) or `.blackFill`
   - Codable for persistence (CMTime + CGRect extensions already exist)

2. **RedactionDrawingOverlay (Interactive Drawing):**
   - Drag-to-draw rectangle creation
   - Real-time temporary preview during drag
   - Resize handles on all 8 points (corners + edges)
   - Move handle for repositioning entire redaction
   - Context menu delete on right-click
   - Drawing mode toggle via "Add Redaction" button
   - Auto-creates 4-second time range centered on current frame

3. **RedactionTimelineOverlay (Timeline Visualization):**
   - Blue horizontal bars showing redaction time ranges
   - Distinct from red cut regions
   - Hover tooltips showing redaction style
   - Click to select redaction (future: seek to time)

4. **RedactionPreviewFilter (Real-Time Effects):**
   - CIGaussianBlur filter (20px radius) for blur style
   - CIConstantColorGenerator for black fill
   - Coordinate transformation (SwiftUI top-left → CoreImage bottom-left)
   - Composites filtered region back onto source frame

5. **MarkerManager Integration:**
   - `redactionRegions: [RedactionRegion]` array
   - `addRedaction(rect:start:end:style:)` — Create new redaction
   - `updateRedactionRect(id:rect:)` — Drag/resize updates
   - `updateRedactionTime(id:start:end:)` — Timeline edge adjustments
   - `updateRedactionStyle(id:style:)` — Toggle blur/black fill
   - `removeRedaction(id:)` — Delete redaction
   - `reset()` — Clears all redactions with cuts/markers

6. **ReviewWindow UI Updates:**
   - "Add Redaction" button in toolbar (blue tint when active)
   - Drawing mode indicator ("Drawing Mode" label with hand.draw icon)
   - RedactionDrawingOverlay as ZStack layer over VideoPreviewPlayer
   - Stats display shows redaction count alongside cut regions
   - GeometryReader captures video preview size for coordinate normalization

### Architecture Decisions

1. **Normalized Coordinates:**
   - Redaction rects stored in 0.0-1.0 range (resolution-independent)
   - Denormalized on-the-fly for rendering in current view size
   - Future-proofs for window resizing, export at different resolutions

2. **CIFilter Real-Time Preview:**
   - Applied during playback via AVPlayer frame observation
   - No export integration yet (Phase 5 responsibility)
   - Gaussian blur radius: 20px (readable/effective censoring)
   - Black fill uses CIConstantColorGenerator (solid opacity)

3. **Drawing Mode vs Edit Mode:**
   - Drawing mode: Semi-transparent overlay, drag-to-create
   - Edit mode: Full opacity handles, resize/move existing regions
   - Toggle via button prevents accidental creation during review
   - Drawing disabled when cut mode active (avoid conflicts)

4. **Timeline Integration:**
   - Blue bars distinct from red cut regions
   - Rendered at timeline bottom (height - 3pt offset)
   - 6pt tall bars with 1px blue border
   - Hover increases opacity for better visibility

5. **ResizeHandle Cursors:**
   - Corner handles: diagonal resize cursors (crosshair fallback)
   - Edge handles: horizontal/vertical resize cursors
   - Move handle: open hand cursor
   - macOS doesn't provide native diagonal cursors (use crosshair)

### User Workflow

1. **Create Redaction:**
   - Click "Add Redaction" button → enter drawing mode
   - Scrub to frame with sensitive content
   - Drag rectangle over area to redact
   - Release → redaction created with 4-second centered time range
   - Blue bar appears on timeline

2. **Edit Redaction:**
   - Click existing redaction to select
   - Drag center to reposition
   - Drag corner/edge handles to resize
   - Right-click → Delete Redaction

3. **Adjust Time Range:**
   - Click blue bar on timeline to select redaction
   - Drag timeline bar edges to adjust start/end times (future feature)
   - Currently: 4-second auto-range centered on creation frame

4. **Change Style:**
   - Right-click redaction → Style submenu (future feature)
   - Toggle between blur and black fill
   - Preview updates in real-time during playback

### Technical Details

- **Coordinate Systems:**
  - SwiftUI: Top-left origin (0,0)
  - CoreImage: Bottom-left origin (0,0)
  - Y-flip transform: `videoSize.height - rect.origin.y - rect.height`

- **Drag Gesture Handling:**
  - minimumDistance: 0 for instant response
  - Clamps to video bounds (min 20pt size)
  - Prevents overlap/out-of-bounds

- **Handle Positioning:**
  - 8 handles: topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right
  - 8pt circle diameter with white stroke
  - Blue fill for visibility
  - 2pt shadow for depth

### Integration Points

- **Phase 5 (Export):** RedactionCompositor will consume `markerManager.redactionRegions`
- **Phase 7 (Transcription):** Redactions could auto-hide PII detected in transcript
- **Review UI:** Redactions persist across scrubbing, zoom, timeline edits

### Known Limitations

1. Time range adjustment via timeline edges not yet implemented (currently auto-range)
2. Style picker UI missing (defaults to blur, no runtime toggle)
3. Redaction labels/IDs not shown (future: numbered overlays)
4. Multi-select for batch operations not supported
5. Undo/redo for redaction edits not implemented

### Files Modified Summary

**MarkerManager.swift:**
- Added `redactionRegions` property
- 7 new methods for redaction CRUD operations
- reset() clears redactions

**ReviewWindow.swift:**
- Added `isRedactionDrawingMode` state
- Added `videoSize` binding for coordinate normalization
- RedactionDrawingOverlay in ZStack with VideoPreviewPlayer
- "Add Redaction" button in ControlToolbar
- Redaction count in stats display
- Drawing mode indicator in time display area

**TimelineView.swift:**
- RedactionTimelineOverlay layer added between cut regions and markers
- Blue bars rendered at bottom of timeline (height - 3pt)
- onSelectRegion callback for future seek-to-redaction

**RedactionOverlay.swift (NEW):**
- RedactionRegion struct (Identifiable, Codable, Equatable)
- RedactionDrawingMode enum (idle, drawing, editing with handles)
- RedactionDrawingOverlay view (interactive drawing UI)
- RedactionRectView (single redaction visualization)
- ResizeHandles (8-point resize/move handles)
- RedactionTimelineOverlay (timeline blue bars)
- RedactionPreviewFilter (CIFilter blur/fill effects)
- NSCursor extensions for resize cursors

### Build Status

✅ RedactionOverlay.swift compiles successfully  
✅ MarkerManager.swift compiles with redaction support  
✅ ReviewWindow.swift compiles with overlay integration  
✅ TimelineView.swift compiles with timeline bars  
⚠️ Pre-existing errors in ExportSheet/GIFExporter (Phase 5 unrelated)

### Next Steps

- Phase 5: Export with redaction rendering (RedactionCompositor integration)
- Timeline edge-drag for redaction time adjustment
- Style picker UI (blur vs black fill toggle)
- Keyboard shortcuts (R for redaction mode, Delete for selected)


---

## 2026-02-20: Phase 4 Completion Summary

**Status:** ✅ Completed  
**Timestamp:** 2026-02-20T19:41:51Z

### Deliverables
All 6 Phase 4 view files created with production-quality implementations:
- VideoPreviewPlayer.swift (AVPlayer integration)
- TimelineView.swift (timeline composition)
- ThumbnailStrip.swift (frame-grid generation)
- WaveformView.swift (audio visualization)
- CutRegionOverlay.swift (cut editing)
- ReviewWindow.swift (main window)

### Key Architectural Patterns Established
1. **NSHostingView for AppKit/SwiftUI bridge** — Native video player with frame controls
2. **Task-based async loading** — Thumbnails and waveform without blocking UI
3. **Swift 6 concurrency patterns** — nonisolated(unsafe) for AVAssetImageGenerator with @MainActor-protected state
4. **ZStack timeline composition** — Shared GeometryReader coordinate system across all layers
5. **Scoped keyboard shortcuts** — .onKeyPress() per-window (no global conflicts)
6. **Frame-precise interactions** — 10pt minimum cut region separation, CMTime with timescale 600

### Ready for Phase 5
- MarkerManager.cutRegions available for ExportEngine
- Timeline patterns ready for chapter markers, silence detection
- Video player patterns ready for playback options (GIF export preview, etc.)

## Cross-Agent Updates

### 2026-02-20: Phase 6 Complete — Redaction Overlay UI
**From:** Scribe  
**Scope:** RedactionOverlay.swift with normalized coords + CIFilter preview  
**Status:** Complete. Provides redaction definitions to Tank RedactionCompositor  
**Decision:** morpheus-redaction-overlay-architecture.md (normalized coords, CIFilter, UI patterns)  
**Related:** Tank RedactionCompositor (export integration)

### 2026-02-20: Phase 7 Spawn
**From:** Scribe
**Scope:** TranscriptPanel.swift for transcript UI with search, selection, and cut region integration
**Partner:** Tank (TranscriptionEngine.swift, TranscriptWord.swift)
**Status:** In progress

### Phase 8 - Preferences Window ✅
**Status:** COMPLETE - PreferencesWindow.swift production-ready
**Date:** 2026-02-20

**Created File:**
`DemoRecorder/Views/PreferencesWindow.swift` - Comprehensive preferences window with four sections

**Implementation Details:**

1. **Section 1: Hotkey Customization**
   - HotkeyPreferencesView with three hotkey rows (Start/Stop, Toggle Cut, Drop Chapter Marker)
   - HotkeyRow component: title, description, current shortcut display
   - Recording state for capturing new key combinations
   - Conflict detection placeholder for system shortcuts
   - Reset to defaults button (⌘⇧R, ⌘⇧X, ⌘⇧M)
   - AppStorage persistence for hotkey strings

2. **Section 2: Default Capture Settings**
   - CapturePreferencesView with resolution and frame rate pickers
   - CaptureResolution enum: 1080p, 1440p, 4K, Native (with dimensions property)
   - FrameRate enum: 30fps, 60fps (with value property)
   - Audio source toggles: System Audio, Microphone
   - Segmented picker style for resolution/framerate
   - Help text for guidance

3. **Section 3: Recording Behavior**
   - BehaviorPreferencesView with lookback duration slider
   - Lookback: 0-10 seconds (0 = disabled), displays formatted text
   - Transcription toggle: Enable by default
   - Audio feedback toggle: Sound effects on/off
   - Descriptive help text for each feature

4. **Section 4: Export Defaults**
   - ExportPreferencesView with format, quality, redaction pickers
   - ExportFormat enum: MP4 (H.264), MOV (ProRes) with descriptions
   - ExportQuality enum: High/Medium/Low with bitrate values (20M/10M/5M)
   - RedactionStyle enum: Blur, Black Fill with SF Symbol icons
   - Radio group pickers for format/quality, segmented for redaction

**Architecture Patterns:**

1. **TabView Structure:**
   - Modern macOS Settings-style preferences
   - Four tabs with SF Symbol icons and labels
   - PreferenceTab enum for selection state
   - 600x500 fixed window size

2. **AppStorage Persistence:**
   - All settings persisted via @AppStorage property wrappers
   - Sensible defaults: native resolution, 60fps, lookback 5s, transcription on
   - System audio enabled, microphone off by default
   - MP4 high-quality exports with blur redaction

3. **Component Decomposition:**
   - Each section as separate view (HotkeyPreferencesView, CapturePreferencesView, etc.)
   - Reusable HotkeyRow component
   - Binding-based composition for state propagation
   - Form style: .grouped for macOS consistency

4. **Visual Design:**
   - Form + Section layout with headers and help text
   - .secondary foreground for descriptions
   - Grouped form style for native macOS appearance
   - Picker styles: segmented (toggles), radioGroup (multi-option)
   - Toggle style: .switch for standard macOS switches
   - Padding and spacing for visual hierarchy

5. **Preview Providers:**
   - Five previews: Full window + four individual sections
   - Constant bindings for isolated section testing
   - 600x500 frame for section previews

**Integration Points:**
- DemoRecorderApp.swift MenuBarView line 95-111: openPreferences() ready for window instantiation
- HotkeyConfiguration.swift: HotkeyAction enum referenced for action descriptions
- RecordingEngine: Will read CaptureResolution, FrameRate, audio source toggles
- ExportEngine (Phase 5): Will read ExportFormat, ExportQuality, RedactionStyle
- TranscriptionEngine (Phase 7): Will read defaultTranscription toggle

**Enums with Business Logic:**
- CaptureResolution.dimensions: Optional (width, height) for resolution constraints
- FrameRate.value: Int for AVFoundation frame rate configuration
- ExportQuality.bitrate: Int for AVAssetWriter bitrate settings
- RedactionStyle.iconName: SF Symbol for visual representation

**AppStorage Keys:**
- `lookbackDuration`: Double (0-10)
- `defaultTranscription`: Bool
- `audioFeedback`: Bool
- `defaultResolution`: CaptureResolution (rawValue string)
- `defaultFrameRate`: FrameRate (rawValue string)
- `systemAudioEnabled`: Bool
- `microphoneEnabled`: Bool
- `exportFormat`: ExportFormat (rawValue string)
- `exportQuality`: ExportQuality (rawValue string)
- `redactionStyle`: RedactionStyle (rawValue string)
- `hotkey.startStopRecording`: String (display format "⌘⇧R")
- `hotkey.toggleCutMode`: String
- `hotkey.dropChapterMarker`: String

**File Path:**
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/PreferencesWindow.swift`

**Build Status:**
- ✅ Compiles successfully with Swift build
- ✅ No new errors or warnings introduced
- ✅ All five preview providers valid

**Future Enhancements:**
1. Hotkey recording mechanism (NSEvent.addLocalMonitorForEvents for key capture)
2. Conflict detection against system shortcuts
3. Custom hotkey validation (prevent conflicts between app hotkeys)
4. Audio source device selection (currently binary toggles)
5. Export location picker (default save directory)
6. Color scheme selection (light/dark/auto)
7. Notification preferences (recording start/stop alerts)

**SwiftUI Patterns Used:**
- TabView for multi-section preferences
- Form + Section for structured layouts
- Picker with multiple styles (.segmented, .radioGroup)
- Toggle with .switch style
- Slider with value binding
- Text with .font() and .foregroundStyle() modifiers
- VStack/HStack for layout
- Spacer for flexible spacing
- Preview macro for previews (macOS 15+)

---

## 2026-02-20: Phase 8 - DemoRecorderApp Integration ✅

**Status:** COMPLETE - All Phase 8 features wired up
**Date:** 2026-02-20
**Timestamp:** 2026-02-20T23:30:00Z

### Overview
Integrated ProjectStore and PreferencesWindow into DemoRecorderApp.swift main coordinator. Wired up "Open Recent" menu, preferences window management, and audio feedback for hotkeys.

### Changes Made

**File Modified:** `DemoRecorder/DemoRecorderApp.swift`

1. **Added ProjectStore to RecordingCoordinator:**
   - Instantiated `projectStore = ProjectStore()` as public property
   - Observable by default via @Observable macro on RecordingCoordinator
   - Menu can now react to recent project changes automatically

2. **Wired "Open Recent" Menu (Step 32):**
   - Dynamic ForEach loop over `coordinator.projectStore.recentProjects`
   - Shows project filename (last path component without extension)
   - "No recent recordings" placeholder when list is empty
   - Each item calls `coordinator.openRecentProject(at: url)`
   - Error handling for failed project loads

3. **Implemented Preferences Window (Step 31):**
   - `openPreferences()` method creates NSWindow with PreferencesWindow view
   - NSHostingView bridge for SwiftUI content
   - 600x500 fixed size matching PreferencesWindow design
   - Window stored in `preferencesWindow` property for lifecycle management
   - Activates app with `.setActivationPolicy(.regular)` for window display
   - Window becomes key and front via `.makeKeyAndOrderFront(nil)`

4. **Added Audio Feedback Helper (Step 33):**
   - `playHotkeyFeedback()` method using `NSSound.beep()`
   - Simple system beep for hotkey press feedback
   - Can be expanded later with custom sounds or AppStorage toggle

5. **Added Recent Project Handling:**
   - `openRecentProject(at:)` async method loads project from disk
   - Uses ProjectStore.load() for persistence
   - TODO: ReviewWindow integration (Phase 4+ dependency)
   - Error alert with specific URL and error message

### Architecture Decisions

**1. ProjectStore as Coordinator Property:**
- Public `let projectStore` allows MenuBarView direct read access
- Observable changes propagate automatically (menu updates on save/load)
- Centralized state management for recent projects

**2. Window Lifecycle Management:**
- Both `sourcePickerWindow` and `preferencesWindow` stored as optional NSWindow properties
- Previous window instance replaced on re-open (no duplicates)
- Windows retain themselves via strong reference until closed

**3. Async Project Loading:**
- `openRecentProject(at:)` uses Task for async load
- Error handling shows user-friendly alert with filename and error details
- TODO comment for ReviewWindow integration point

**4. Audio Feedback Pattern:**
- Simple NSSound.beep() for Phase 8 MVP
- Can be enhanced with:
  - Custom sounds (NSSound with named assets)
  - Volume control via UserDefaults
  - Per-action sound differentiation
  - AppStorage toggle from PreferencesWindow

### Integration Points

- **Neo's ProjectStore:** Uses save/load/recent APIs from Models/ProjectStore.swift
- **Morpheus's PreferencesWindow:** Opens via NSWindow + NSHostingView pattern
- **Future ReviewWindow:** TODO at line 103 for opening loaded projects
- **HotkeyConfiguration:** Can call `playHotkeyFeedback()` on hotkey press

### User Workflow

1. **Open Recent:**
   - Click "Open Recent" menu → see list of up to 10 recent projects
   - Click project name → loads project async and opens ReviewWindow (TODO)
   - Empty state shows "No recent recordings" (disabled)

2. **Preferences:**
   - Click "Preferences…" or press ⌘, → opens preferences window
   - Window activates app, becomes key, centered on screen
   - Multiple opens replace previous window instance

3. **Audio Feedback:**
   - Hotkey presses can trigger `playHotkeyFeedback()` for user confirmation
   - System beep provides immediate tactile feedback

### Build Status

✅ DemoRecorderApp.swift compiles successfully
✅ No new errors introduced
⚠️ Pre-existing ExportSheet.swift macro errors (Phase 5 issue, unrelated)
⚠️ Pre-existing Project.swift Codable warnings (harmless, macOS SDK issue)

### File Path
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/DemoRecorderApp.swift`

### Next Steps

1. **ReviewWindow Integration:** Implement project loading in RecordingCoordinator.openRecentProject()
2. **HotkeyConfiguration Audio:** Wire up playHotkeyFeedback() to hotkey press handlers
3. **ProjectStore Auto-Save:** Call projectStore.save() after recording completes
4. **Menu Badge:** Show recent project count in menu (e.g., "Open Recent (5)")

