import SwiftUI
import AppKit

struct RegionSelector: View {
    @State private var selectionRect: CGRect = .zero
    @State private var isDragging = false
    @State private var dragStartPoint: CGPoint = .zero
    
    let displayBounds: CGRect
    let onRegionSelected: (CGRect) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Selection rectangle
            if selectionRect.width > 0 && selectionRect.height > 0 {
                Rectangle()
                    .strokeBorder(Color.blue, lineWidth: 2)
                    .background(Color.blue.opacity(0.1))
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(
                        x: selectionRect.origin.x + selectionRect.width / 2,
                        y: selectionRect.origin.y + selectionRect.height / 2
                    )
                
                // Dimensions label
                VStack(spacing: 4) {
                    Text("\(Int(selectionRect.width)) × \(Int(selectionRect.height))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .position(
                    x: selectionRect.origin.x + selectionRect.width / 2,
                    y: selectionRect.origin.y - 20
                )
            }
            
            // Instructions
            if !isDragging && selectionRect == .zero {
                VStack(spacing: 16) {
                    Text("Select Recording Region")
                        .font(.title)
                        .foregroundStyle(.white)
                    
                    Text("Click and drag to select the area you want to record")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(32)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Confirm/Cancel buttons when selection exists
            if selectionRect.width > 0 && selectionRect.height > 0 && !isDragging {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Button("Start Recording") {
                            onRegionSelected(selectionRect)
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartPoint = value.startLocation
                    }
                    
                    let origin = CGPoint(
                        x: min(dragStartPoint.x, value.location.x),
                        y: min(dragStartPoint.y, value.location.y)
                    )
                    let size = CGSize(
                        width: abs(value.location.x - dragStartPoint.x),
                        height: abs(value.location.y - dragStartPoint.y)
                    )
                    
                    selectionRect = CGRect(origin: origin, size: size)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

// MARK: - NSWindow wrapper for full-screen overlay

@MainActor
final class RegionSelectorWindow: NSWindow {
    init(displayBounds: CGRect, onRegionSelected: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        super.init(
            contentRect: displayBounds,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingView = NSHostingView(
            rootView: RegionSelector(
                displayBounds: displayBounds,
                onRegionSelected: { rect in
                    onRegionSelected(rect)
                    self.close()
                },
                onCancel: {
                    onCancel()
                    self.close()
                }
            )
        )
        
        self.contentView = hostingView
        self.makeKeyAndOrderFront(nil)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
