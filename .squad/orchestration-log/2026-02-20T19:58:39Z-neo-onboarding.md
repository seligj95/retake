# Neo (agent-29) — Design first-launch onboarding for permissions

**Timestamp:** 2026-02-20T19:58:39Z  
**Status:** Completed (267s)

## Deliverables

1. **OnboardingCoordinator** — Observable state machine for multi-step flow
2. **OnboardingWindow** — Window controller with step navigation
3. **5-Step Flow** — Welcome → ScreenRecording → Microphone → SpeechRecognition → Complete
4. **Permission Checks** — ScreenCaptureKit, AVFoundation, Speech framework integration
5. **Decision Document** — Rationale for mandatory screen recording, optional enhancements

## Key Decisions

- **Mandatory screen recording** — App unusable without ScreenCaptureKit access
- **Optional microphone/speech** — Enhancement features, skip buttons provided
- **System Settings redirect** — No programmatic API for screen recording permission request
- **UserDefaults flag** — `hasCompletedOnboarding` boolean for first-launch detection
- **Re-show on revocation** — Permission lost in System Settings triggers onboarding re-display

## Rationale

ScreenCaptureKit is fundamental to DemoRecorder. Forcing optional permissions creates friction. System Settings redirect provides best UX given macOS constraints.

---
