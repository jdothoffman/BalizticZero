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
        XCTAssertEqual(dial.turretReading, 4.6, accuracy: 0.001)
        XCTAssertEqual(dial.summary, "1 turn + 4.6 MRAD (46.0 clicks)")
    }

    func testMRADUnderOneTurnReadsStraightOffTheTurret() {
        let dial = ScopeDial.instruction(
            angleMOA: 7.3 * AngularScale.moaPerMil,
            clickUnit: .mil,
            clickValue: 0.1,
            travelPerTurnMOA: 10 * AngularScale.moaPerMil
        )
        XCTAssertEqual(dial.wholeTurns, 0)
        XCTAssertEqual(dial.summary, "7.3 MRAD (73.0 clicks)")
    }

    func testMRADExactTurnsDropTheRemainder() {
        let dial = ScopeDial.instruction(
            angleMOA: 20 * AngularScale.moaPerMil,
            clickUnit: .mil,
            clickValue: 0.1,
            travelPerTurnMOA: 10 * AngularScale.moaPerMil
        )
        XCTAssertEqual(dial.wholeTurns, 2)
        XCTAssertEqual(dial.summary, "2 turns")
    }

    func testMOAReadingUsesQuarterMinuteDecimals() {
        let dial = ScopeDial.instruction(angleMOA: 28.25, clickUnit: .moa, clickValue: 0.25, travelPerTurnMOA: 25)
        XCTAssertEqual(dial.summary, "1 turn + 3.25 MOA (13.0 clicks)")
    }

    func testSwitchingTurretToMRADUsesMRADStandards() {
        let settings = ScopeDial.turretSettings(changingFrom: .moa, to: .mil, clickValue: 0.25, travelPerTurnMOA: 25)
        XCTAssertEqual(settings.clickValue, 0.1)
        XCTAssertEqual(AngularScale.display(settings.travelPerTurnMOA, unit: .mil), 10, accuracy: 0.001)

        let back = ScopeDial.turretSettings(changingFrom: .mil, to: .moa, clickValue: 0.1, travelPerTurnMOA: settings.travelPerTurnMOA)
        XCTAssertEqual(back.clickValue, 0.25)
        XCTAssertEqual(back.travelPerTurnMOA, 25, accuracy: 0.001)
    }

    func testSwitchingTurretKeepsACustomTurnAngle() {
        let settings = ScopeDial.turretSettings(changingFrom: .moa, to: .mil, clickValue: 0.125, travelPerTurnMOA: 15)
        XCTAssertEqual(settings.clickValue, 0.1)
        XCTAssertEqual(settings.travelPerTurnMOA, 15)
    }

    func testSwitchingReticleToMRADUsesMRADHashes() {
        let stored = ScopeDial.hashSpacingMIL(changingFrom: .moa, to: .mil, storedMIL: AngularScale.oneMOAInMil)
        XCTAssertEqual(stored, 0.2, accuracy: 0.0001)
        let custom = ScopeDial.hashSpacingMIL(changingFrom: .moa, to: .mil, storedMIL: 0.5)
        XCTAssertEqual(custom, 0.5)
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
