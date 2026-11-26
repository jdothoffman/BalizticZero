import Foundation

/// Facts for one after-shot review. Field names match the server. The phone does not send a prompt.
struct AdvisorShot: Encodable, Equatable {
    var rangeYards: Double
    var azimuthDegrees: Double
    var inclineDegrees: Double
    var latitudeDegrees: Double
    var longitudeDegrees: Double
    var temperatureF: Double
    var stationPressureInHg: Double
    var humidityPercent: Double
    var altitudeFeet: Double
    var windSpeedMph: Double
    var windFromDegrees: Double
    var comeUpMOA: Double
    var windageMOA: Double
    var spinDriftInches: Double
    var coriolisHorizontalInches: Double
    var coriolisVerticalInches: Double
    var aerodynamicWindageInches: Double
    /// Positive is high of the point of aim.
    var impactHighMOA: Double
    /// Positive is right of the point of aim.
    var impactRightMOA: Double
}

protocol BallisticAdvising: Sendable {
    func review(_ shot: AdvisorShot, baseURL: URL, token: String) async throws -> ShotReview
}

enum AdvisorError: LocalizedError, Equatable {
    case notConfigured
    case insecureAddress
    case badResponse
    case rateLimited(retryAfterSeconds: Int?)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Set the advisor server address and the development token. The Anthropic key stays on the server."
        case .insecureAddress:
            "The advisor address must start with https:// so the token is not sent in the clear."
        case .badResponse:
            "The advisor did not answer."
        case .rateLimited(let seconds?):
            "Too many reviews in a row. Try again in \(seconds) s."
        case .rateLimited(nil):
            "Too many reviews in a row. Try again shortly."
        case .server(let message):
            message
        }
    }

    /// The server's https origin from the setting, or why it cannot be used.
    static func validatedBaseURL(_ address: String) throws -> URL {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AdvisorError.notConfigured }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              let host = url.host(), !host.isEmpty else {
            throw AdvisorError.notConfigured
        }
        guard scheme == "https" else { throw AdvisorError.insecureAddress }
        return url
    }
}

struct RemoteBallisticAdvisor: BallisticAdvising {
    var session: URLSession = .shared

    func review(_ shot: AdvisorShot, baseURL: URL, token: String) async throws -> ShotReview {
        var request = URLRequest(url: Self.adviseURL(from: baseURL))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(shot)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AdvisorError.badResponse
        }
        if http.statusCode == 200 {
            guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
                throw AdvisorError.badResponse
            }
            return reply.review
        }
        if http.statusCode == 429 {
            let seconds = http.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw AdvisorError.rateLimited(retryAfterSeconds: seconds)
        }
        if let failure = try? JSONDecoder().decode(Failure.self, from: data), !failure.error.isEmpty {
            throw AdvisorError.server(failure.error)
        }
        throw AdvisorError.server("The advisor returned \(http.statusCode).")
    }

    /// The setting is the server origin. A full /v1/advise URL is used as given.
    static func adviseURL(from base: URL) -> URL {
        if base.path.hasSuffix("/v1/advise") {
            return base
        }
        return base.appending(path: "v1/advise")
    }

    private struct Reply: Decodable {
        var review: ShotReview
    }

    private struct Failure: Decodable {
        var error: String
    }
}
