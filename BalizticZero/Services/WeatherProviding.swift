import Foundation

struct WeatherConditions: Equatable {
    var temperatureF: Double
    var stationPressureInHg: Double
    var humidityPercent: Double
    var windSpeedMph: Double
    var windFromDegrees: Double
}

enum WeatherProviderError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Weather lookup is not configured."
        }
    }
}

/// Free sources left unwired on purpose:
/// Open-Meteo needs no key:
/// `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,relative_humidity_2m,surface_pressure,wind_speed_10m,wind_direction_10m`
/// NOAA, US locations, no key: `https://api.weather.gov/points/{lat},{lon}` and then the hourly forecast URL it returns.
protocol WeatherProviding: Sendable {
    var isConfigured: Bool { get }
    var sourceNote: String { get }
    func fetchConditions(latitude: Double, longitude: Double) async throws -> WeatherConditions
}

struct UnconfiguredWeatherProvider: WeatherProviding {
    let isConfigured = false
    let sourceNote = "Open-Meteo and NOAA weather are not connected. Enter temperature, pressure, humidity, and wind by hand."

    func fetchConditions(latitude: Double, longitude: Double) async throws -> WeatherConditions {
        throw WeatherProviderError.notConfigured
    }
}
