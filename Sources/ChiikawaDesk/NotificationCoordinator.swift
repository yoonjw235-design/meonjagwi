import AppKit
import SwiftUI
import PetGeometry

final class NotificationCoordinator {
    private var reservations = NotificationReservations()
    func reserve(_ character: CharacterKind, in area: CGRect) -> NotificationPlacement {
        reservations.reserve(character.rawValue, in: area, capacity: CharacterKind.allCases.count)
    }
    func release(_ character: CharacterKind) { reservations.release(character.rawValue) }
}

struct SmallSpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = RoundedRectangle(cornerRadius: 14).path(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 8))
        path.move(to: CGPoint(x: rect.midX - 8, y: rect.maxY - 9))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + 8, y: rect.maxY - 9))
        path.closeSubpath()
        return path
    }
}
