# DemoRecorder Team Decisions

## Phase 2: Recording Engine Architecture
**Date:** 2026-02-20  
**Agent:** Tank (Media/AV Specialist)  
**Status:** ✅ Implemented

### ScreenCaptureKit Configuration + HEVC Codec Selection

**Context:** Recording engine requires capturing screen at high quality with minimal latency and efficient encoding.

**Decision:** Use ScreenCaptureKit with HEVC (H.265) codec at 60 FPS.

**Rationale:**
- **ScreenCaptureKit:** Modern, low-latency capture API (replaces AVScreenRecorder)
- **HEVC:** H.265 codec provides 50% better compression than H.264; essential for large screen recordings
- **60 FPS:** Captures fast UI interactions, editing operations
- **Timescale 600:** CMTime precision allows frame-accurate bracket cuts (10ms granularity = 600/60)

**Trade-offs:**
- HEVC not supported on macOS < 10.13 (acceptable for macOS 15+)
- Slightly higher CPU during encoding (mitigated by hardware acceleration)

---

## Phase 4: Review UI and Timeline
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Status:** ✅ Implemented

### Timeline ZStack Layering Pattern

**Context:** Review window displays video with overlaid editing controls (cut markers, chapter labels) without conflicting interactions.

**Decision:** Use ZStack layering: video → timeline → UI overlays, with transparent hit areas for non-interactive zones.

**Implementation:**
```swift
ZStack(alignment: .bottom) {
    VideoPlayer(...)  // Base layer
    TimelineView(...)  // Timeline with markers
    CutMarkerOverlay(...)  // Cut region highlights
    ChapterLabelOverlay(...)  // Chapter markers
    HotkeyHintOverlay(...)  // Help text
}
```

**Key Pattern:** Each overlay layer only responds to its own interaction (taps on non-markers pass through).

**Related:** Phase 3 NSPanel + NSHostingView bridge for overlay window pattern.

---

## Phase 3: SwiftUI ↔ AppKit Integration
**Date:** 2026-02-20  
**Agent:** Neo (Lead Architect)  
**Status:** ✅ Implemented

### NSPanel + NSHostingView Pattern for Overlay Integration

**Context:** DemoRecorder menu bar app needs overlays (cut markers, redaction frames) above video window without blocking SwiftUI view hierarchy.

**Decision:** Use NSPanel (floating window) + NSHostingView to embed SwiftUI views in AppKit hierarchy.

**Pattern:**
```swift
let overlayPanel = NSPanel()
overlayPanel.contentView = NSHostingView(
    rootView: RedactionDrawingOverlay(...)
)
overlayPanel.level = .floating  // Always above video
overlayPanel.isMovable = false
```

**Why NSPanel + NSHostingView:**
1. AppKit handles window layering and floating semantics
2. SwiftUI provides modern declarative UI for complex overlays
3. Maintains single SwiftUI state tree (no separate AppKit view sync issues)

**Alternatives Considered:**
- Pure SwiftUI: Overlay windows not available in macOS SwiftUI (yet)
- Pure AppKit: More verbose, less maintainable
- Separate process: Overkill, synchronization complexity

---

## Phase 5: Export Engine — Cut Region Removal
**Date:** 2026-02-20  
**Agent:** Tank (Media/AV Specialist)  
**Status:** ✅ Implemented

### AVMutableComposition with Reverse Chronological Cut Removal

**Context:** Export system removes bracket-cut regions from videos without breaking timestamps on remaining cuts.

**Decision:** Use AVMutableComposition.removeTimeRange() called in **reverse chronological order** (latest cuts first).

**Rationale:**
When removing a time range early, all subsequent timestamps shift backward (offset drift). Processing from end to start preserves validity of earlier cut timestamps.

**Example:** Cuts at [0-10s, 20-30s, 40-50s]
- Remove 40-50s: composition 0-40s, other cuts still valid ✓
- Remove 20-30s: composition 0-30s, first cut still valid ✓
- Remove 0-10s: composition 0-20s ✓

Forward order fails because first removal invalidates later cut boundaries.

**Implementation:**
```swift
let sortedCuts = cutRegions.sorted { $0.start > $1.start }
for cutRegion in sortedCuts {
    composition.removeTimeRange(CMTimeRange(start: cutRegion.start, duration: cutRegion.duration))
}
```

**Export Presets:**
- High Quality: 4K HEVC (.mov) — AVAssetExportPresetHEVC3840x2160
- Balanced: 1080p HEVC (.mp4) — AVAssetExportPresetHEVC1920x1080
- Small File: 720p HEVC (.mp4) — AVAssetExportPresetHEVC1280x720

**GIF Export:** AVAssetImageGenerator for frame extraction, CGImageDestination for animated GIF encoding.

