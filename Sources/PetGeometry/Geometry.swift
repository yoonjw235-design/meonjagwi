import CoreGraphics
import Foundation

public struct WindowShape: Equatable {
    public let id: Int
    public let rect: CGRect
    public init(id: Int, rect: CGRect) { self.id = id; self.rect = rect }
}
public struct Platform: Equatable {
    public let windowID: Int
    public let rect: CGRect
    public init(windowID: Int, rect: CGRect) { self.windowID = windowID; self.rect = rect }
}
public struct Wall {
    public let windowID: Int
    public let x: CGFloat
    public let top: CGFloat
    public let inward: CGFloat
}
public enum WindowGeometry {
    // Upper envelope of the rectangle union, independent of window stacking order.
    public static func skyline(_ windows: [WindowShape]) -> [Platform] {
        let xs = Set(windows.flatMap { [$0.rect.minX, $0.rect.maxX] }).sorted()
        guard xs.count > 1 else { return [] }
        var result: [Platform] = []
        for i in 0..<(xs.count - 1) {
            let mid = (xs[i] + xs[i + 1]) / 2
            guard let owner = windows.filter({ mid > $0.rect.minX && mid < $0.rect.maxX })
                .max(by: { $0.rect.maxY < $1.rect.maxY }) else { continue }
            let rect = CGRect(x: xs[i], y: owner.rect.maxY, width: xs[i + 1] - xs[i], height: 0)
            if let last = result.last, last.windowID == owner.id, last.rect.maxX == rect.minX {
                result[result.count - 1] = Platform(windowID: owner.id, rect: CGRect(x: last.rect.minX, y: rect.minY, width: rect.maxX - last.rect.minX, height: 0))
            } else { result.append(Platform(windowID: owner.id, rect: rect)) }
        }
        return result
    }
    public static func walls(_ windows: [WindowShape], skyline: [Platform]) -> [Wall] {
        skyline.flatMap { p -> [Wall] in
            guard let owner = windows.first(where: { $0.id == p.windowID }) else { return [] }
            var result: [Wall] = []
            if p.rect.minX == owner.rect.minX { result.append(Wall(windowID: owner.id, x: p.rect.minX, top: p.rect.minY, inward: 1)) }
            if p.rect.maxX == owner.rect.maxX { result.append(Wall(windowID: owner.id, x: p.rect.maxX, top: p.rect.minY, inward: -1)) }
            return result
        }
    }
    // Rectangle subtraction avoids even-odd masks revealing overlapping occluders.
    public static func visibleRegions(_ bounds: CGRect, behind occluders: [CGRect]) -> [CGRect] {
        occluders.reduce([bounds]) { regions, cover in
            regions.flatMap { r -> [CGRect] in
                let cut = r.intersection(cover)
                guard !cut.isNull, !cut.isEmpty else { return [r] }
                return [CGRect(x: r.minX, y: r.minY, width: r.width, height: cut.minY - r.minY),
                        CGRect(x: r.minX, y: cut.maxY, width: r.width, height: r.maxY - cut.maxY),
                        CGRect(x: r.minX, y: cut.minY, width: cut.minX - r.minX, height: cut.height),
                        CGRect(x: cut.maxX, y: cut.minY, width: r.maxX - cut.maxX, height: cut.height)].filter { !$0.isEmpty }
            }
        }
    }
    public static func occluders(_ windows: [WindowShape], attachedTo id: Int?) -> [CGRect] {
        guard let id, let index = windows.firstIndex(where: { $0.id == id }) else { return windows.map(\.rect) }
        return windows.prefix(index).map(\.rect)
    }
}

