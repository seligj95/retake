import Foundation
import CoreMedia

struct RedactionRegion: Identifiable, Sendable {
    let id: UUID
    var rect: CGRect          // Normalized 0..1, top-left origin
    var startTime: CMTime
    var endTime: CMTime
    var style: Style

    enum Style: String, CaseIterable, Sendable {
        case blur = "Blur"
        case blackFill = "Black Fill"
    }

    init(id: UUID = UUID(), rect: CGRect, startTime: CMTime, endTime: CMTime, style: Style = .blur) {
        self.id = id
        self.rect = rect
        self.startTime = startTime
        self.endTime = endTime
        self.style = style
    }

    func isActive(at time: CMTime) -> Bool {
        time >= startTime && time <= endTime
    }
}
