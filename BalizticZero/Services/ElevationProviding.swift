import Foundation

enum ElevationProviderError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Elevation lookup is not configured."
        }
    }
}

/// Free source left unwired on purpose. Open-Meteo elevation needs no key:
/// `https://api.open-meteo.com/v1/elevation?latitude={lat}&longitude={lon}`
/// GPS altitude and the barometer remain the live sources.
protocol ElevationProviding: Sendable {
    var isConfigured: Bool { get }
    var sourceNote: String { get }
    func elevationFeet(latitude: Double, longitude: Double) async throws -> Double
}

struct UnconfiguredElevationProvider: ElevationProviding {
    let isConfigured = false
    let sourceNote = "A free elevation lookup is not connected. Use GPS altitude or type it in."

    func elevationFeet(latitude: Double, longitude: Double) async throws -> Double {
        throw ElevationProviderError.notConfigured
    }
}
