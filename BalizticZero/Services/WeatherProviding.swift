import Foundation

struct WeatherConditions: Equatable {
    var temperatureF: Double
    var stationPressureInHg: Double
    var humidityPercent: Double
    var windSpeedMph: Double
    var windFromDegrees: Double
}

/// What a weather source requires the app to show next to its data.
struct WeatherSourceAttribution: Equatable {
    var serviceName: String
    /// Logo for a dark background.
    var markURL: URL
    var legalURL: URL
}

enum WeatherProviderError: LocalizedError {
    case notConfigured
    case noLocation
    case notAuthorized
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Weather lookup is not configured."
        case .noLocation:
            "Set latitude and longitude first, or use the iPhone sensors."
        case .notAuthorized:
            "Apple Weather refused the request. WeatherKit must be enabled for this app ID in the developer portal."
        case .unavailable:
            "Apple Weather is unavailable right now. Enter the conditions by hand."
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
    /// Altitude is the rifle's, so a source that reports sea-level pressure can return station pressure.
    func fetchConditions(latitude: Double, longitude: Double, altitudeFeet: Double) async throws -> WeatherConditions
    func attribution() async -> WeatherSourceAttribution?
}

extension WeatherProviding {
    func attribution() async -> WeatherSourceAttribution? { nil }
}

struct UnconfiguredWeatherProvider: WeatherProviding {
    let isConfigured = false
    let sourceNote = "Weather lookup is not connected. Enter temperature, pressure, humidity, and wind by hand."

    func fetchConditions(latitude: Double, longitude: Double, altitudeFeet: Double) async throws -> WeatherConditions {
        throw WeatherProviderError.notConfigured
    }
}
