import Foundation

/// Station conditions. Density uses temperature, pressure, and humidity. Altitude is the reference height for the short lapse during flight.
struct Atmosphere: Equatable {
    var temperatureF: Double
    var stationPressureInHg: Double
    var humidityPercent: Double
    var altitudeFeet: Double

    static let icaoSeaLevel = Atmosphere(
        temperatureF: 59,
        stationPressureInHg: 29.9212524,
        humidityPercent: 0,
        altitudeFeet: 0
    )

    static func standardPressureInHg(altitudeFeet: Double) -> Double {
        let meters = altitudeFeet * 0.3048
        let hPa = 1013.25 * pow(1 + (-0.0065) * meters / (15 + 273.15), 5.255876)
        return hPa / AtmosphereModel.hPaPerInHg
    }

    static func standardTemperatureF(altitudeFeet: Double) -> Double {
        59 + altitudeFeet * (-3.56616e-3)
    }
}

enum PressureSource: Equatable {
    /// Station pressure follows the standard atmosphere at the entered altitude.
    case standardForAltitude
    case manual
    case barometer
}
