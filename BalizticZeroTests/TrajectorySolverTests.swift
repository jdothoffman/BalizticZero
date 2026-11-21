import XCTest
@testable import BalizticZero

final class TrajectorySolverTests: XCTestCase {
    func testVacuumMatchesAnalyticDrop() {
        let load = BallisticLoad(
            muzzleVelocityFps: 3000,
            bulletWeightGrains: 150,
            diameterInches: 0.308,
            lengthInches: 1.2,
            ballisticCoefficient: 0.5,
            dragModel: .g7,
            sightHeightInches: 0,
            zeroRangeYards: 100,
            twistInches: 0,
            clickUnit: .moa,
            clickValue: 0.25
        )
        var vacuum = Atmosphere.icaoSeaLevel
        vacuum.stationPressureInHg = 0
        let sample = TrajectorySolver.integrate(
            load: load,
            atmosphere: vacuum,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            azimuthDegrees: 0,
            latitudeDegrees: nil,
            barrelElevationRadians: 0,
            horizontalFeet: [300]
        )?.first

        let time = 300.0 / 3000.0
        let expectedDrop = -0.5 * 32.17405 * time * time
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample?.verticalFeet ?? 0, expectedDrop, accuracy: 0.001)
        XCTAssertEqual(sample?.velocityFps ?? 0, 3000, accuracy: 0.05)
        XCTAssertEqual(sample?.crossFeet ?? 1, 0, accuracy: 0.0001)
    }

    func testG7PublishedCheckpoint() {
        let samples = publishedSamples(model: .g7, elevationRadians: 4.221 * .pi / 180 / 60, twist: 12)
        let expected: [(Double, Double, Double, Double, Double)] = [
            (100, 2545, 0.113, 0.0, -0.2),
            (500, 1814, 0.672, -56.2, -6.3),
            (1000, 1086, 1.748, -399.9, -31.6)
        ]
        assertPublished(samples, expected: expected, twist: 12, pathToleranceAt1000: 4, windageTolerance: 1.5)
    }

    func testG1PublishedCheckpoint() {
        let samples = publishedSamples(model: .g1, elevationRadians: 0.001228, twist: 0)
        let expected: [(Double, Double, Double, Double, Double)] = [
            (100, 2351.2, 0.118, 0.0, -0.6),
            (500, 1169.1, 0.857, -87.9, -19.5),
            (1000, 776.4, 2.495, -823.9, -87.5)
        ]
        assertPublished(samples, expected: expected, twist: 0, pathToleranceAt1000: 6, windageTolerance: 1.5)
    }

    func testZeroAngleMatchesReference() {
        let angle = TrajectorySolver.zeroAngleRadians(load: publishedLoad(model: .g7, twist: 12), atmosphere: .icaoSeaLevel)
        XCTAssertEqual(angle ?? 0, 0.0012286, accuracy: 0.0001)
    }

    func testZeroCrossesLineOfSight() {
        let load = publishedLoad(model: .g7, twist: 12)
        guard let angle = TrajectorySolver.zeroAngleRadians(load: load, atmosphere: .icaoSeaLevel) else {
            return XCTFail("Missing zero")
        }
        let sample = TrajectorySolver.integrate(
            load: load,
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            azimuthDegrees: 0,
            latitudeDegrees: nil,
            barrelElevationRadians: angle,
            horizontalFeet: [300]
        )?.first
        XCTAssertEqual((sample?.verticalFeet ?? 1) * 12, 0, accuracy: 0.1)
    }

    func testHeadwindDropsMoreThanTailwind() {
        let load = standardLoad()
        guard let angle = TrajectorySolver.zeroAngleRadians(load: load, atmosphere: .icaoSeaLevel) else {
            return XCTFail("Missing zero")
        }
        let head = path(load: load, elevation: angle, windFrom: 0)
        let tail = path(load: load, elevation: angle, windFrom: 180)
        XCTAssertLessThan(head, tail - 0.4)
    }

    func testCrosswindDeflectsMoreThanHeadwind() {
        let load = standardLoad()
        guard let angle = TrajectorySolver.zeroAngleRadians(load: load, atmosphere: .icaoSeaLevel) else {
            return XCTFail("Missing zero")
        }
        let cross = windage(load: load, elevation: angle, windFrom: 90, distanceFeet: 1500)
        let head = windage(load: load, elevation: angle, windFrom: 0, distanceFeet: 1500)
        XCTAssertLessThan(cross, -8.0 / 12)
        XCTAssertEqual(head, 0, accuracy: 2.0 / 12)
    }

    func testInclineReducesDrop() {
        let load = standardLoad()
        guard let zero = TrajectorySolver.zeroAngleRadians(load: load, atmosphere: .icaoSeaLevel) else {
            return XCTFail("Missing zero")
        }
        let flat = abs(slantInches(load: load, lookDegrees: 0, barrel: zero, slantYards: 800))
        let uphill = abs(slantInches(load: load, lookDegrees: 30, barrel: zero + 30 * .pi / 180, slantYards: 800))
        XCTAssertGreaterThan(flat, 20)
        XCTAssertLessThan(uphill, flat * 0.92)
    }

    func testCoriolisVerticalChangesSignWithAzimuth() {
        let load = standardLoad()
        guard let angle = TrajectorySolver.zeroAngleRadians(load: load, atmosphere: .icaoSeaLevel) else {
            return XCTFail("Missing zero")
        }
        let east = verticalFeet(load: load, elevation: angle, latitude: 45, azimuth: 90)
        let west = verticalFeet(load: load, elevation: angle, latitude: 45, azimuth: 270)
        let none = verticalFeet(load: load, elevation: angle, latitude: nil, azimuth: 90)
        XCTAssertGreaterThan(east - none, 0.4 / 12)
        XCTAssertLessThan(west - none, -0.4 / 12)

        let north = crossFeet(load: load, elevation: angle, latitude: 45, azimuth: 0)
        let southHemisphere = crossFeet(load: load, elevation: angle, latitude: -45, azimuth: 0)
        XCTAssertGreaterThan(north, 0.5 / 12)
        XCTAssertLessThan(southHemisphere, -0.5 / 12)
    }

    func testHotterAirReducesDrop() {
        var load = standardLoad()
        load.sightHeightInches = 0
        var cold = Atmosphere.icaoSeaLevel
        cold.temperatureF = 0
        var hot = Atmosphere.icaoSeaLevel
        hot.temperatureF = 100
        let coldDrop = height(load: load, atmosphere: cold)
        let hotDrop = height(load: load, atmosphere: hot)
        XCTAssertGreaterThan(hotDrop, coldDrop + 0.5)
    }

    func testSpinDriftIsToTheRightForRightHandTwist() {
        let load = standardLoad()
        let request = ShotRequest(
            load: load,
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            context: ShotContext(rangeYards: 1000, azimuthDegrees: 0, inclineDegrees: 0, latitudeDegrees: 0, longitudeDegrees: 0)
        )
        let solution = TrajectorySolver.solve(request)
        XCTAssertGreaterThan(solution?.spinDriftInches ?? 0, 2)
    }

    func testSolutionTableStepsByOneHundredYards() {
        let request = ShotRequest(
            load: standardLoad(),
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            context: ShotContext(rangeYards: 800, azimuthDegrees: 0, inclineDegrees: 0, latitudeDegrees: 0, longitudeDegrees: 0)
        )
        let rows = TrajectorySolver.solve(request)?.rows.map(\.rangeYards)
        XCTAssertEqual(rows ?? [], [100, 200, 300, 400, 500, 600, 700, 800])
        let pathAtZero = TrajectorySolver.solve(request)?.rows.first?.pathInches ?? 10
        XCTAssertEqual(pathAtZero, 0, accuracy: 0.2)
    }

    func testSeaLevelDensityIsNearStandard() {
        let ratio = AtmosphereModel.densityRatio(.icaoSeaLevel)
        XCTAssertEqual(ratio, 1, accuracy: 0.003)
        let sound = AtmosphereModel.speedOfSoundFps(.icaoSeaLevel)
        XCTAssertEqual(sound, 1116.5, accuracy: 1)
    }

    private func publishedLoad(model: DragModel, twist: Double) -> BallisticLoad {
        BallisticLoad(
            muzzleVelocityFps: 2750,
            bulletWeightGrains: 168,
            diameterInches: 0.308,
            lengthInches: 1.282,
            ballisticCoefficient: 0.223,
            dragModel: model,
            sightHeightInches: 2,
            zeroRangeYards: 100,
            twistInches: twist,
            clickUnit: .moa,
            clickValue: 0.25
        )
    }

    private func publishedSamples(model: DragModel, elevationRadians: Double, twist: Double) -> [TrajectorySample] {
        TrajectorySolver.integrate(
            load: publishedLoad(model: model, twist: twist),
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 5, fromDegrees: 135),
            azimuthDegrees: 0,
            latitudeDegrees: nil,
            barrelElevationRadians: elevationRadians,
            horizontalFeet: [300, 1500, 3000]
        ) ?? []
    }

    private func assertPublished(
        _ samples: [TrajectorySample],
        expected: [(Double, Double, Double, Double, Double)],
        twist: Double,
        pathToleranceAt1000: Double,
        windageTolerance: Double
    ) {
        XCTAssertEqual(samples.count, expected.count)
        for (sample, row) in zip(samples, expected) {
            let (yards, velocity, time, path, wind) = row
            let pathTolerance = yards >= 800 ? pathToleranceAt1000 : (yards >= 500 ? 2.0 : 0.5)
            let spin = spinInches(sample: sample, twist: twist, modelVelocity: 2750)
            XCTAssertEqual(sample.velocityFps, velocity, accuracy: 8, "velocity at \(yards)")
            XCTAssertEqual(sample.timeSeconds, time, accuracy: 0.02, "time at \(yards)")
            XCTAssertEqual(sample.verticalFeet * 12, path, accuracy: pathTolerance, "path at \(yards)")
            XCTAssertEqual(sample.crossFeet * 12 + spin, wind, accuracy: windageTolerance, "windage at \(yards)")
            let energy = 168 * sample.velocityFps * sample.velocityFps / 450400
            if yards == 100, velocity > 2400 {
                XCTAssertEqual(energy, 2416, accuracy: 8)
            }
        }
    }

    private func spinInches(sample: TrajectorySample, twist: Double, modelVelocity: Double) -> Double {
        guard twist != 0 else { return 0 }
        return SpinDrift.inches(
            timeSeconds: sample.timeSeconds,
            muzzleVelocityFps: modelVelocity,
            weightGrains: 168,
            diameterInches: 0.308,
            lengthInches: 1.282,
            twistInches: twist,
            temperatureF: 59,
            pressureInHg: 29.9212524
        )
    }

    private func standardLoad() -> BallisticLoad {
        BallisticLoad(
            muzzleVelocityFps: 2600,
            bulletWeightGrains: 175,
            diameterInches: 0.308,
            lengthInches: 1.24,
            ballisticCoefficient: 0.243,
            dragModel: .g7,
            sightHeightInches: 1.5,
            zeroRangeYards: 100,
            twistInches: 11.25,
            clickUnit: .moa,
            clickValue: 0.25
        )
    }

    private func path(load: BallisticLoad, elevation: Double, windFrom: Double) -> Double {
        TrajectorySolver.integrate(
            load: load,
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 20, fromDegrees: windFrom),
            azimuthDegrees: 0,
            latitudeDegrees: nil,
            barrelElevationRadians: elevation,
            horizontalFeet: [2400]
        )?.first?.verticalFeet ?? 0
    }

    private func windage(load: BallisticLoad, elevation: Double, windFrom: Double, distanceFeet: Double) -> Double {
        TrajectorySolver.integrate(
            load: load,
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 10, fromDegrees: windFrom),
            azimuthDegrees: 0,
            latitudeDegrees: nil,
            barrelElevationRadians: elevation,
            horizontalFeet: [distanceFeet]
        )?.first?.crossFeet ?? 0
    }

    private func slantInches(load: BallisticLoad, lookDegrees: Double, barrel: Double, slantYards: Double) -> Double {
        let look = lookDegrees * .pi / 180
        let sample = TrajectorySolver.integrate(
            load: load,
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            azimuthDegrees: 0,
            latitudeDegrees: nil,
            barrelElevationRadians: barrel,
            horizontalFeet: [slantYards * 3 * cos(look)]
        )?.first
        return (sample?.slantHeightFeet(lookAngleRadians: look) ?? 0) * 12
    }

    private func verticalFeet(load: BallisticLoad, elevation: Double, latitude: Double?, azimuth: Double) -> Double {
        TrajectorySolver.integrate(
            load: load,
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            azimuthDegrees: azimuth,
            latitudeDegrees: latitude,
            barrelElevationRadians: elevation,
            horizontalFeet: [3000]
        )?.first?.verticalFeet ?? 0
    }

    private func crossFeet(load: BallisticLoad, elevation: Double, latitude: Double, azimuth: Double) -> Double {
        TrajectorySolver.integrate(
            load: load,
            atmosphere: .icaoSeaLevel,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            azimuthDegrees: azimuth,
            latitudeDegrees: latitude,
            barrelElevationRadians: elevation,
            horizontalFeet: [3000]
        )?.first?.crossFeet ?? 0
    }

    private func height(load: BallisticLoad, atmosphere: Atmosphere) -> Double {
        TrajectorySolver.integrate(
            load: load,
            atmosphere: atmosphere,
            wind: Wind(speedMph: 0, fromDegrees: 0),
            azimuthDegrees: 0,
            latitudeDegrees: nil,
            barrelElevationRadians: 0,
            horizontalFeet: [2400]
        )?.first?.verticalFeet ?? 0
    }
}
