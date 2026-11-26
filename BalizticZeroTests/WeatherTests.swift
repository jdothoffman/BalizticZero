import XCTest
@testable import BalizticZero

final class WeatherTests: XCTestCase {
    func testStationPressureEqualsSeaLevelAtSeaLevel() {
        XCTAssertEqual(Atmosphere.stationPressureInHg(seaLevelInHg: 30.10, altitudeFeet: 0), 30.10, accuracy: 0.0001)
    }

    func testStationPressureAtAltitudeFollowsTheStandardAtmosphere() {
        // ICAO standard atmosphere: 5,000 ft is 843.07 hPa, or 24.896 inHg, when sea level is standard.
        let station = Atmosphere.stationPressureInHg(seaLevelInHg: 29.9212524, altitudeFeet: 5000)
        XCTAssertEqual(station, 24.896, accuracy: 0.01)
    }

    func testStationPressureScalesWithTheSeaLevelReading() {
        let high = Atmosphere.stationPressureInHg(seaLevelInHg: 30.40, altitudeFeet: 5000)
        let low = Atmosphere.stationPressureInHg(seaLevelInHg: 29.40, altitudeFeet: 5000)
        XCTAssertGreaterThan(high, low)
        XCTAssertEqual(high / low, 30.40 / 29.40, accuracy: 0.0001)
    }

    func testAppleWeatherValuesMapToSolverInputs() {
        let conditions = WeatherKitProvider.conditions(
            temperatureF: 68,
            seaLevelPressureInHg: 29.9212524,
            humidityFraction: 0.42,
            windSpeedMph: 9,
            windFromDegrees: 270,
            altitudeFeet: 5000
        )
        XCTAssertEqual(conditions.temperatureF, 68)
        XCTAssertEqual(conditions.stationPressureInHg, 24.896, accuracy: 0.01)
        XCTAssertEqual(conditions.humidityPercent, 42, accuracy: 0.0001)
        XCTAssertEqual(conditions.windSpeedMph, 9)
        XCTAssertEqual(conditions.windFromDegrees, 270)
    }

    func testWindDirectionWrapsIntoACompassCircle() {
        let wrapped = WeatherKitProvider.conditions(
            temperatureF: 59, seaLevelPressureInHg: 29.92, humidityFraction: 0.5,
            windSpeedMph: 5, windFromDegrees: 360, altitudeFeet: 0
        )
        XCTAssertEqual(wrapped.windFromDegrees, 0, accuracy: 0.0001)
        let negative = WeatherKitProvider.conditions(
            temperatureF: 59, seaLevelPressureInHg: 29.92, humidityFraction: 0.5,
            windSpeedMph: 5, windFromDegrees: -90, altitudeFeet: 0
        )
        XCTAssertEqual(negative.windFromDegrees, 270, accuracy: 0.0001)
    }
}
