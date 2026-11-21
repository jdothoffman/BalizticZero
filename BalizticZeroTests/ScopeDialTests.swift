import XCTest
@testable import BalizticZero

final class ScopeDialTests: XCTestCase {
    func testTurnsAndRemainder() {
        let dial = ScopeDial.instruction(
            angleMOA: 14.6 * AngularScale.moaPerMil,
            clickUnit: .mil,
            clickValue: 0.1,
            travelPerTurnMOA: 10 * AngularScale.moaPerMil
        )
        XCTAssertEqual(dial.wholeTurns, 1)
        XCTAssertEqual(dial.remainderClicks, 46, accuracy: 0.05)
        XCTAssertEqual(dial.summary, "1 turn + 46.0 clicks")
    }

    func testElevationTravelIncludesTheRail() {
        let limit = ScopeDial.elevationLimit(
            comeUpMOA: 80,
            zeroAngleMOA: 4,
            elevationTravelMOA: 100,
            railCantMOA: 20,
            clickUnit: .moa
        )
        XCTAssertEqual(limit?.available ?? 0, 66, accuracy: 0.01)
        XCTAssertEqual(limit?.isOver, true)
        XCTAssertEqual(limit?.overBy ?? 0, 14, accuracy: 0.01)
    }

    func testWindageTravelIsHalfToEachSide() {
        let inside = ScopeDial.windageLimit(windageMOA: 10, windageTravelMOA: 80, clickUnit: .moa)
        let outside = ScopeDial.windageLimit(windageMOA: 50, windageTravelMOA: 80, clickUnit: .moa)
        XCTAssertEqual(inside?.isOver, false)
        XCTAssertEqual(outside?.isOver, true)
        XCTAssertEqual(outside?.overBy ?? 0, 10, accuracy: 0.01)
    }

    func testSecondFocalPlaneHoldScalesWithMagnification() {
        let indicated = ScopeDial.indicatedHold(
            angleMOA: 4 * AngularScale.moaPerMil,
            reticleUnit: .mil,
            focalPlane: .sfp,
            trueMagnification: 25,
            currentMagnification: 12.5
        )
        XCTAssertEqual(indicated, 2, accuracy: 0.01)
        let hashes = ScopeDial.hashCount(indicated: indicated, hashSpacing: 0.2)
        XCTAssertEqual(hashes ?? 0, 10, accuracy: 0.01)
    }

    func testFirstFocalPlaneHoldIgnoresMagnification() {
        let indicated = ScopeDial.indicatedHold(
            angleMOA: 4 * AngularScale.moaPerMil,
            reticleUnit: .mil,
            focalPlane: .ffp,
            trueMagnification: 25,
            currentMagnification: 12.5
        )
        XCTAssertEqual(indicated, 4, accuracy: 0.01)
    }
}
