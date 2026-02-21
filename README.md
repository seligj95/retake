# Retake

A lightweight screen recording app for macOS with live redo, redaction, trim, and pause/resume. Record your screen, re-do any section on the fly, blur sensitive areas, and trim the result — all from your menu bar.

## Features

- **Screen & Window Recording** — Record your full screen or a specific window using ScreenCaptureKit
- **Live Redo** — Made a mistake? Hit redo to re-record from any point without starting over
- **Redaction** — Blur or black out sensitive areas of your recording before saving
- **Trim** — Cut the beginning and end of your recording with a dual-handle trim editor
- **Pause & Resume** — Pause recording at any time and pick up where you left off
- **Microphone Audio** — Optionally capture microphone narration alongside screen audio
- **Format Choice** — Export as MP4 or MOV from Preferences
- **Menu Bar App** — Lives in your menu bar, no dock icon
- **Auto-Update** — Checks GitHub Releases for new versions with one-click install

## Requirements

- macOS 15.0+

## Installation

Download **Retake.app.zip** from the [latest release](https://github.com/seligj95/retake/releases/latest), unzip it, and move `Retake.app` to `/Applications`.

> **Note:** macOS will block unsigned apps the first time — see [Gatekeeper Notice](#gatekeeper-notice) below. You'll also need to grant [permissions](#permissions).

## Building from Source

If you'd prefer to build locally, see [CONTRIBUTING.md](CONTRIBUTING.md) for instructions. Requires Xcode 16+ / Swift 6.0+.

## Gatekeeper Notice

Since Retake is ad-hoc signed (not notarized with an Apple Developer ID), macOS may block it the first time you open it. To allow it:

- **Right-click** (or Control-click) `Retake.app` → select **Open** → click **Open** in the dialog
- Or run: `xattr -cr /Applications/Retake.app` then open normally

You only need to do this once.

## Permissions

Retake requires the following permissions:

### Screen Recording
1. Open **System Settings > Privacy & Security > Screen Recording**
2. Toggle on **Retake**
3. Restart Retake if needed

> **Note:** After an update, you may need to re-grant Screen Recording permission since macOS ties it to the specific app binary. To do this, go to Screen Recording settings, select Retake, click **−** to remove it, then click **+** to re-add `Retake.app`, and restart Retake.

### Microphone (optional)
1. Open **System Settings > Privacy & Security > Microphone**
2. Toggle on **Retake**

> **Note:** Microphone permission may also need to be re-granted after an update.

## Usage

| Action | Shortcut |
|---|---|
| New Recording | `⌘⇧R` |
| Stop Recording | `⌘⇧R` |
| Pause / Resume | `⌘⇧P` |
| Redo from here | `⌘⇧Z` |
| Cancel Recording | Menu bar → Cancel |

After stopping, you'll be prompted to add redactions, then trim. The final file opens in Finder.

Access **Preferences** and **Quit** from the menu bar icon.

## Contributing

Found a bug or have a feature idea? [Open an issue](https://github.com/seligj95/retake/issues). Pull requests are welcome too — see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT
