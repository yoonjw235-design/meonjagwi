import AppKit
import SwiftUI
import CoreGraphics
import PetGeometry
import QuartzCore

enum WorkState: String, Codable, CaseIterable {
    case inbox = "확인해야 할 것", later = "나중에 진행할 것", done = "완료"
}
struct WorkItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var kind: String
    var state: WorkState = .inbox
}
final class WorkStore: ObservableObject {
    @Published var items: [WorkItem] = [] { didSet { save() } }
    @Published var storageError: String?
    private let url: URL
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ChiikawaDesk")
        url = folder.appendingPathComponent("tasks.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                items = try JSONDecoder().decode([WorkItem].self, from: Data(contentsOf: url))
            }
        } catch { storageError = "업무 파일을 읽을 수 없어요: \(error.localizedDescription)" }
    }
    func save() {
        // Preserve an unreadable file rather than silently replacing it.
        guard storageError == nil else { return }
        do { try JSONEncoder().encode(items).write(to: url, options: .atomic) }
        catch { storageError = "업무를 저장하지 못했어요: \(error.localizedDescription)" }
    }
}

// Keep the supplied GIF timing and transparency through AppKit's image playback.
final class DirectionalImageView: NSImageView {
    var pose = "walk"
    var profile = CharacterProfile.current
    var clip: SpriteClip?
    var clipStartedAt = Date.timeIntervalSinceReferenceDate
    var mirrored = false {
        didSet { if mirrored != oldValue { needsDisplay = true } }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        if profile.usesSpriteClip, let clip {
            if mirrored {
                let transform = NSAffineTransform()
                transform.translateX(by: bounds.width, yBy: 0)
                transform.scaleX(by: -1, yBy: 1)
                transform.concat()
            }
            clip.draw(pose: pose, elapsed: Date.timeIntervalSinceReferenceDate - clipStartedAt,
                      baseline: profile.bottomPadding, width: bounds.width, character: profile.kind)
            NSGraphicsContext.restoreGraphicsState()
            return
        }
        if pose == "rest", let image {
            // Ignore the PNG's transparent margins; keep its visible bottom on the surface.
            let source = NSRect(x: image.size.width * 155 / 1261,
                                y: image.size.height * (1247 - 964) / 1247,
                                width: image.size.width * 973 / 1261,
                                height: image.size.height * 589 / 1247)
            let width: CGFloat = 97
            image.draw(in: NSRect(x: (bounds.width - width) / 2, y: 0,
                                  width: width, height: width * 589 / 973),
                       from: source, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            return
        }
        if pose == "run" {
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.midX, yBy: bounds.midY)
            transform.scale(by: 1.2)
            transform.translateX(by: -bounds.midX, yBy: -bounds.midY)
            transform.concat()
        }
        if pose == "fall" || pose == "jump" {
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.midX, yBy: 0)
            transform.scale(by: 0.9)
            transform.translateX(by: -bounds.midX, yBy: 0)
            transform.concat()
        }
        if pose == "happy" {
            let transform = NSAffineTransform()
            // The dance GIF has 24 pixels of transparent padding below its feet.
            transform.translateX(by: bounds.midX, yBy: -bounds.height * 24 / 282 * 1.148)
            transform.scale(by: 1.148)
            transform.translateX(by: -bounds.midX, yBy: 0)
            transform.concat()
        }
        if mirrored {
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
        }
        super.draw(bounds)
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class PetView: NSView {
    let artwork = DirectionalImageView()
    private var visibleRegions: [CGRect] = []
    private let visibilityMask = CAShapeLayer()
    func setOccluders(_ rectangles: [CGRect]) {
        visibleRegions = WindowGeometry.visibleRegions(bounds, behind: rectangles)
        let path = CGMutablePath()
        for region in visibleRegions { path.addRect(region) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        visibilityMask.frame = artwork.bounds
        visibilityMask.path = path
        visibilityMask.fillColor = NSColor.black.cgColor
        artwork.layer?.mask = visibilityMask
        CATransaction.commit()
    }
    var onClick: (() -> Void)?
    var onGrab: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onRelease: (() -> Void)?
    private var start = CGPoint.zero
    private var offset = CGPoint.zero
    private var dragged = false
    private var currentAsset = ""
    var currentAssetName: String { currentAsset }
    var hasLoadedArtwork: Bool { profile.usesSpriteClip ? artwork.clip != nil : artwork.image != nil }
    private var images: [String: NSImage] = [:]
    private var clips: [String: SpriteClip] = [:]
    var profile: CharacterProfile { artwork.profile }
    func tickAnimation() { if profile.usesSpriteClip { artwork.needsDisplay = true } }
    init(frame: NSRect, profile: CharacterProfile = .current) {
        super.init(frame: frame)
        artwork.profile = profile
        artwork.wantsLayer = true
        artwork.frame = bounds
        artwork.autoresizingMask = [.width, .height]
        artwork.imageScaling = .scaleProportionallyUpOrDown
        artwork.animates = !profile.usesSpriteClip
        addSubview(artwork)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { visibleRegions.contains(where: { $0.contains(point) }) ? self : nil }
    func display(_ state: String, movingRight: Bool = false) {
        if artwork.pose != state { artwork.pose = state; artwork.needsDisplay = true }
        // The supplied walk GIF faces left; mirror it for rightward travel.
        artwork.mirrored = (state == "walk" || state == "climb" || state == "run") && movingRight
        let name = profile.asset(for: state)
        guard name != currentAsset else { return }
        currentAsset = name
        if profile.usesSpriteClip {
            if clips[name] == nil, let url = spriteURL(name) {
                clips[name] = SpriteClip(url: url, playbackScale: profile.isHachiware && state == "rest" ? 1.6 : 1)
            }
            artwork.clip = clips[name]
            artwork.clipStartedAt = Date.timeIntervalSinceReferenceDate
            artwork.needsDisplay = true
            return
        }
        if images[name] == nil, let url = (Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Resources") ?? Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources")) {
            images[name] = NSImage(contentsOf: url)
        }
        artwork.image = images[name]
    }
    override func mouseDown(with event: NSEvent) {
        start = NSEvent.mouseLocation
        offset = CGPoint(x: start.x - (window?.frame.minX ?? 0), y: start.y - (window?.frame.minY ?? 0))
        dragged = false
        onGrab?()
    }
    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        if hypot(mouse.x - start.x, mouse.y - start.y) > 4 { dragged = true }
        if dragged { onDrag?(CGPoint(x: mouse.x - offset.x, y: mouse.y - offset.y)) }
    }
    override func mouseUp(with event: NSEvent) {
        onRelease?()
        if !dragged { onClick?() }
    }
}

final class PetController: NSObject {
    static var boardWindowNumbers: Set<Int> = []
    let profile: CharacterProfile
    let store: WorkStore
    let notifications: NotificationCoordinator
    var notificationPlacement: NotificationPlacement?
    init(profile: CharacterProfile, store: WorkStore, notifications: NotificationCoordinator = NotificationCoordinator()) {
        self.profile = profile; self.store = store; self.notifications = notifications
        super.init()
    }
    var walkSpeed: CGFloat { profile.style.walkSpeed }
    var renderOrigin: CGPoint { CGPoint(x: position.x - profile.horizontalPadding, y: position.y - profile.bottomPadding) }
    func placePet() { pet.setFrameOrigin(renderOrigin) }
    var pet: NSPanel!
    lazy var petView = PetView(frame: NSRect(x: 0, y: 0, width: 114 + profile.horizontalPadding * 2, height: profile.bodyHeight + profile.bottomPadding), profile: profile)
    var board: NSWindow!
    var bubble: NSPanel!
    var menu: NSMenu!
    var timer: Timer?
    var position = CGPoint.zero
    var velocity = CGPoint(x: 65, y: 0)
    var surfaces: [CGRect] = []
    var windows: [WindowShape] = []
    var platforms: [Platform] = []
    var walls: [Wall] = []
    var attachedWindowID: Int?
    var climbingWall: Wall?
    var droppingToFloor = false
    var flight: FlightPlan?
    var nextTransferAt = Date.distantPast
    var lastVisitedWindowID: Int?
    var travelMemory = TravelMemory()
    var approachWall: Wall?
    var climbCounts: [Int: Int] = [:]
    var climbSideCounts: [Int: Int] = [:]
    var lastClimbedWindowID: Int?
    var transferPreference = 0
    var nextEdgeAttemptAt = Date.distantPast
    var ticks = 0
    var mode = "walk"
    var target: CGPoint?
    var notificationUntil = Date.distantPast
    var paused = false
    var leisureUntil = Date.distantPast
    var selectedScreen: NSScreen {
        NSScreen.screens.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height } ?? NSScreen.main!
    }
    func screensChanged() {
        let area = selectedScreen.visibleFrame
        position = CGPoint(x: area.midX - 57 + profile.startOffset, y: area.minY)
        velocity = CGPoint(x: walkSpeed, y: 0)
        droppingToFloor = false; attachedWindowID = nil; climbingWall = nil; flight = nil; approachWall = nil
        mode = "walk"; target = nil
        clearNotification()
    }

