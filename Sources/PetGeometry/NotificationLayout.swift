import CoreGraphics
import Foundation

public struct NotificationPlacement: Equatable {
    public let petOrigin: CGPoint
    public let bubble: CGRect
}
public enum NotificationLayout {
    public static func placements(in area: CGRect, count: Int) -> [NotificationPlacement] {
        guard count > 0 else { return [] }
        let gap: CGFloat = 12, margin: CGFloat = 16
        let columns = min(count, max(1, Int((area.width - margin * 2 + gap) / (114 + gap))))
        let width = min(240, (area.width - margin * 2 - gap * CGFloat(columns - 1)) / CGFloat(columns))
        let height: CGFloat = width < 180 ? 160 : 128
        return (0..<count).map { index in
            let row = index / columns, column = index % columns
            let inRow = min(columns, count - row * columns)
            let totalWidth = width * CGFloat(inRow) + gap * CGFloat(inRow - 1)
            let x = area.midX - totalWidth / 2 + CGFloat(column) * (width + gap)
            let baseline = area.minY + 8 + CGFloat(row) * (132 + height + 24)
            return NotificationPlacement(petOrigin: CGPoint(x: x + width / 2 - 57, y: baseline),
                                         bubble: CGRect(x: x, y: baseline + 136, width: width, height: height))
        }
    }
}
public struct NotificationReservations {
    private var slots: [String: Int] = [:]
    public init() {}
    public mutating func reserve(_ key: String, in area: CGRect, capacity: Int) -> NotificationPlacement {
        precondition(capacity > 0)
        let placements = NotificationLayout.placements(in: area, count: capacity)
        if let slot = slots[key], slot < placements.count { return placements[slot] }
        let middle = Double(placements.count - 1) / 2
        let order = placements.indices.sorted {
            let a = abs(Double($0) - middle), b = abs(Double($1) - middle)
            return a == b ? $0 < $1 : a < b
        }
        guard let slot = order.first(where: { !slots.values.contains($0) }) else {
            preconditionFailure("Notification capacity must match companion count")
        }
        slots[key] = slot
        return placements[slot]
    }
    public mutating func release(_ key: String) { slots.removeValue(forKey: key) }
}
