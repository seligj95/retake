# Skill: NSPanel + SwiftUI Overlay Pattern

## Summary
Create floating, always-on-top overlay windows using NSPanel + NSHostingView with SwiftUI content.

## When to Use
- Always-on-top floating UI (status bars, HUDs, overlays)
- Transparent or translucent windows
- Non-activating panels that don't steal focus
- Draggable overlay windows
- Overlay UI that persists across Spaces/fullscreen apps

## Pattern

### Controller (AppKit Layer)
```swift
@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?
    
    func show() {
        let contentView = YourSwiftUIView()
        let hostingView = NSHostingView(rootView: contentView)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
            styleMask: [.nonactivatingPanel, .titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = hostingView
        panel.level = .floating                    // Always on top
        panel.collectionBehavior = [
            .canJoinAllSpaces,                     // Show in all Spaces
            .stationary,                           // Don't move in Exposé
            .fullScreenAuxiliary                   // Show in fullscreen
        ]
        panel.isMovableByWindowBackground = true   // Draggable
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear             // Transparent background
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false            // Stay visible
        
        // Position (example: top-center)
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - panel.frame.width / 2
            let y = screen.visibleFrame.maxY - panel.frame.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.orderFrontRegardless()
        self.panel = panel
    }
    
    func hide() {
        panel?.close()
        panel = nil
    }
}
```

### SwiftUI Content
```swift
struct YourSwiftUIView: View {
    var body: some View {
        HStack {
            // Your content
        }
        .padding()
        .background(.ultraThinMaterial)  // Native translucency
        .cornerRadius(8)
        .shadow(radius: 8)
    }
}
```

## Key Properties

### NSPanel Configuration
| Property | Value | Purpose |
|----------|-------|---------|
| `level` | `.floating` | Always on top of regular windows |
| `styleMask` | `.nonactivatingPanel` | Don't steal focus when shown |
| `collectionBehavior` | `.canJoinAllSpaces` | Show in all Spaces |
| `collectionBehavior` | `.fullScreenAuxiliary` | Show in fullscreen apps |
| `isMovableByWindowBackground` | `true` | Drag anywhere on window |
| `backgroundColor` | `.clear` | Transparent window chrome |
| `hidesOnDeactivate` | `false` | Stay visible when clicking away |

### Alternative Window Levels
- `.floating` — Above normal windows, below screensaver
- `.statusBar` — Same level as menu bar (may obscure menu)
- `.modalPanel` — Above floating panels
- `.popUpMenu` — Highest level (for menus/tooltips)

## Common Use Cases

### Status Bar / HUD
```swift
// Show recording status, timer, indicators
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

### Inspector Panel
```swift
// Tool palette, inspector, non-modal dialog
panel.styleMask = [.titled, .closable, .utilityWindow]
panel.level = .floating
panel.hidesOnDeactivate = true  // Hide when clicking away
```

### Screen Overlay
```swift
// Full-screen transparent overlay for region selection
panel.level = .screenSaver
panel.collectionBehavior = [.stationary, .fullScreenAuxiliary]
panel.backgroundColor = .black.withAlphaComponent(0.3)
```

## Positioning Helpers

```swift
// Top-center
let x = screen.visibleFrame.midX - panel.frame.width / 2
let y = screen.visibleFrame.maxY - panel.frame.height - margin

// Bottom-right
let x = screen.visibleFrame.maxX - panel.frame.width - margin
let y = screen.visibleFrame.minY + margin

// Center
let x = screen.visibleFrame.midX - panel.frame.width / 2
let y = screen.visibleFrame.midY - panel.frame.height / 2
```

## SwiftUI Integration Tips

### Observable State
```swift
struct FloatingView: View {
    @State private var model: YourModel
    
    var body: some View {
        // SwiftUI automatically updates when @Observable model changes
    }
}
```

### Timers
```swift
@State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

var body: some View {
    Text("...")
        .onReceive(timer) { _ in
            // Update state
        }
}
```

### Dark Mode
Use semantic colors and materials — they adapt automatically:
- `.primary`, `.secondary` for text
- `.ultraThinMaterial`, `.thinMaterial` for backgrounds

## Gotchas

1. **Panel must be strong-referenced** — Store `panel` property or it closes immediately
2. **NSHostingView lifecycle** — Panel owns the view; don't try to detach/reattach
3. **SwiftUI window APIs insufficient** — `Window` + `.windowLevel()` doesn't provide NSPanel features
4. **Keyboard focus** — `.nonactivatingPanel` prevents keyboard input; use `.titled` if you need text fields
5. **Memory** — Call `panel.close()` in `hide()` to release resources

## Testing

```swift
// SwiftUI Preview (panel won't float in preview)
#Preview {
    YourSwiftUIView()
        .frame(width: 200, height: 50)
}

// Runtime test
let controller = FloatingPanelController()
controller.show()
// Verify: window stays on top, draggable, transparent background
```

## Related Patterns
- **NSPopover** — For menu-anchored popovers (not always-on-top)
- **NSWindow subclass** — For more complex window behaviors
- **SwiftUI Window** — For standard windows (not overlays)

## References
- [NSPanel Documentation](https://developer.apple.com/documentation/appkit/nspanel)
- [NSHostingView Documentation](https://developer.apple.com/documentation/swiftui/nshostingview)
- [Window Levels](https://developer.apple.com/documentation/appkit/nswindow/level)
