import CoreGraphics
import Foundation

func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs == rhs, "Expected \(rhs), got \(lhs)") }
func XCTAssertTrue(_ condition: Bool) { precondition(condition) }
func XCTAssertFalse(_ condition: Bool) { precondition(!condition) }

final class GeometryTests {
    let back = WindowShape(id: 1, rect: CGRect(x: 100, y: 100, width: 500, height: 400))
    let front = WindowShape(id: 2, rect: CGRect(x: 200, y: 100, width: 200, height: 200))
    func testBehindWindowStillDefinesOuterRoof() {
        let roof = WindowGeometry.skyline([front, back])
        XCTAssertEqual(roof.count, 1)
        XCTAssertEqual(roof[0].windowID, back.id)
        XCTAssertEqual(roof[0].rect, CGRect(x: 100, y: 500, width: 500, height: 0))
    }
    func testStaircaseEnvelopeIgnoresStackingOrder() {
        let tall = WindowShape(id: 3, rect: CGRect(x: 350, y: 150, width: 400, height: 500))
        let a = WindowGeometry.skyline([tall, back])
        XCTAssertEqual(a, WindowGeometry.skyline([back, tall]))
        XCTAssertEqual(a.map(\.rect), [CGRect(x: 100, y: 500, width: 250, height: 0), CGRect(x: 350, y: 650, width: 400, height: 0)])
    }
    func testDisconnectedWindowsLeaveGap() {
        let other = WindowShape(id: 3, rect: CGRect(x: 800, y: 100, width: 200, height: 200))
        XCTAssertEqual(WindowGeometry.skyline([back, other]).count, 2)
    }
    func testOnlyForegroundWindowsOccludeAttachedPet() {
        XCTAssertEqual(WindowGeometry.occluders([front, back], attachedTo: 1), [front.rect])
        XCTAssertTrue(WindowGeometry.occluders([front, back], attachedTo: 2).isEmpty)
        XCTAssertEqual(WindowGeometry.occluders([back, front], attachedTo: 1), [])
    }
    func testOverlappingOccludersDoNotRevealPet() {
        let regions = WindowGeometry.visibleRegions(CGRect(x: 0, y: 0, width: 100, height: 100), behind: [CGRect(x: 20, y: 0, width: 50, height: 100), CGRect(x: 40, y: 0, width: 50, height: 100)])
        XCTAssertEqual(regions.reduce(CGFloat(0)) { $0 + $1.width * $1.height }, 3000)
        XCTAssertFalse(regions.contains { $0.contains(CGPoint(x: 50, y: 50)) })
    }
    func testFullOcclusionAndMissingWindow() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(WindowGeometry.visibleRegions(bounds, behind: [bounds]).isEmpty)
        XCTAssertTrue(WindowGeometry.skyline([]).isEmpty)
        XCTAssertEqual(WindowGeometry.visibleRegions(bounds, behind: []), [bounds])
    }
    func testSkylineWallsUseBothOutsideEdges() {
        let walls = WindowGeometry.walls([front, back], skyline: WindowGeometry.skyline([front, back]))
        XCTAssertEqual(walls.map(\.x), [100, 600])
        XCTAssertEqual(walls.map(\.inward), [1, -1])
    }
    func testAllRoofsAreAvailableRegardlessOfDepth() {
        let roofs = PetTravel.platforms([front, back])
        XCTAssertEqual(Set(roofs.map(\.windowID)), Set([1, 2]))
        XCTAssertEqual(roofs.count, PetTravel.platforms([back, front]).count)
    }
    func testDropOntoOverlappingLowerWindow() {
        let roofs = PetTravel.platforms([back, front])
        let plans = PetTravel.transfers(from: CGPoint(x: 300, y: 500), sourceID: 1, platforms: roofs, area: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        XCTAssertEqual(plans.count, 1)
        let plan = plans[0]
        XCTAssertEqual(plan.destinationID, 2)
        XCTAssertEqual(plan.velocity.x, 0)
        XCTAssertTrue(plan.velocity.y < 200)
        let endY = 500 + plan.velocity.y * plan.duration - PetTravel.gravity * plan.duration * plan.duration / 2
        XCTAssertTrue(abs(endY - 300) < 0.01)
    }
    func testNearbyHigherWindowIsReachableButDistantWindowIsNot() {
        let near = WindowShape(id: 3, rect: CGRect(x: 420, y: 100, width: 200, height: 280))
        let far = WindowShape(id: 4, rect: CGRect(x: 1400, y: 100, width: 200, height: 280))
        let roofs = PetTravel.platforms([front, near, far])
        let plans = PetTravel.transfers(from: CGPoint(x: 350, y: 300), sourceID: 2, platforms: roofs, area: CGRect(x: 0, y: 0, width: 2000, height: 1200))
        XCTAssertEqual(plans.map(\.destinationID), [3])
    }
    func testDescentLandsOnHighestCrossedRoof() {
        let roofs = PetTravel.platforms([front, back])
        XCTAssertEqual(PetTravel.landing(on: roofs, x: 300, oldY: 550, newY: 250, ignoring: nil)?.windowID, 1)
        XCTAssertEqual(PetTravel.landing(on: roofs, x: 300, oldY: 550, newY: 250, ignoring: 1)?.windowID, 2)
    }
    func testDropDoesNotTargetRoofBelowAnInterveningRoof() {
        let middle = WindowShape(id: 3, rect: CGRect(x: 200, y: 100, width: 200, height: 300))
        let plans = PetTravel.transfers(from: CGPoint(x: 300, y: 500), sourceID: 1, platforms: PetTravel.platforms([back, middle, front]), area: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        XCTAssertEqual(plans.map(\.destinationID), [3])
    }
    func testJumpRespectsScreenCeiling() {
        let plans = PetTravel.transfers(from: CGPoint(x: 300, y: 300), sourceID: 2, platforms: PetTravel.platforms([back, front]), area: CGRect(x: 0, y: 0, width: 1600, height: 450))
        XCTAssertTrue(plans.isEmpty)
        let drops = PetTravel.transfers(from: CGPoint(x: 300, y: 500), sourceID: 1, platforms: PetTravel.platforms([back, front]), area: CGRect(x: 0, y: 0, width: 1600, height: 608))
        XCTAssertEqual(drops.count, 1)
        XCTAssertEqual(drops[0].velocity.y, 0)
    }

    func testCoveredRoofSplitWithBodyClearance() {
        let lower = WindowShape(id: 10, rect: CGRect(x: 0, y: 0, width: 600, height: 300))
        let cover = WindowShape(id: 11, rect: CGRect(x: 200, y: 200, width: 200, height: 300))
        let safe = PetTravel.playablePlatforms([cover, lower]).filter { $0.windowID == 10 }
        XCTAssertEqual(safe.map(\.rect), [CGRect(x: 0, y: 300, width: 143, height: 0), CGRect(x: 457, y: 300, width: 143, height: 0)])
    }
    func testWindowBelowFeetDoesNotBlockPlaying() {
        XCTAssertEqual(PetTravel.playablePlatforms([front, back]), PetTravel.platforms([front, back]))
    }
    func testFullyCoveredRoofIsNotAPlayOrLandingTarget() {
        let cover = WindowShape(id: 12, rect: CGRect(x: 0, y: 100, width: 700, height: 500))
        let safe = PetTravel.playablePlatforms([cover, front])
        XCTAssertFalse(safe.contains { $0.windowID == front.id })
        let plans = PetTravel.transfers(from: CGPoint(x: 300, y: 600), sourceID: 12, platforms: safe, area: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        XCTAssertTrue(plans.isEmpty)
        XCTAssertEqual(PetTravel.playablePlatforms([front, cover]).first?.windowID, front.id)
    }
    func testCoverAboveFeetButTouchingBodyBlocksWalking() {
        let cover = WindowShape(id: 13, rect: CGRect(x: 200, y: 350, width: 200, height: 200))
        let safe = PetTravel.playablePlatforms([cover, front]).filter { $0.windowID == front.id }
        XCTAssertTrue(safe.isEmpty)
    }

    func testHigherAndSidewaysJumpsAndDirectionChoice() {
        let source = WindowShape(id: 20, rect: CGRect(x: 100, y: 0, width: 200, height: 300))
        let up = WindowShape(id: 21, rect: CGRect(x: 310, y: 0, width: 200, height: 450))
        let side = WindowShape(id: 22, rect: CGRect(x: 520, y: 0, width: 200, height: 300))
        let down = WindowShape(id: 23, rect: CGRect(x: 0, y: 0, width: 100, height: 180))
        let area = CGRect(x: 0, y: 0, width: 1600, height: 1100)
        let upper = PetTravel.transfers(from: CGPoint(x: 280, y: 300), sourceID: 20, platforms: PetTravel.platforms([source, up]), area: area)
        let sideways = PetTravel.transfers(from: CGPoint(x: 280, y: 300), sourceID: 20, platforms: PetTravel.platforms([source, side]), area: area)
        let lower = PetTravel.transfers(from: CGPoint(x: 280, y: 300), sourceID: 20, platforms: PetTravel.platforms([source, down]), area: area)
        XCTAssertEqual(upper.first?.destinationID, 21)
        XCTAssertEqual(sideways.first?.destinationID, 22)
        let all = upper + sideways + lower
        XCTAssertEqual(PetTravel.choose(all, fromY: 300, preference: 0)?.destinationID, 21)
        XCTAssertEqual(PetTravel.choose(all, fromY: 300, preference: 1)?.destinationID, 22)
        XCTAssertEqual(PetTravel.choose(all, fromY: 300, preference: 2)?.destinationID, 23)
    }

    func testNearlyIdenticalRoofsDoNotCauseStationaryJumps() {
        let a = WindowShape(id: 30, rect: CGRect(x: 100, y: 0, width: 400, height: 300))
        let b = WindowShape(id: 31, rect: CGRect(x: 105, y: 0, width: 400, height: 310))
        let plans = PetTravel.transfers(from: CGPoint(x: 300, y: 300), sourceID: 30, platforms: PetTravel.platforms([a,b]), area: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        XCTAssertTrue(plans.isEmpty)
    }
    func testLandingDwellAndReturnCooldown() {
        var memory = TravelMemory()
        memory.landed(on: 1, at: 100)
        XCTAssertFalse(memory.canDepart(at: 104.99))
        XCTAssertTrue(memory.canDepart(at: 105))
        XCTAssertFalse(memory.canVisit(1, at: 117.99))
        XCTAssertTrue(memory.canVisit(1, at: 118))
        memory.landed(on: 2, at: 108)
        XCTAssertFalse(memory.canDepart(at: 112))
        XCTAssertFalse(memory.canVisit(1, at: 112))
        XCTAssertTrue(memory.canVisit(3, at: 112))
        memory.left(2, at: 140)
        XCTAssertFalse(memory.canVisit(2, at: 145))
        XCTAssertTrue(memory.canVisit(2, at: 158))
    }
    func testLowerProtrudingWindowAlsoHasClimbableSides() {
        let upper = WindowShape(id: 40, rect: CGRect(x: 100, y: 200, width: 400, height: 400))
        let lower = WindowShape(id: 41, rect: CGRect(x: 200, y: 50, width: 200, height: 300))
        let windows = [lower, upper]
        let walls = WindowGeometry.climbWalls(windows, playable: PetTravel.playablePlatforms(windows))
        XCTAssertEqual(Set(walls.map(\.windowID)), Set([40,41]))
        let contained = WindowShape(id: 42, rect: CGRect(x: 200, y: 250, width: 200, height: 150))
        let containedWindows = [contained, upper]
        XCTAssertFalse(WindowGeometry.climbWalls(containedWindows, playable: PetTravel.playablePlatforms(containedWindows)).contains { $0.windowID == 42 })
    }

    func testForegroundWindowRemovesCoveredFooting() {
        let roof = WindowShape(id: 50, rect: CGRect(x: 100, y: 100, width: 600, height: 300))
        let other = WindowShape(id: 51, rect: CGRect(x: 250, y: 200, width: 300, height: 400))
        let foot = CGPoint(x: 400, y: 400)
        XCTAssertTrue(WindowGeometry.hasVisibleFooting([roof, other], on: 50, at: foot))
        XCTAssertFalse(WindowGeometry.hasVisibleFooting([other, roof], on: 50, at: foot))
        XCTAssertTrue(WindowGeometry.hasVisibleFooting([other, roof], on: 50, at: CGPoint(x: 150, y: 400)))
        XCTAssertFalse(WindowGeometry.hasVisibleFooting([other], on: 50, at: foot))
    }
    func testUpperBodyOcclusionDoesNotRemoveVisibleLedge() {
        let roof = WindowShape(id: 52, rect: CGRect(x: 100, y: 100, width: 600, height: 300))
        let hovering = WindowShape(id: 53, rect: CGRect(x: 250, y: 450, width: 300, height: 200))
        XCTAssertTrue(WindowGeometry.hasVisibleFooting([hovering, roof], on: 52, at: CGPoint(x: 400, y: 400)))
        XCTAssertFalse(WindowGeometry.hasVisibleFooting([roof], on: 52, at: CGPoint(x: 400, y: 420)))
    }

    func testClimbingUsesLessVisitedSide() {
        let w = WindowShape(id: 60, rect: CGRect(x: 100, y: 100, width: 500, height: 400))
        let walls = WindowGeometry.climbWalls([w], playable: PetTravel.platforms([w]))
        var counts: [Int: Int] = [:]
        for _ in 0..<20 {
            let selected = WindowGeometry.balancedClimbWall(walls, lastWindowID: 60, windowVisits: [:], sideVisits: counts)!
            counts[Int(selected.inward), default: 0] += 1
        }
        XCTAssertEqual(counts[1], 10)
        XCTAssertEqual(counts[-1], 10)
        let rightOnly = walls.filter { $0.inward == -1 }
        XCTAssertEqual(WindowGeometry.balancedClimbWall(rightOnly, lastWindowID: nil, windowVisits: [:], sideVisits: [-1: 20])?.inward, -1)
        XCTAssertTrue(WindowGeometry.balancedClimbWall([], lastWindowID: nil, windowVisits: [:], sideVisits: [:]) == nil)
    }

    func testCharacterSpeedsReflectTemperament() {
        XCTAssertTrue(CompanionMotion.usagi.walkSpeed > CompanionMotion.hachiware.walkSpeed)
        XCTAssertTrue(CompanionMotion.hachiware.walkSpeed > CompanionMotion.chiikawa.walkSpeed)
        XCTAssertTrue(CompanionMotion.chiikawa.walkSpeed > CompanionMotion.shisa.walkSpeed)
        XCTAssertTrue(CompanionMotion.hachiware.climbSpeed > CompanionMotion.chiikawa.climbSpeed)
        XCTAssertTrue(CompanionMotion.usagi.restPeriod > CompanionMotion.hachiware.restPeriod)
    }

    func testThreeAlertsStaySideBySideWithoutOverlap() {
        let area = CGRect(x: -1600, y: 80, width: 1600, height: 900)
        let slots = NotificationLayout.placements(in: area, count: 3)
        XCTAssertEqual(slots.count, 3)
        for (i, slot) in slots.enumerated() {
            XCTAssertTrue(area.contains(slot.bubble))
            XCTAssertEqual(slot.petOrigin.y, area.minY + 8)
            XCTAssertEqual(slot.bubble.midX, slot.petOrigin.x + 57)
            for j in slots.indices where j > i { XCTAssertFalse(slot.bubble.intersects(slots[j].bubble)) }
        }
        XCTAssertEqual(slots[1].bubble.midX, area.midX)
    }
    func testNotificationReservationsAreStableAndReusable() {
        let area = CGRect(x: 0, y: 0, width: 1440, height: 900)
        var reservations = NotificationReservations()
        let chi = reservations.reserve("chi", in: area, capacity: 3)
        XCTAssertEqual(chi.bubble.midX, area.midX)
        let hachi = reservations.reserve("hachi", in: area, capacity: 3)
        let usagi = reservations.reserve("usagi", in: area, capacity: 3)
        XCTAssertFalse(chi.bubble.intersects(hachi.bubble))
        XCTAssertFalse(hachi.bubble.intersects(usagi.bubble))
        XCTAssertEqual(reservations.reserve("chi", in: area, capacity: 3), chi)
        reservations.release("chi")
        XCTAssertEqual(reservations.reserve("hachi", in: area, capacity: 3), hachi)
        XCTAssertEqual(reservations.reserve("usagi", in: area, capacity: 3), usagi)
        XCTAssertEqual(reservations.reserve("chi", in: area, capacity: 3), chi)
    }
    func testAlertLayoutAdaptsToNarrowDisplay() {
        let area = CGRect(x: 120, y: 30, width: 420, height: 900)
        let slots = NotificationLayout.placements(in: area, count: 3)
        for i in slots.indices {
            XCTAssertTrue(area.contains(slots[i].bubble))
            for j in slots.indices where j > i { XCTAssertFalse(slots[i].bubble.intersects(slots[j].bubble)) }
        }
        XCTAssertTrue(NotificationLayout.placements(in: area, count: 0).isEmpty)
    }
    func testReservedSlotMovesWithDisplayCoordinates() {
        var reservations = NotificationReservations()
        let first = reservations.reserve("usagi", in: CGRect(x: 0, y: 0, width: 1440, height: 900), capacity: 3)
        let moved = reservations.reserve("usagi", in: CGRect(x: -1440, y: 100, width: 1440, height: 900), capacity: 3)
        XCTAssertEqual(moved.petOrigin.x, first.petOrigin.x - 1440)
        XCTAssertEqual(moved.petOrigin.y, first.petOrigin.y + 100)
    }
    func testTallEarsAreIncludedInJumpCeilingCheck() {
        let destination = Platform(windowID: 2, rect: CGRect(x: 350, y: 420, width: 250, height: 0))
        let area = CGRect(x: 0, y: 0, width: 1440, height: 532)
        XCTAssertEqual(PetTravel.transfers(from: CGPoint(x: 300, y: 300), sourceID: 1, platforms: [destination], area: area).count, 1)
        XCTAssertTrue(PetTravel.transfers(from: CGPoint(x: 300, y: 300), sourceID: 1, platforms: [destination], area: area, bodyHeight: 132).isEmpty)
    }

    func testUsagiYellowReferencesMatchOneCoatColor() {
        for tone in [CoatTone(250,244,204), CoatTone(252,242,205), CoatTone(255,243,213), CoatTone(253,239,203), CoatTone(252,239,193), CoatTone(249,232,196), CoatTone(252,238,204), CoatTone(248,240,205)] {
            let mapped = CoatTone.matched(tone.r, tone.g, tone.b, reference: tone)
            XCTAssertEqual(mapped.0, 252); XCTAssertEqual(mapped.1, 242); XCTAssertEqual(mapped.2, 205)
        }
    }
    func testCoatMatchingPreservesCheeksEarsWhitesAndOutlines() {
        for tone in [CoatTone(255,180,197), CoatTone(249,194,202), CoatTone(255,255,255), CoatTone(50,30,20), CoatTone(140,110,80)] {
            let mapped = CoatTone.matched(tone.r, tone.g, tone.b, reference: .usagi)
            XCTAssertEqual(mapped.0, tone.r); XCTAssertEqual(mapped.1, tone.g); XCTAssertEqual(mapped.2, tone.b)
        }
    }
    func testCoatMatchingRetainsShading() {
        let shadow = CoatTone.matched(245,235,195, reference: .usagi)
        XCTAssertTrue(shadow.0 < 252 && shadow.1 < 242 && shadow.2 < 205)
        XCTAssertTrue(abs((shadow.0 - shadow.1) - 10) < 0.001)
    }

}

@main struct GeometryChecks {
    static func main() {
        let checks = GeometryTests()
        checks.testBehindWindowStillDefinesOuterRoof()
        checks.testStaircaseEnvelopeIgnoresStackingOrder()
        checks.testDisconnectedWindowsLeaveGap()
        checks.testOnlyForegroundWindowsOccludeAttachedPet()
        checks.testOverlappingOccludersDoNotRevealPet()
        checks.testFullOcclusionAndMissingWindow()
        checks.testSkylineWallsUseBothOutsideEdges()
        checks.testAllRoofsAreAvailableRegardlessOfDepth()
        checks.testDropOntoOverlappingLowerWindow()
        checks.testNearbyHigherWindowIsReachableButDistantWindowIsNot()
        checks.testDescentLandsOnHighestCrossedRoof()
        checks.testDropDoesNotTargetRoofBelowAnInterveningRoof()
        checks.testJumpRespectsScreenCeiling()
        checks.testCoveredRoofSplitWithBodyClearance()
        checks.testWindowBelowFeetDoesNotBlockPlaying()
        checks.testFullyCoveredRoofIsNotAPlayOrLandingTarget()
        checks.testCoverAboveFeetButTouchingBodyBlocksWalking()
        checks.testHigherAndSidewaysJumpsAndDirectionChoice()
        checks.testNearlyIdenticalRoofsDoNotCauseStationaryJumps()
        checks.testLandingDwellAndReturnCooldown()
        checks.testLowerProtrudingWindowAlsoHasClimbableSides()
        checks.testForegroundWindowRemovesCoveredFooting()
        checks.testUpperBodyOcclusionDoesNotRemoveVisibleLedge()
        checks.testClimbingUsesLessVisitedSide()
        checks.testCharacterSpeedsReflectTemperament()
        checks.testThreeAlertsStaySideBySideWithoutOverlap()
        checks.testNotificationReservationsAreStableAndReusable()
        checks.testAlertLayoutAdaptsToNarrowDisplay()
        checks.testReservedSlotMovesWithDisplayCoordinates()
        checks.testTallEarsAreIncludedInJumpCeilingCheck()
        checks.testUsagiYellowReferencesMatchOneCoatColor()
        checks.testCoatMatchingPreservesCheeksEarsWhitesAndOutlines()
        checks.testCoatMatchingRetainsShading()
        print("33 geometry, movement, notification and coat checks passed")
    }
}