public struct FlightPlan {
    public let destinationID: Int
    public let sourceID: Int
    public let velocity: CGPoint
    public let duration: CGFloat
    public let destination: CGPoint
}
public struct JumpAbility {
    public let maxRise: CGFloat
    public let launchVelocity: CGFloat
    public let maxHorizontalSpeed: CGFloat
    public let maxDuration: CGFloat
    public init(maxRise: CGFloat = 155, launchVelocity: CGFloat = 460,
                maxHorizontalSpeed: CGFloat = 300, maxDuration: CGFloat = 1.8) {
        self.maxRise = maxRise
        self.launchVelocity = launchVelocity
        self.maxHorizontalSpeed = maxHorizontalSpeed
        self.maxDuration = maxDuration
    }
    public static let standard = JumpAbility()
    public static let usagi = JumpAbility(maxRise: 260, launchVelocity: 600,
                                          maxHorizontalSpeed: 440, maxDuration: 2.2)
}
public enum PetTravel {
    public static let gravity: CGFloat = 650
    public static func platforms(_ windows: [WindowShape]) -> [Platform] {
        windows.map { Platform(windowID: $0.id, rect: CGRect(x: $0.rect.minX, y: $0.rect.maxY, width: $0.rect.width, height: 0)) }
    }
    // Foot-center intervals: reserve room for the entire body in front of each roof.
    public static func playablePlatforms(_ windows: [WindowShape], halfWidth: CGFloat = 57, height: CGFloat = 108) -> [Platform] {
        windows.enumerated().flatMap { index, window -> [Platform] in
            let y = window.rect.maxY
            var intervals = [window.rect.minX...window.rect.maxX]
            for cover in windows.prefix(index).map(\.rect) where cover.maxY > y && cover.minY < y + height {
                let low = cover.minX - halfWidth, high = cover.maxX + halfWidth
                intervals = intervals.flatMap { interval -> [ClosedRange<CGFloat>] in
                    guard high > interval.lowerBound && low < interval.upperBound else { return [interval] }
                    var parts: [ClosedRange<CGFloat>] = []
                    if low > interval.lowerBound { parts.append(interval.lowerBound...min(low, interval.upperBound)) }
                    if high < interval.upperBound { parts.append(max(high, interval.lowerBound)...interval.upperBound) }
                    return parts
                }
            }
            return intervals.filter { $0.upperBound - $0.lowerBound > 30 }.map {
                Platform(windowID: window.id, rect: CGRect(x: $0.lowerBound, y: y, width: $0.upperBound - $0.lowerBound, height: 0))
            }
        }
    }
    public static func transfers(from point: CGPoint, sourceID: Int, platforms: [Platform], area: CGRect,
                                 bodyHeight: CGFloat = 108, jumpAbility: JumpAbility = .standard) -> [FlightPlan] {
        platforms.compactMap { destination in
            guard destination.windowID != sourceID else { return nil }
            let low = max(destination.rect.minX + 22, area.minX + 57)
            let high = min(destination.rect.maxX - 22, area.maxX - 57)
            guard low <= high else { return nil }
            let dy = destination.rect.minY - point.y
            guard dy <= jumpAbility.maxRise, dy >= -700 else { return nil }
            let headroom = max(0, area.maxY - bodyHeight - point.y)
            let desired: CGFloat = dy < -25 ? 110 : (dy > 25 ? jumpAbility.launchVelocity : min(360, jumpAbility.launchVelocity))
            let vy = min(desired, sqrt(2 * gravity * headroom))
            let discriminant = vy * vy - 2 * gravity * dy
            guard discriminant > 0 else { return nil }
            let time = (vy + sqrt(discriminant)) / gravity
            let x = min(high, max(low, point.x))
            // Similar, overlapping roofs are one place to play, not a jump destination.
            guard abs(x - point.x) >= 60 || abs(dy) >= 35 else { return nil }
            let vx = (x - point.x) / time
            guard time < jumpAbility.maxDuration, abs(vx) <= jumpAbility.maxHorizontalSpeed else { return nil }
            // Do not aim through another roof on the descending part of the arc.
            for other in platforms where other.windowID != sourceID && other.windowID != destination.windowID {
                let d = vy * vy - 2 * gravity * (other.rect.minY - point.y)
                guard d >= 0 else { continue }
                let crossing = (vy + sqrt(d)) / gravity
                let crossingX = point.x + vx * crossing
                if crossing > 0.01 && crossing < time - 0.01,
                   crossingX > other.rect.minX, crossingX < other.rect.maxX { return nil }
            }
            // The complete arc must fit below the menu bar.
            guard point.y + vy * vy / (2 * gravity) <= area.maxY - bodyHeight + 0.01 else { return nil }
            return FlightPlan(destinationID: destination.windowID, sourceID: sourceID,
                              velocity: CGPoint(x: vx, y: vy), duration: time,
                              destination: CGPoint(x: x, y: destination.rect.minY))
        }
    }
    public static func choose(_ plans: [FlightPlan], fromY y: CGFloat, preference: Int) -> FlightPlan? {
        // Rotate up, sideways, down instead of allowing plentiful lower roofs to dominate.
        for offset in 0..<3 {
            let category = (preference + offset) % 3
            let options = plans.filter {
                let dy = $0.destination.y - y
                return category == 0 ? dy > 25 : (category == 1 ? abs(dy) <= 25 : dy < -25)
            }
            if let choice = options.min(by: { abs($0.velocity.x) < abs($1.velocity.x) }) { return choice }
        }
        return nil
    }
    public static func landing(on platforms: [Platform], x: CGFloat, oldY: CGFloat, newY: CGFloat, ignoring id: Int?) -> Platform? {
        platforms.filter {
            $0.windowID != id && x > $0.rect.minX && x < $0.rect.maxX && oldY >= $0.rect.minY - 0.01 && newY <= $0.rect.minY
        }.max { $0.rect.minY < $1.rect.minY }
    }
}

public struct TravelMemory {
    private var visited: [Int: TimeInterval] = [:]
    public private(set) var earliestDeparture: TimeInterval = 0
    public init() {}
    public mutating func landed(on id: Int, at time: TimeInterval) {
        visited[id] = time
        earliestDeparture = time + 5
    }
    public mutating func left(_ id: Int, at time: TimeInterval) { visited[id] = time }
    public func canDepart(at time: TimeInterval) -> Bool { time >= earliestDeparture }
    public func canVisit(_ id: Int, at time: TimeInterval) -> Bool {
        guard let last = visited[id] else { return true }
        return time - last >= 18
    }
}

