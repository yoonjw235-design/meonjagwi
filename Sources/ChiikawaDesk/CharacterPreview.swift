import AppKit

private final class CharacterPreviewView: NSView {
    let poses = ["walk", "held", "rest", "fall", "happy", "run", "notify"]
    let labels = ["걷기", "매달리기", "엎드리기 · 꼬리는 아래로", "낙하", "기쁨", "알림으로 달려오기", "알림 도착"]
    let profile: CharacterProfile
    var clips: [String: SpriteClip] = [:]
    init(frame: NSRect, profile: CharacterProfile) {
        self.profile = profile
        super.init(frame: frame)
        for pose in poses {
            let name = profile.asset(for: pose)
            if let url = spriteURL(name), let clip = SpriteClip(url: url, playbackScale: profile.isHachiware && pose == "rest" ? 1.6 : 1) { clips[pose] = clip }
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.98, alpha: 1).setFill()
        bounds.fill()
        ("\(profile.name) · 동작 미리보기" as NSString).draw(at: CGPoint(x: 25, y: 215), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 18), .foregroundColor: NSColor.darkGray])
        for (index, pose) in poses.enumerated() {
            let x = CGFloat(index) * 155 + 20
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform(); transform.translateX(by: x, yBy: 65); transform.concat()
            NSColor(calibratedRed: 0.7, green: 0.8, blue: 0.77, alpha: 1).setStroke()
            let line = NSBezierPath(); line.move(to: CGPoint(x: 0, y: 18)); line.line(to: CGPoint(x: 122, y: 18)); line.stroke()
            clips[pose]?.draw(pose: pose, elapsed: 0.5, baseline: 18, width: 114, character: profile.kind)
            ((profile.isUsagi && pose == "happy" ? "빙글빙글 돌기" : (profile.isUsagi && pose == "rest" ? "엎드리기" : labels[index])) as NSString).draw(at: CGPoint(x: 0, y: -15), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.darkGray])
            NSGraphicsContext.restoreGraphicsState()
        }
        ("초록 선 = 몸과 다리가 닿는 발판 · GIF 원본의 투명 배경과 프레임 유지" as NSString).draw(at: CGPoint(x: 25, y: 15), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.gray])
    }
}

func renderCharacterPreview() {
    let profile = CharacterProfile(kind: CommandLine.arguments.contains("--usagi") ? .usagi : .hachiware)
    let view = CharacterPreviewView(frame: NSRect(x: 0, y: 0, width: 1110, height: 260), profile: profile)
    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = view; window.orderFrontRegardless()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        view.layoutSubtreeIfNeeded()
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: "/tmp/\(profile.kind.rawValue)-character-preview.png"))
            }
        }
        // Validate original GIF timing is slowed only for the resting animation.
        if profile.isHachiware {
            let sit = spriteURL("Hachiware sit.gif")!
            let normal = SpriteClip(url: sit)!, slow = SpriteClip(url: sit, playbackScale: 1.6)!
            precondition(abs(slow.duration / normal.duration - 1.6) < 0.001)
        }
        precondition(view.clips.count == 7)
        print("7 \(profile.kind.rawValue) sprite assets decoded; preview saved")
        window.orderOut(nil)
        NSApp.terminate(nil)
    }
}
