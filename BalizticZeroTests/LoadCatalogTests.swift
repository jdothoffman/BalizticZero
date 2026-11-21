import XCTest
@testable import BalizticZero

final class LoadCatalogTests: XCTestCase {
    func testSample308MatchesThe175Preset() {
        let profile = LoadProfile.standard308()
        let preset = LoadCatalog.preset(matching: profile.loadIdentity)
        XCTAssertEqual(preset?.id, "308-175")
        XCTAssertEqual(LoadCatalog.cartridge(for: profile.loadIdentity)?.id, "308")
        XCTAssertEqual(LoadCatalog.bullet(matching: profile.loadIdentity)?.id, "308-175-smk")
    }

    func testPublishedMatchCoefficients() {
        let creedmoor = LoadCatalog.bullet(id: "65-140-eldm")
        XCTAssertEqual(creedmoor?.g7 ?? 0, 0.326, accuracy: 0.0001)
        XCTAssertEqual(creedmoor?.g1 ?? 0, 0.646, accuracy: 0.0001)
        XCTAssertEqual(LoadCatalog.bullet(id: "338-285-eldm")?.g7 ?? 0, 0.417, accuracy: 0.0001)
    }

    func testSameBulletPicksTheCartridgeThatFitsTheVelocity() {
        let identity = LoadIdentity(
            muzzleVelocityFps: 2750,
            bulletWeightGrains: 178,
            diameterInches: 0.308,
            lengthInches: 1.320,
            ballisticCoefficient: 0.275,
            dragModel: .g7,
            twistInches: 10
        )
        XCTAssertEqual(LoadCatalog.cartridge(for: identity)?.id, "3006")
    }

    func testEveryPresetUsesABulletItsCartridgeOffers() {
        for preset in LoadCatalog.presets {
            let cartridge = LoadCatalog.cartridge(id: preset.cartridgeID)
            XCTAssertNotNil(cartridge, preset.id)
            XCTAssertTrue(cartridge?.bullets.contains { $0.id == preset.bulletID } == true, preset.id)
            XCTAssertFalse(cartridge?.velocitiesFps.isEmpty == true)
            XCTAssertFalse(cartridge?.twistsInches.isEmpty == true)
        }
    }

    func testOddSavedVelocityStaysSelectable() {
        let choices = LoadCatalog.choices([2600, 2650, 2700], including: 2610, tolerance: 1)
        XCTAssertEqual(choices, [2600, 2610, 2650, 2700])
    }
}
