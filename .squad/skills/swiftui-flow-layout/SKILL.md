# Skill: SwiftUI FlowLayout Pattern

## Summary
Custom SwiftUI Layout protocol implementation for text-wrapping, tag-cloud-style layouts where items flow left-to-right and wrap to new lines.

## When to Use
- Word-by-word transcript displays
- Tag clouds / token lists
- Chip/pill collections (filters, selections)
- Any content that should wrap like text but maintain individual item interactivity
- Alternative to fixed-width grids when content length varies

## Pattern

### FlowLayout Implementation
```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in layout.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let containerWidth = proposal.replacingUnspecifiedDimensions().width
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Move to next line if needed
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        let totalHeight = currentY + lineHeight
        return (CGSize(width: containerWidth, height: totalHeight), positions)
    }
}
```

### Usage Example
```swift
FlowLayout(spacing: 6) {
    ForEach(items) { item in
        ItemView(item: item)
            .padding(6)
            .background(Color.blue.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

## Source
Implemented in: `DemoRecorder/Views/TranscriptPanel.swift`  
Agent: Morpheus  
Date: 2026-02-20  
Phase: 7 — Transcription UI