    func start() {
        velocity.x = walkSpeed
        pet = NSPanel(contentRect: petView.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        pet.isOpaque = false; pet.backgroundColor = .clear; pet.hasShadow = false
        pet.level = .floating; pet.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        pet.contentView = petView
        petView.onClick = { [weak self] in self?.showBoard(); self?.dismissNotification() }
        petView.onGrab = { [weak self] in
            self?.clearNotification(); self?.mode = "held"; self?.target = nil
            self?.attachedWindowID = nil; self?.climbingWall = nil; self?.flight = nil; self?.approachWall = nil
            self?.petView.setOccluders([])
            self?.petView.display("held")
        }
        petView.onDrag = { [weak self] point in
            guard let self else { return }
            self.position = CGPoint(x: point.x + self.profile.horizontalPadding, y: point.y + self.profile.bottomPadding)
            self.placePet()
        }
        petView.onRelease = { [weak self] in self?.mode = "fall"; self?.droppingToFloor = false; self?.velocity = CGPoint(x: self?.walkSpeed ?? 65, y: 0) }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.screensChanged() }
        let screen = selectedScreen.visibleFrame
        position = CGPoint(x: screen.midX - 57 + profile.startOffset, y: screen.minY)
        placePet(); pet.orderFrontRegardless()
        board = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        board.title = "\(profile.name) · \(profile.role)"; board.isReleasedWhenClosed = false
        Self.boardWindowNumbers.insert(board.windowNumber)
        if profile.isUsagi {
            board.contentView = NSHostingView(rootView: ScheduleView(notify: { [weak self] in self?.notify() }))
        } else if profile.isHachiware {
            board.contentView = NSHostingView(rootView: TasksView(store: store, notify: { [weak self] in self?.notify() }))
        } else {
            board.contentView = NSHostingView(rootView: AutomationView(notify: { [weak self] in self?.notify() }))
        }
        board.center()
        bubble = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 128), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        bubble.isOpaque = false; bubble.backgroundColor = .clear; bubble.level = .floating
        bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        menu = NSMenu()
        for (title, action) in [("\(profile.role) 열기", #selector(showBoard)), ("테스트 알림", #selector(notify)), ("산책 일시 정지 / 재개", #selector(togglePause)), ("창 감지 상태 확인", #selector(checkWindows))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        let poses = NSMenu()
        for (title, action) in [("엎드리기", #selector(previewRest)), (profile.happyActionTitle, #selector(previewHappy))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; poses.addItem(item)
        }
        let preview = NSMenuItem(title: "동작 보기", action: nil, keyEquivalent: "")
        preview.submenu = poses
        menu.insertItem(preview, at: 2)
        let animationTimer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.step() }
        timer = animationTimer
        // NSMenu tracks in an event-tracking run-loop mode. Register in common
        // modes so pet movement and sprite animation continue while it is open.
        RunLoop.main.add(animationTimer, forMode: .common)
    }
    func renderBoardPreview() {
        board = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 900), styleMask: [.borderless], backing: .buffered, defer: false)
        board.appearance = NSAppearance(named: .aqua)
        let view = NSHostingView(rootView: TasksView(store: store, notify: {}))
        board.contentView = view
        board.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { NSApp.terminate(nil); return }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let url = URL(fileURLWithPath: "/tmp/chiikawa-board-preview.png")
            if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: url) }
            NSApp.terminate(nil)
        }
    }
    @objc func previewRest() { previewPose("rest") }
    @objc func previewHappy() { previewPose("happy") }
    func previewPose(_ pose: String) {
        guard mode != "held" else { return }
        clearNotification()
        let area = selectedScreen.visibleFrame
        let grounded = abs(position.y - area.minY) < 3 || attachedWindowID.map {
            WindowGeometry.hasVisibleFooting(windows, on: $0, at: CGPoint(x: position.x + 57, y: position.y))
        } == true
        if !grounded { screensChanged() }
        flight = nil; climbingWall = nil; target = nil
        mode = pose; leisureUntil = Date().addingTimeInterval(8)
        petView.display(pose)
        placePet()
    }
    @objc func showBoard() { NSApp.activate(ignoringOtherApps: true); board.makeKeyAndOrderFront(nil) }
    @objc func togglePause() { paused.toggle() }
    @objc func checkWindows() {
        scanWindows()
        let alert = NSAlert()
        alert.messageText = "감지한 창 \(windows.count)개 · 이동할 발판 \(platforms.count)개"
        alert.informativeText = surfaces.isEmpty
            ? "선택된 화면에 일반 창을 열고 위쪽에 캐릭터가 설 공간을 남겨주세요."
            : "창 가장자리로 다가간 뒤 위로 올라가요."
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    @objc func notify() {
        let screen = selectedScreen
        let placement = notifications.reserve(profile.kind, in: screen.visibleFrame)
        notificationPlacement = placement
        target = placement.petOrigin
        mode = "notify"; approachWall = nil; attachedWindowID = nil; climbingWall = nil; flight = nil; bubble.orderOut(nil)
        notificationUntil = .distantPast
        petView.display("run", movingRight: (target?.x ?? position.x) > position.x)
    }
    func scanWindows() {
        let previousOwner = attachedWindowID.flatMap { id in windows.first { $0.id == id } }
        windows = []
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
           let main = NSScreen.screens.first {
            for entry in list {
                guard let pid = entry[kCGWindowOwnerPID as String] as? Int,
                      (pid != Int(getpid()) || Self.boardWindowNumbers.contains(entry[kCGWindowNumber as String] as? Int ?? -1)),
                      let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                      let dict = entry[kCGWindowBounds as String] as? [String: Any],
                      let rect = CGRect(dictionaryRepresentation: dict as CFDictionary),
                      rect.width > 180, rect.height > 100,
                      (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                      let id = entry[kCGWindowNumber as String] as? Int else { continue }
                let converted = CGRect(x: rect.minX, y: main.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
                guard converted.intersects(selectedScreen.visibleFrame) else { continue }
                windows.append(WindowShape(id: id, rect: converted))
            }
        }
        let area = selectedScreen.visibleFrame
        platforms = PetTravel.playablePlatforms(windows, halfWidth: 57 + profile.horizontalPadding, height: profile.bodyHeight).filter {
            $0.rect.minY > area.minY + 30 && $0.rect.minY <= area.maxY - profile.bodyHeight
        }
        surfaces = platforms.map(\.rect)
        walls = WindowGeometry.climbWalls(windows, playable: platforms)
        if let flight, !platforms.contains(where: { $0.windowID == flight.destinationID }) {
            beginFall(toFloor: true)
        }
        if let previousOwner, ["climb", "walk", "rest", "happy"].contains(mode) {
            let current = windows.first { $0.id == previousOwner.id }
            // A roof hidden behind a foreground window is no longer a foothold.
            let lost = current == nil || (mode == "climb"
                ? current?.rect != previousOwner.rect
                : !WindowGeometry.hasVisibleFooting(windows, on: previousOwner.id,
                                                   at: CGPoint(x: position.x + 57, y: position.y)))
            if lost { beginFall(toFloor: true) }
        }
    }
    func beginFall(toFloor: Bool) {
        droppingToFloor = toFloor; flight = nil
        if toFloor { attachedWindowID = nil; approachWall = nil }
        mode = "fall"; target = nil; climbingWall = nil; velocity.y = 0
    }
    func updateOcclusion() {
        let covers = (mode == "held" || mode == "notify" || attachedWindowID == nil) ? [] : WindowGeometry.occluders(windows, attachedTo: attachedWindowID)
        let local = covers.map { $0.offsetBy(dx: -renderOrigin.x, dy: -renderOrigin.y) }
        petView.setOccluders(local)
        // Fully covered pets must not intercept clicks intended for foreground apps.
        pet.ignoresMouseEvents = !WindowGeometry.visibleRegions(petView.bounds, behind: local).contains {
            $0.contains(CGPoint(x: NSEvent.mouseLocation.x - renderOrigin.x, y: NSEvent.mouseLocation.y - renderOrigin.y))
        }
    }
    func startClimbing(_ wall: Wall) {
        climbingWall = wall; attachedWindowID = wall.windowID; approachWall = nil
        climbCounts[wall.windowID, default: 0] += 1
        climbSideCounts[Int(wall.inward), default: 0] += 1
        lastClimbedWindowID = wall.windowID
        position.x = wall.x + wall.inward * 10 - 57
        target = CGPoint(x: position.x, y: wall.top)
        velocity = CGPoint(x: wall.inward * walkSpeed, y: 0)
        mode = "climb"
    }
    func movePet(in area: CGRect) {
        let dt: CGFloat = 1 / 30
        let foot = position.x + 57
        // Keep an existing foothold even when another window covers it visually.
        let attached = attachedWindowID.flatMap { id in windows.first { $0.id == id } }
        let safeSupport = platforms.first {
            !droppingToFloor && $0.windowID == attachedWindowID && foot > $0.rect.minX && foot < $0.rect.maxX && abs(position.y - $0.rect.minY) < 5
        }
        let ownSupport = attached.flatMap { w -> Platform? in
            guard !droppingToFloor, foot > w.rect.minX, foot < w.rect.maxX,
                  abs(position.y - w.rect.maxY) < 5 else { return nil }
            return Platform(windowID: w.id, rect: CGRect(x: w.rect.minX, y: w.rect.maxY, width: w.rect.width, height: 0))
        }
        let support = safeSupport ?? ownSupport ?? (droppingToFloor ? nil : platforms.first {
            foot > $0.rect.minX && foot < $0.rect.maxX && abs(position.y - $0.rect.minY) < 5
        })
        if mode == "climb", let dest = target, let wall = climbingWall {
            if !windows.contains(where: { $0.id == wall.windowID }) { beginFall(toFloor: true); return }
            position.y += profile.style.climbSpeed * dt
            if position.y >= dest.y {
                position = dest; mode = "walk"; target = nil; climbingWall = nil
                guard WindowGeometry.hasVisibleFooting(windows, on: wall.windowID,
                                                       at: CGPoint(x: position.x + 57, y: position.y)) else {
                    beginFall(toFloor: true); return
                }
                travelMemory.landed(on: wall.windowID, at: Date().timeIntervalSinceReferenceDate)
                nextTransferAt = Date().addingTimeInterval(5)
            }
            return
        }
        let grounded = flight == nil && (support != nil || abs(position.y - area.minY) < 3)
        if grounded && velocity.y <= 0 {
            velocity.y = 0; mode = "walk"
            if let support { attachedWindowID = support.windowID }
            let onSafeRoof = support == nil || safeSupport != nil
            if onSafeRoof && ticks % profile.style.restPeriod == 0 { mode = "rest"; leisureUntil = Date().addingTimeInterval(5) }
            else if onSafeRoof && ticks % profile.style.happyPeriod == 0 { mode = "happy"; leisureUntil = Date().addingTimeInterval(4) }
            if mode == "walk" {
                if support == nil {
                    attachedWindowID = nil
                    let candidates = walls.filter {
                        let x = $0.x + $0.inward * 10 - 57
                        return x >= area.minX && x <= area.maxX - 114
                    }
                    if let selected = approachWall, !candidates.contains(where: {
                        $0.windowID == selected.windowID && $0.x == selected.x && $0.top == selected.top && $0.inward == selected.inward
                    }) { approachWall = nil }
                    if approachWall == nil {
                        approachWall = WindowGeometry.balancedClimbWall(candidates.shuffled(),
                            lastWindowID: lastClimbedWindowID, windowVisits: climbCounts, sideVisits: climbSideCounts)
                    }
                    if let wall = approachWall {
                        let x = wall.x + wall.inward * 10 - 57
                        if abs(position.x - x) < 4 { startClimbing(wall); return }
                        velocity.x = x > position.x ? walkSpeed : -walkSpeed
                    }
                } else if let support {
                    let atEdge = safeSupport.map { foot < $0.rect.minX + 24 || foot > $0.rect.maxX - 24 } ?? false
                    let now = Date().timeIntervalSinceReferenceDate
                    if travelMemory.canDepart(at: now) && (Date() >= nextTransferAt || (atEdge && Date() >= nextEdgeAttemptAt)) {
                        let plans = PetTravel.transfers(from: CGPoint(x: foot, y: position.y), sourceID: support.windowID,
                            platforms: platforms, area: area, bodyHeight: profile.bodyHeight,
                            jumpAbility: profile.isUsagi ? .usagi : .standard)
                            .filter { travelMemory.canVisit($0.destinationID, at: now) }
                        let fresh = plans.filter { $0.destinationID != lastVisitedWindowID }
                        if let plan = PetTravel.choose(fresh.isEmpty ? plans : fresh, fromY: position.y, preference: transferPreference) {
                            travelMemory.left(support.windowID, at: now)
                            flight = plan; velocity = plan.velocity
                            lastVisitedWindowID = support.windowID
                            let dy = plan.destination.y - position.y
                            transferPreference = dy > 25 ? 1 : (abs(dy) <= 25 ? 2 : 0)
                            mode = "jump"
                        }
                        nextTransferAt = Date().addingTimeInterval(Double.random(in: 3...6))
                        nextEdgeAttemptAt = Date().addingTimeInterval(0.8)
                    }
                    if flight == nil {
                        if let safeSupport {
                            if foot >= min(safeSupport.rect.maxX - 8, area.maxX - 57) { velocity.x = -walkSpeed }
                            if foot <= max(safeSupport.rect.minX + 8, area.minX + 57) { velocity.x = walkSpeed }
                        } else {
                            // A moved foreground window may cover the current spot. Leave it;
                            // never rest or turn back into the covered part of the roof.
                            let available = platforms.filter { $0.windowID == support.windowID }
                            if let nearest = available.min(by: { abs($0.rect.midX - foot) < abs($1.rect.midX - foot) }) {
                                velocity.x = nearest.rect.midX > foot ? walkSpeed : -walkSpeed
                            } else { beginFall(toFloor: true) }
                        }
                    }
                }
            }
        } else {
            velocity.y -= 650 * dt
            mode = velocity.y > 0 ? "jump" : "fall"
        }
        if mode == "rest" || mode == "happy" { return }
        let oldY = position.y
        position.x += velocity.x * dt; position.y += velocity.y * dt
        if velocity.y <= 0 {
            if !droppingToFloor, let landing = PetTravel.landing(on: platforms, x: position.x + 57,
                                                                oldY: oldY, newY: position.y,
                                                                ignoring: flight?.sourceID) {
                position.y = landing.rect.minY; velocity.y = 0; attachedWindowID = landing.windowID
                flight = nil; travelMemory.landed(on: landing.windowID, at: Date().timeIntervalSinceReferenceDate)
                nextTransferAt = Date().addingTimeInterval(Double.random(in: 5...8))
                velocity.x = velocity.x < 0 ? -walkSpeed : walkSpeed
            }
            if position.y <= area.minY {
                position.y = area.minY; velocity.y = 0; droppingToFloor = false; attachedWindowID = nil; flight = nil
                velocity.x = velocity.x < 0 ? -walkSpeed : walkSpeed
            }
        }
        position.y = min(position.y, area.maxY - profile.bodyHeight)
        if position.x < area.minX { position.x = area.minX; velocity.x = abs(velocity.x) }
        if position.x > area.maxX - 114 { position.x = area.maxX - 114; velocity.x = -abs(velocity.x) }
    }
    func step() {
        ticks += 1
        petView.tickAnimation()
        if ticks % 3 == 1 { scanWindows() }
        let screen = selectedScreen
        if mode == "held" { updateOcclusion(); return }
        let area = screen.visibleFrame
        if mode == "notify", let dest = target {
            let dx = dest.x - position.x, dy = dest.y - position.y
            let distance = hypot(dx, dy)
            if distance > 5 {
                position.x += dx / distance * min(profile.style.alertSpeed / 30, distance)
                position.y += dy / distance * min(profile.style.alertSpeed / 30, distance)
            } else {
                position = dest
                if notificationUntil == .distantPast {
                    // Keep the alert visible until the user dismisses it or opens the work panel.
                    notificationUntil = .distantFuture
                    showNotificationBubble()
                }
            }
            if mode == "notify" && notificationUntil != .distantPast {
                positionNotificationBubble()
            }
        } else if (mode == "rest" || mode == "happy") && Date() < leisureUntil {
            let support = attachedWindowID.flatMap { id in windows.first { $0.id == id } }
            let supported = abs(position.y - area.minY) < 3 || support.map {
                position.x + 57 > $0.rect.minX && position.x + 57 < $0.rect.maxX && abs(position.y - $0.rect.maxY) < 5
            } == true
            if !supported { beginFall(toFloor: true) }
            else if attachedWindowID != nil && !platforms.contains(where: {
                $0.windowID == attachedWindowID && position.x + 57 > $0.rect.minX && position.x + 57 < $0.rect.maxX
            }) { mode = "walk"; leisureUntil = .distantPast }
        } else if !paused || droppingToFloor {
            movePet(in: area)
        }
        updateOcclusion()
        let runningToNotification = mode == "notify" && notificationUntil == .distantPast
        let facingRight = runningToNotification ? (target?.x ?? position.x) > position.x : velocity.x > 0
        petView.display(runningToNotification ? "run" : mode, movingRight: facingRight)
        placePet()
    }
    func positionNotificationBubble() {
        guard let placement = notificationPlacement else { return }
        bubble.setFrame(CGRect(x: position.x + 57 - placement.bubble.width / 2,
                               y: position.y + 136, width: placement.bubble.width, height: placement.bubble.height), display: true)
    }
    func showNotificationBubble() {
        guard let placement = notificationPlacement else { return }
        let count = store.items.filter { $0.state == .inbox }.count
        bubble.contentView = NSHostingView(rootView:
            VStack(spacing: 6) {
                Text(profile.greeting).font(.system(size: placement.bubble.width < 180 ? 14 : 17, weight: .semibold))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text(profile.alertDetail(bomCount: count)).font(.system(size: 10)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button("업무 보기") { [weak self] in self?.showBoard(); self?.dismissNotification() }
                    Button("닫기") { [weak self] in self?.dismissNotification() }
                }.font(.system(size: 11)).buttonStyle(.borderless)
            }.padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 18)
                .frame(width: placement.bubble.width, height: placement.bubble.height)
                .background(SmallSpeechBubble().fill(Color.white)))
        positionNotificationBubble()
        bubble.orderFrontRegardless()
    }
    func clearNotification() {
        bubble?.orderOut(nil)
        notifications.release(profile.kind)
        notificationPlacement = nil
        notificationUntil = .distantPast
    }
    func dismissNotification() { clearNotification(); mode = "fall"; target = nil; velocity.y = 0 }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = WorkStore()
    let notifications = NotificationCoordinator()
    var companions: [PetController] = []
    var status: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--preview-character") {
            renderCharacterPreview(); return
        }
        if CommandLine.arguments.contains("--preview-board") {
            let controller = PetController(profile: CharacterProfile(isHachiware: true), store: store)
            companions = [controller]
            controller.renderBoardPreview(); return
        }
        for profile in CharacterProfile.all {
            let controller = PetController(profile: profile, store: store, notifications: notifications)
            companions.append(controller)
            controller.start()
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = ""
        if let url = spriteURL("MenuBarBanner.png"), let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 64, height: 20)
            icon.isTemplate = false
            status.button?.image = icon
        } else {
            status.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "먼작귀")
        }
        status.button?.imagePosition = .imageOnly
        status.button?.imageScaling = .scaleProportionallyDown
        status.button?.toolTip = "먼작귀"
        status.button?.setAccessibilityLabel("먼작귀")
        let menu = NSMenu()
        for controller in companions {
            let item = NSMenuItem(title: "\(controller.profile.name) · \(controller.profile.role)", action: nil, keyEquivalent: "")
            item.submenu = controller.menu
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let testAll = NSMenuItem(title: "모두 테스트 알림", action: #selector(notifyAll), keyEquivalent: "")
        testAll.target = self; menu.addItem(testAll)
        let quit = NSMenuItem(title: "모두 종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        status.menu = menu
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                runSmokeTest()
                NSApp.terminate(nil)
            }
        }
    }
    @objc func notifyAll() { companions.forEach { $0.notify() } }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        companions.forEach { $0.timer?.invalidate() }
    }
    func runSmokeTest() {
        precondition(companions.count == 3)
        let chi = companions[0], hachi = companions[1], usagi = companions[2]
        precondition(!chi.profile.isHachiware && hachi.profile.isHachiware)
        precondition(chi.store === hachi.store)
        precondition(chi.petView.profile.isHachiware == false && hachi.petView.profile.isHachiware)
        chi.petView.display("walk"); hachi.petView.display("walk")
        precondition(chi.petView.currentAssetName == "Chiikawa Walk.gif")
        precondition(hachi.petView.currentAssetName == "Hachiware Walk.gif")
        precondition(chi.petView.hasLoadedArtwork && hachi.petView.hasLoadedArtwork)
        hachi.togglePause()
        precondition(hachi.paused && !chi.paused)
        hachi.togglePause()
        hachi.previewRest()
        precondition(hachi.mode == "rest" && chi.mode != "rest")
        precondition(hachi.petView.currentAssetName == "Hachiware sit.gif")
        hachi.notify()
        precondition(hachi.petView.currentAssetName == "Hachiware run.gif")
        precondition(chi.mode != "notify")
        hachi.position = hachi.target!
        hachi.step()
        precondition(hachi.petView.currentAssetName == "Hachiware talk.gif")
        precondition(hachi.bubble.isVisible)
        precondition(hachi.pet.frame.minY == hachi.position.y - hachi.profile.bottomPadding)
        precondition(usagi.profile.isUsagi && usagi.profile.style.walkSpeed > hachi.profile.style.walkSpeed)
        precondition(usagi.store === hachi.store && usagi.notifications === chi.notifications)
        for pose in ["walk", "held", "rest", "fall", "happy", "run", "notify"] {
            usagi.petView.display(pose)
            precondition(usagi.petView.hasLoadedArtwork)
        }
        notifyAll()
        for character in companions {
            character.position = character.target!
            character.step()
            precondition(character.bubble.isVisible)
            precondition(character.petView.currentAssetName == character.profile.asset(for: "notify"))
        }
        precondition(usagi.petView.currentAssetName == "Usagi Scream.gif")
        precondition(usagi.profile.greeting == "이야아아아하!!!!!!!")
        for i in companions.indices {
            for j in companions.indices where j > i {
                precondition(!companions[i].bubble.frame.intersects(companions[j].bubble.frame))
                precondition(!companions[i].pet.frame.intersects(companions[j].pet.frame))
            }
        }
        renderNotificationPreview(for: companions)
        let oldTargets = companions.map(\.target)
        chi.dismissNotification()
        precondition(hachi.target == oldTargets[1] && usagi.target == oldTargets[2])
        precondition(hachi.bubble.isVisible && usagi.bubble.isVisible)
        chi.notify()
        precondition(chi.target == oldTargets[0])
        precondition(PetController.boardWindowNumbers.count == 3)
        precondition(chi.board.title == "치이카와 · 자동화 검수" && hachi.board.title == "하치와레 · BOM 업무")
        precondition(status.menu?.items.count == 6)
        precondition(status.button?.title == "" && status.button?.image != nil)
        precondition(status.button?.toolTip == "먼작귀")
        print("Unified app checks passed: three independent pets, correct roles and 7 Usagi assets, independent poses, shared store, 3 simultaneous nonoverlapping alerts, stable/reusable notification slots, one icon menu")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