extension WindowGeometry {
    // Every side that contributes to the union boundary may be climbed, even if
    // that window does not own the highest roof at its horizontal position.
    public static func climbWalls(_ windows: [WindowShape], playable: [Platform]) -> [Wall] {
        windows.flatMap { window -> [Wall] in
            guard playable.contains(where: { $0.windowID == window.id }) else { return [] }
            return [CGFloat(1), -1].compactMap { inward in
                let x = inward > 0 ? window.rect.minX : window.rect.maxX
                let outsideX = x - inward
                var exposed = [window.rect.minY...window.rect.maxY]
                for other in windows where other.id != window.id && outsideX > other.rect.minX && outsideX < other.rect.maxX {
                    exposed = exposed.flatMap { span -> [ClosedRange<CGFloat>] in
                        let low = max(span.lowerBound, other.rect.minY), high = min(span.upperBound, other.rect.maxY)
                        guard low < high else { return [span] }
                        var pieces: [ClosedRange<CGFloat>] = []
                        if low > span.lowerBound { pieces.append(span.lowerBound...low) }
                        if high < span.upperBound { pieces.append(high...span.upperBound) }
                        return pieces
                    }
                }
                guard exposed.contains(where: { $0.upperBound - $0.lowerBound > 15 }) else { return nil }
                return Wall(windowID: window.id, x: x, top: window.rect.maxY, inward: inward)
            }
        }
    }
}

extension WindowGeometry {
    public static func hasVisibleFooting(_ windows: [WindowShape], on id: Int, at foot: CGPoint) -> Bool {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return false }
        let roof = windows[index].rect
        guard foot.x > roof.minX, foot.x < roof.maxX, abs(foot.y - roof.maxY) < 5 else { return false }
        // Test the ledge itself. A window only covering the pet's upper body
        // changes its walking area, but does not remove the ledge under its feet.
        let contact = CGRect(x: max(roof.minX, foot.x - 8), y: roof.maxY - 1,
                             width: min(roof.maxX, foot.x + 8) - max(roof.minX, foot.x - 8), height: 2)
        return !windows.prefix(index).contains { $0.rect.intersects(contact) }
    }
}

extension WindowGeometry {
    public static func balancedClimbWall(_ candidates: [Wall], lastWindowID: Int?, windowVisits: [Int: Int], sideVisits: [Int: Int]) -> Wall? {
        let alternatives = candidates.filter { $0.windowID != lastWindowID }
        let pool = alternatives.isEmpty ? candidates : alternatives
        return pool.min {
            let leftCount = sideVisits[Int($0.inward), default: 0]
            let rightCount = sideVisits[Int($1.inward), default: 0]
            if leftCount != rightCount { return leftCount < rightCount }
            return windowVisits[$0.windowID, default: 0] < windowVisits[$1.windowID, default: 0]
        }
    }
}

public struct CompanionMotion {
    public let walkSpeed: CGFloat
    public let climbSpeed: CGFloat
    public let alertSpeed: CGFloat
    public let restPeriod: Int
    public let happyPeriod: Int
    public static let chiikawa = CompanionMotion(walkSpeed: 65, climbSpeed: 85, alertSpeed: 360, restPeriod: 450, happyPeriod: 660)
    public static let hachiware = CompanionMotion(walkSpeed: 80, climbSpeed: 105, alertSpeed: 390, restPeriod: 660, happyPeriod: 510)
    public static let usagi = CompanionMotion(walkSpeed: 140, climbSpeed: 170, alertSpeed: 500, restPeriod: 900, happyPeriod: 360)
    public static let shisa = CompanionMotion(walkSpeed: 58, climbSpeed: 75, alertSpeed: 320, restPeriod: 600, happyPeriod: 750)
}

public struct CoatTone {
    public let r: Double, g: Double, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    public static let usagi = CoatTone(252, 242, 205)
    public static func isYellowCoat(_ r: Double, _ g: Double, _ b: Double) -> Bool {
        r >= 200 && g >= 190 && b >= 130 && r >= g && g > b
            && r - b >= 12 && g - b >= 6 && (r - b) / max(r, 1) < 0.45
    }
    public static func matched(_ r: Double, _ g: Double, _ b: Double, reference: CoatTone) -> (Double, Double, Double) {
        guard isYellowCoat(r, g, b) else { return (r, g, b) }
        let shade = (r - reference.r) * 0.25 + (g - reference.g) * 0.55 + (b - reference.b) * 0.2
        func clamp(_ value: Double) -> Double { min(255, max(0, value)) }
        return (clamp(usagi.r + shade), clamp(usagi.g + shade), clamp(usagi.b + shade))
    }
}