---

## Phase 6: Redaction Compositor — Export Pattern
**Date:** 2026-02-20  
**Agent:** Tank (Media/AV Specialist)  
**Status:** ✅ Implemented

### AVVideoComposition with CIFilter Handler for Screen Redaction

**Context:** Phase 6 export requires applying redaction effects (blur or black-fill) to sensitive screen regions during video export.

**Decision:** Use **AVMutableVideoComposition** with **CIFilter handler** pattern, not pre-processing or custom compositor.

**Implementation:**
```swift
let composition = AVMutableVideoComposition(
    asset: asset,
    applyingCIFiltersWithHandler: { request in
        var outputImage = request.sourceImage.clampedToExtent()
        
        // Find active redactions at composition time
        let activeRedactions = redactionRegions.filter { $0.contains(time: request.compositionTime) }
        
        // Apply each redaction sequentially
        for redaction in activeRedactions {
            outputImage = self.applyRedaction(redaction: redaction, to: outputImage, renderSize: renderSize)
        }
        
        request.finish(with: outputImage.cropped(to: CGRect(origin: .zero, size: renderSize)), context: nil)
    }
)
```

**Redaction Application:** Both blur and black-fill use **CIBlendWithMask**:
1. Create filtered layer (CIGaussianBlur or CIConstantColorGenerator)
2. Create white mask at redaction rect
3. Composite filtered layer onto original using mask

**Coordinate Translation:**
- **RedactionRegion:** Normalized (0.0-1.0), top-left origin (UI convention)
- **Core Image:** Absolute pixels, bottom-left origin (video system)
- **Formula:** `y_ci = renderSize.height - (y_ui * renderSize.height) - (height_ui * renderSize.height)`

**Rationale:**
- Native AVFoundation first-class support
- Per-frame processing: handler called once per frame, checks `compositionTime` against redaction time ranges
- Hardware-accelerated GPU rendering
- Composable multi-redaction support (sequential application)

**Alternatives Rejected:**
- Pre-process with AVAssetWriter: Manual frame extraction, complex
- Custom AVVideoCompositing: Overkill for filter-only use case
- Post-process separate tool: Two-pass reduces quality, doubles time

---

## Phase 6: Redaction Overlay UI — Architecture
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Status:** ✅ Implemented

### Normalized Coordinates + CIFilter Real-Time Preview

**Context:** Redaction UI needs interactive drawing/editing with resolution-independent coordinates and real-time blur/black-fill preview during playback.

**Decision:** Use **normalized coordinates (0.0-1.0)** for RedactionRegion storage with **CIFilter-based real-time preview** applied during video playback.

### Why Normalized Coordinates?

**Advantages:**
1. **Resolution-independent:** Work regardless of window size, export resolution, scaling
2. **Export-ready:** Phase 5 uses same values at native video resolution without conversion
3. **Flexible rendering:** Denormalize on-the-fly for current view size
4. **Future-proof:** Supports dynamic window resize, multi-monitor workflows

**Trade-offs:**
- Coordinate transformation on every render
- GeometryReader needed to capture current video size

**Alternatives Rejected:**
- Absolute Pixel Coordinates: Break when preview resizes
- SwiftUI Points: Change with zoom level, window size

### Why CIFilter for Preview?

**Advantages:**
1. **Native macOS API:** CIGaussianBlur, CIConstantColorGenerator built-in
2. **GPU-accelerated:** Hardware-optimized real-time processing
3. **Composable:** Multiple redactions chain via `composited(over:)`
4. **Export parity:** Same filters used in Phase 5 export rendering

**Trade-offs:**
- Coordinate system mismatch (CoreImage bottom-left vs SwiftUI top-left)
- Y-flip required: `videoSize.height - rect.origin.y - rect.height`

**Alternatives Rejected:**
- SwiftUI `.blur()`: Can't target specific rectangles
- Custom Metal Shader: Over-engineered
- AVVideoComposition (export-only): No real-time feedback

### Implementation Pattern

```swift
// Storage: normalized coordinates
struct RedactionRegion {
    var rect: CGRect // 0.0-1.0 coordinates
    var start: CMTime
    var end: CMTime
    var style: RedactionStyle // .blur or .blackFill
}

// Rendering: denormalize for current view
let absoluteRect = CGRect(
    x: region.rect.origin.x * videoSize.width,
    y: region.rect.origin.y * videoSize.height,
    width: region.rect.width * videoSize.width,
    height: region.rect.height * videoSize.height
)
```

### UI Interaction Modes

**Drawing Mode (Active):**
- "Add Redaction" button blue-tinted
- Drag gesture creates new redaction
- Temporary preview during drag
- Auto-creates 4-second time range centered on current frame

