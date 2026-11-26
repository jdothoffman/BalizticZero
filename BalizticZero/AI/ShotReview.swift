import Foundation

/// The advisor's structured answer about one recorded impact. It holds words only;
/// every number on the review card comes from the on-device solver.
struct ShotReview: Decodable, Equatable {
    enum Verdict: String, Decodable {
        case onCall = "on_call"
        case withinCall = "within_call"
        case checkWind = "check_wind"
        case checkZero = "check_zero"
        case checkVelocity = "check_velocity"
        /// A verdict this build does not know yet. The card still renders.
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Verdict(rawValue: raw) ?? .unknown
        }

        var title: String {
            switch self {
            case .onCall: "On call"
            case .withinCall: "Within call"
            case .checkWind: "Check wind"
            case .checkZero: "Check zero"
            case .checkVelocity: "Check velocity"
            case .unknown: "Review"
            }
        }

        /// True when the advisor wants an input confirmed before the next shot.
        var needsAttention: Bool {
            switch self {
            case .checkWind, .checkZero, .checkVelocity: true
            case .onCall, .withinCall, .unknown: false
            }
        }

        var symbol: String {
            switch self {
            case .onCall: "scope"
            case .withinCall: "checkmark.circle"
            case .checkWind: "wind"
            case .checkZero: "dot.scope"
            case .checkVelocity: "speedometer"
            case .unknown: "questionmark.circle"
            }
        }
    }

    enum Likelihood: String, Decodable {
        case likely, possible, unlikely, unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Likelihood(rawValue: raw) ?? .unknown
        }

        /// Bar fill. A word, never a percentage, because one shot cannot support one.
        var fill: Double {
            switch self {
            case .likely: 0.85
            case .possible: 0.5
            case .unlikely: 0.18
            case .unknown: 0.3
            }
        }

        var title: String {
            self == .unknown ? "unclear" : rawValue
        }
    }

    struct Cause: Decodable, Equatable, Identifiable {
        var factor: String
        var likelihood: Likelihood
        var note: String

        var id: String { factor + note }

        var title: String {
            switch factor {
            case "wind": "Wind"
            case "spin_drift": "Spin drift"
            case "coriolis": "Coriolis"
            case "zero": "Zero"
            case "muzzle_velocity": "Muzzle velocity"
            case "atmosphere": "Atmosphere"
            case "shooter": "Shooter"
            default: factor.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }
    }

    var verdict: Verdict
    var headline: String
    var causes: [Cause]
    var nextStep: String
    var caution: String
}

/// A review together with the solver's numbers at the moment it was asked for,
/// so the card keeps matching the shot even after the inputs change.
struct ShotReviewResult: Equatable {
    var review: ShotReview
    var reviewedAt: Date
    var rangeYards: Double
    /// Positive is high.
    var impactHighMOA: Double
    /// Positive is right.
    var impactRightMOA: Double
    /// Positive is right.
    var windDriftInches: Double
    /// Positive is right.
    var spinDriftInches: Double

    var missHighInches: Double {
        AngularScale.inches(fromMOA: impactHighMOA, atYards: rangeYards)
    }

    var missRightInches: Double {
        AngularScale.inches(fromMOA: impactRightMOA, atYards: rangeYards)
    }

    /// Horizontal miss as a share of the wind drift the solver corrected for.
    /// Nil when there was almost no wind to compare against.
    var windShare: Double? {
        guard abs(windDriftInches) >= 0.5 else { return nil }
        return abs(missRightInches) / abs(windDriftInches)
    }
}
