# AVComposition Cut Region Removal

## Overview
Pattern for removing multiple time ranges from an AVMutableComposition without offset drift.

## Use Case
When building a video editor that removes "cut regions" (marked segments to delete), processing cuts in reverse chronological order prevents timestamp invalidation.

## Pattern

```swift
import AVFoundation

/// Remove cut regions from a composition in reverse chronological order
func removeTimeRanges(from composition: AVMutableComposition, cutRegions: [CutRegion]) {
    // CRITICAL: Sort in REVERSE chronological order (latest first)
    let sortedCuts = cutRegions.sorted { $0.start > $1.start }
    
    for cutRegion in sortedCuts {
        let timeRange = CMTimeRange(start: cutRegion.start, duration: cutRegion.duration)
        composition.removeTimeRange(timeRange)
    }
}

struct CutRegion {
    var start: CMTime
    var end: CMTime
    
    var duration: CMTime {
        end - start
    }
}
```

## Why Reverse Order?

**Problem with forward order:**
- Removing early time ranges shifts all later timestamps backward
- Subsequent cut region start times become invalid
- Example: Cuts at [0-10s, 20-30s, 40-50s]
  - Remove 0-10s → composition becomes 0-40s
  - Original "20-30s" is now "10-20s" (offset drift!)
  - Removing "20-30s" removes the wrong segment

**Solution with reverse order:**
- Processing from end to start preserves earlier timestamps
- Example: Same cuts [0-10s, 20-30s, 40-50s]
  - Remove 40-50s → composition 0-40s, other cuts still valid
  - Remove 20-30s → composition 0-30s, first cut still valid
  - Remove 0-10s → composition 0-20s, correct result

## Complete Example

```swift
func createComposition(
    from sourceAsset: AVAsset,
    removingRegions cutRegions: [CutRegion]
) async throws -> AVMutableComposition {
    
    let composition = AVMutableComposition()
    
    // Load source tracks
    let sourceDuration = try await sourceAsset.load(.duration)
    let videoTracks = try await sourceAsset.load(.tracks(withMediaType: .video))
    let audioTracks = try await sourceAsset.load(.tracks(withMediaType: .audio))
    
    // Add video track with full source
    if let sourceVideoTrack = videoTracks.first {
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compositionVideoTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: sourceDuration),
            of: sourceVideoTrack,
            at: .zero
        )
    }
    
    // Add audio track with full source
    if let sourceAudioTrack = audioTracks.first {
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compositionAudioTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: sourceDuration),
            of: sourceAudioTrack,
            at: .zero
        )
    }
    
    // Remove cut regions in REVERSE chronological order
    let sortedCuts = cutRegions.sorted { $0.start > $1.start }
    
    for cutRegion in sortedCuts {
        let timeRange = CMTimeRange(start: cutRegion.start, duration: cutRegion.duration)
        composition.removeTimeRange(timeRange)
    }
    
    return composition
}
```

## Performance Notes
- Reverse sorting is O(n log n) but essential for correctness
- `removeTimeRange()` is efficient (AVFoundation internal optimization)
- Process all tracks simultaneously (video + audio stay synchronized)

## Related Patterns
- CMTime arithmetic: `end - start` for duration
- CMTimeRange: `CMTimeRange(start:duration:)` for range specification
- AVAssetExportSession for final export after composition

## Project Context
- Used in: DemoRecorder Phase 5 Export Engine
- File: `DemoRecorder/Export/ExportEngine.swift`
- Integration: Bracket-cut editing workflow

## Tags
#avfoundation #video-editing #time-range #composition #non-destructive-editing