**Edit Mode (Passive):**
- Existing redactions show resize handles on hover
- 8-point handle system (4 corners + 4 edges + center)
- Drag handles to adjust size/position
- Right-click context menu for delete

### Resize Handle Design

**8-point system:**
- 4 corner handles (diagonal resize)
- 4 edge handles (horizontal/vertical resize)
- Center handle (move without resize)

**Visual:** 8pt circle diameter, blue fill with white stroke, 2pt shadow

**macOS Cursors:**
- Fallback: `NSCursor.crosshair` for corners (no diagonal cursors)
- Native: `.resizeLeftRight`, `.resizeUpDown` for edges

### Color Coding

- **Red:** Cut regions (content removal)
- **Blue:** Redaction regions (privacy censoring)
- **Yellow:** Chapter markers (navigation)

Blue distinguishes from destructive cut operations.

### Future Enhancements

1. Timeline edge-drag: Adjust redaction start/end times via timeline bar
2. Style picker UI: Toggle blur/black-fill in toolbar
3. Redaction labels: Numbered overlays
4. Auto-redaction: Speech recognition PII detection
5. Keyframe animation: Redaction rect moves/scales over time

---

## Phase 8: Preferences Window — AppStorage Persistence
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Status:** ✅ Implemented

### @AppStorage for User Preferences

**Context:** PreferencesWindow requires persistent storage for user preferences (capture settings, export format, hotkeys) across app launches.

**Decision:** Use `@AppStorage` property wrappers for all preference values.

**Rationale:**
1. **Native SwiftUI Integration:** Automatic view invalidation on value changes
2. **Type Safety:** Compiler-enforced types with Codable support for enums
3. **Zero Boilerplate:** No manual UserDefaults reading/writing
4. **Synchronous Access:** Immediate reads, no async complexity
5. **macOS Standard:** Same pattern used by system Settings app

**Implementation:**
```swift
@AppStorage("lookbackDuration") private var lookbackDuration: Double = 5.0
@AppStorage("defaultTranscription") private var defaultTranscription: Bool = true
@AppStorage("defaultResolution") private var defaultResolution: CaptureResolution = .native
```

Enums implement Codable for automatic RawRepresentable conformance (stored as strings).

**Alternatives Rejected:**
- UserDefaults (manual): More boilerplate
- Core Data: Overkill for flat key-value preferences
- JSON file: Manual serialization/deserialization complexity

**Integration Points:**
- **RecordingEngine:** Read capture settings before starting recording
- **ExportEngine:** Read export format/quality during export
- **TranscriptionEngine:** Check defaultTranscription toggle
- **HotkeyConfiguration:** Read hotkey strings for registration

**Trade-offs:**
- No validation layer
- No migration support (breaking changes require manual handling)
- Limited to property list types

---

## Phase 7: Transcript UI — Interaction Patterns
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Status:** ✅ Implemented

### Double-Click for Selection + Single-Click Seek

**Context:** TranscriptPanel needs multiple interaction modes: seek video on click, create cut regions from word selection, and search functionality.

**Decision:** Implemented **double-click for selection** with single-click reserved for seek action.

**UX Pattern:**
1. **Single-click** = Action (seek to word timestamp)
2. **Double-click** = Selection toggle (add/remove from selection set)
3. **Selection state** → "Create Cut Region" button appears
4. **Native search** via `.searchable` modifier (⌘F built-in)

**Implementation:**
```swift
.onTapGesture {
    onTap()  // Seek to timestamp
}
.onTapGesture(count: 2) {
    onSelect()  // Toggle selection
}
```

**Selection-to-Cut:** Selected words → find earliest/latest timestamps → create cut region.

**Rationale:**
- **macOS Conventions:** Single-click = action, double-click = select (Finder, Mail)
- **No Mode Switching:** Both actions always available
- **Discoverability:** Hover tooltips explain both gestures
- **Efficient Workflow:** Quick seek on click, deliberate selection on double-click

**Alternatives Rejected:**
- Shift/Command-click: Harder to discover, conflicts with future shortcuts
- Mode toggle: Extra step, less discoverable

**Impact:**
- ✅ Accessible: Single interaction mode
- ✅ Discoverable: Tooltips explain both gestures
- ✅ Efficient: No mode toggling
- ⚠️ Trade-off: Slightly slower multi-select than shift-click

---

## Consolidated Decisions

**Original:** neo-redaction-model-conflict.md  
**Status:** ✅ Resolved by Phase 6  
**Resolution:** Morpheus chose `start/end CMTime` pattern (matching CutRegion/ChapterMarker consistency). RedactionRegion consolidation complete; all references aligned.

---

**Document Updated:** 2026-02-20T19:52:03Z by Scribe
