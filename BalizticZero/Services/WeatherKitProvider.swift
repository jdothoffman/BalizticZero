import CoreLocation
import Foundation
import WeatherKit

/// Current conditions from Apple Weather. Needs the WeatherKit entitlement and WeatherKit enabled for the app ID.
struct WeatherKitProvider: WeatherProviding {
    let isConfigured = true
    let sourceNote = "Apple Weather gives conditions for the area, not your exact spot. Its wind is not what is blowing on your line, so treat it as a starting point."

    func fetchConditions(latitude: Double, longitude: Double, altitudeFeet: Double) async throws -> WeatherConditions {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let current: CurrentWeather
        do {
            current = try await WeatherService.shared.weather(for: location, including: .current)
        } catch WeatherError.permissionDenied {
            throw WeatherProviderError.notAuthorized
        } catch {
            throw WeatherProviderError.unavailable
        }
        return Self.conditions(
            temperatureF: current.temperature.converted(to: .fahrenheit).value,
            seaLevelPressureInHg: current.pressure.converted(to: .inchesOfMercury).value,
            humidityFraction: current.humidity,
            windSpeedMph: current.wind.speed.converted(to: .milesPerHour).value,
            windFromDegrees: current.wind.direction.converted(to: .degrees).value,
            altitudeFeet: altitudeFeet
        )
    }

    func attribution() async -> WeatherSourceAttribution? {
        guard let attribution = try? await WeatherService.shared.attribution else { return nil }
        return WeatherSourceAttribution(
            serviceName: attribution.serviceName,
            markURL: attribution.combinedMarkDarkURL,
            legalURL: attribution.legalPageURL
        )
    }

    /// Maps Apple Weather's values to the solver's inputs. Apple reports sea-level pressure and humidity as a fraction,
    /// and wind direction as where the wind comes from, clockwise from true north.
    static func conditions(
        temperatureF: Double,
        seaLevelPressureInHg: Double,
        humidityFraction: Double,
        windSpeedMph: Double,
        windFromDegrees: Double,
        altitudeFeet: Double
    ) -> WeatherConditions {
        var direction = windFromDegrees.truncatingRemainder(dividingBy: 360)
        if direction < 0 { direction += 360 }
        return WeatherConditions(
            temperatureF: temperatureF,
            stationPressureInHg: Atmosphere.stationPressureInHg(seaLevelInHg: seaLevelPressureInHg, altitudeFeet: altitudeFeet),
            humidityPercent: min(100, max(0, humidityFraction * 100)),
            windSpeedMph: max(0, windSpeedMph),
            windFromDegrees: direction
        )
    }
}
