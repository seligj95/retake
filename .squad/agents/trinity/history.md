# Trinity's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Learnings

### 2025-01-25: Phase 1 — macOS Permissions & Entitlements
**Decision:** Created Info.plist and DemoRecorder.entitlements for macOS 15+ sandboxed app
**Files:**
- `DemoRecorder/Info.plist` — Bundle configuration with LSUIElement=true, privacy descriptions
- `DemoRecorder/DemoRecorder.entitlements` — App Sandbox with screen recording, microphone, camera, file access

**Privacy Keys (macOS 15+):**
- `NSScreenCaptureDescription` — Required for ScreenCaptureKit
- `NSMicrophoneUsageDescription` — Audio recording
- `NSCameraUsageDescription` — Optional camera overlay

**Entitlements:**
- `com.apple.security.app-sandbox` — Required for Mac App Store distribution
- `com.apple.security.device.audio-input` — Microphone access
- `com.apple.security.device.camera` — Camera access
- `com.apple.security.files.user-selected.read-write` — Save recordings to user-chosen locations

**Pattern:** LSUIElement=true hides app from Dock, shows only menu bar icon (background app)

### 2026-02-20: Phase 1 Entitlements & Privacy Configuration Finalized
**Status:** ✅ COMPLETED

Phase 1 entitlements and privacy configuration integrated into production Xcode project:
- Info.plist privacy descriptions validated and embedded in pbxproj build settings
- DemoRecorder.entitlements integrated with Xcode code signing configuration
- Sandbox entitlements properly referenced in build settings (CODE_SIGN_ENTITLEMENTS)
- macOS 15+ privacy keys configured: NSScreenCaptureDescription, NSMicrophoneUsageDescription, NSCameraUsageDescription

**Next phase (Phase 2):** Validate sandbox does not block ScreenCaptureKit at runtime (highest identified risk).
**Phase 7 prep:** NSSpeechRecognitionUsageDescription already added to Info.plist to avoid churn.
