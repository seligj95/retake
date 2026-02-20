# Neo's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Learnings

### 2025-01-25: Phase 1 Architecture Review
**Decision:** Xcode project required (not pure SPM executable) for sandboxed menu bar app
- A `Package.swift` alone produces a CLI executable, not an app bundle. Entitlements, Info.plist, code signing, and sandboxing require an Xcode project (`.xcodeproj`).
- Recommended hybrid: Xcode project for app target + `Package.swift` for internal library targets (enables testability) + SPM dependencies managed via Xcode.
- **Sandbox + ScreenCaptureKit risk**: Most open-source screen recorders (Azayaka, QuickRecorder) are NOT sandboxed. ScreenCaptureKit has had historical issues in sandbox. Must validate early in Phase 2 or consider hardened runtime without sandbox.
- `MenuBarExtra` should use `.menu` content style in Phase 1 (native NSMenu). Reserve `.window` style for future popover UI.
- Use `@Observable` (macOS 15+ / Swift 5.9+) for state management from the start.
- "Open Recent" menu item should be disabled/placeholder in Phase 1 — project persistence comes in Phase 8.
- `LSUIElement = true` hides from Dock, but Phase 4 review window may need dynamic `NSApp.setActivationPolicy(.regular)` to show in Dock when windows are open.
- Screen recording permission is TCC-managed (no entitlement key needed), but microphone requires both entitlement AND `NSMicrophoneUsageDescription`.
- Missing from plan: asset catalog (menu bar icon, app icon), `.xcodeproj` creation.

**Key file paths:**
- `DemoRecorder/DemoRecorderApp.swift` — App entry point
- `DemoRecorder/Info.plist` — Privacy descriptions, LSUIElement
- `DemoRecorder/DemoRecorder.entitlements` — Sandbox entitlements
- `DemoRecorder/Assets.xcassets/` — App icon, menu bar icon (MISSING from plan)

### 2026-02-20: Phase 1 Architecture Review Finalized
**Status:** ✅ APPROVED & COMPLETED

All 3 required changes implemented by Morpheus:
1. ✅ Xcode project created with native targets (app + tests)
2. ✅ Assets.xcassets catalog added (AppIcon, AccentColor)
3. ✅ DemoRecorderTests target created with unit test skeleton

Phase 1 scaffold complete and ready for Phase 2 (ScreenCaptureKit integration).

**Highest risk identified:** Sandbox + ScreenCaptureKit compatibility. Schedule spike for Phase 2, day 1.
