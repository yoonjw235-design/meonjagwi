import AppKit

private struct AlertSnapshot {
    let name: String
    let bubble: NSImage
    let pet: NSImage
    let petSize: CGSize
    let padding: CGFloat
}
private final class AlertPreviewView: NSView {
    let snapshots: [AlertSnapshot]
    init(frame: CGRect, snapshots: [AlertSnapshot]) { self.snapshots = snapshots; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.95, alpha: 1).setFill(); bounds.fill()
        ("먼작귀 · 동시에 알림이 왔을 때" as NSString).draw(at: CGPoint(x: 20, y: 340), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 16), .foregroundColor: NSColor.darkGray])
        for (i, snapshot) in snapshots.enumerated() {
            let x = CGFloat(i) * 252 + 16
            (snapshot.name as NSString).draw(at: CGPoint(x: x + 92, y: 306), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.gray])
            snapshot.bubble.draw(in: CGRect(x: x, y: 160, width: 240, height: 128))
            snapshot.pet.draw(in: CGRect(x: x + 120 - snapshot.petSize.width / 2, y: 24 - snapshot.padding, width: snapshot.petSize.width, height: snapshot.petSize.height))
        }
    }
}
private func snapshot(_ view: NSView) -> NSImage? {
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let image = NSImage(size: view.bounds.size)
    image.addRepresentation(bitmap)
    return image
}
func renderNotificationPreview(for companions: [PetController]) {
    let snapshots = companions.sorted { $0.position.x < $1.position.x }.compactMap { controller -> AlertSnapshot? in
        guard let content = controller.bubble.contentView, let bubble = snapshot(content), let pet = snapshot(controller.petView) else { return nil }
        return AlertSnapshot(name: controller.profile.name, bubble: bubble, pet: pet, petSize: controller.petView.bounds.size, padding: controller.profile.bottomPadding)
    }
    precondition(snapshots.count == 3)
    let view = AlertPreviewView(frame: CGRect(x: 0, y: 0, width: 790, height: 370), snapshots: snapshots)
    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = view; window.orderFrontRegardless()
    if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/meonjakgwi-alerts-preview.png"))
        }
    }
    window.orderOut(nil)
}
