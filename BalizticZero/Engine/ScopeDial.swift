import Foundation

enum FocalPlane: String, Codable, CaseIterable, Identifiable {
    case ffp
    case sfp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ffp: "First"
        case .sfp: "Second"
        }
    }
}

enum AngularScale {
    /// True minutes of angle in one milliradian.
    static let moaPerMil = (180.0 / .pi) * 60.0 / 1000.0
    static let oneMOAInMil = 1 / moaPerMil

    static func moa(fromDisplay value: Double, unit: ClickUnit) -> Double {
        switch unit {
        case .moa: value
        case .mil: value * moaPerMil
        }
    }

    static func display(_ moa: Double, unit: ClickUnit) -> Double {
        switch unit {
        case .moa: moa
        case .mil: moa / moaPerMil
        }
    }
}

struct DialInstruction: Equatable {
    var wholeTurns: Int
    var remainderClicks: Double
    var summary: String
}

struct TravelLimit: Equatable {
    /// Room left in the turret, in the turret's click unit.
    var available: Double
    var required: Double
    var overBy: Double
    var isOver: Bool
}

enum ScopeDial {
    static func instruction(
        angleMOA: Double,
        clickUnit: ClickUnit,
        clickValue: Double,
        travelPerTurnMOA: Double
    ) -> DialInstruction {
        let clicks = abs(AngularScale.display(angleMOA, unit: clickUnit)) / clickValue
        let roundedClicks = (clicks * 10).rounded() / 10
        let perTurn = AngularScale.display(travelPerTurnMOA, unit: clickUnit) / clickValue
        guard perTurn > 0.5 else {
            return DialInstruction(wholeTurns: 0, remainderClicks: roundedClicks, summary: clickText(roundedClicks))
        }

        var turns = Int((roundedClicks / perTurn).rounded(.down))
        var remainder = roundedClicks - Double(turns) * perTurn
        if remainder >= perTurn - 0.05 {
            turns += 1
            remainder = 0
        }
        let summary: String
        if turns == 0 {
            summary = clickText(remainder)
        } else {
            let turnWord = turns == 1 ? "turn" : "turns"
            summary = "\(turns) \(turnWord) + \(clickText(remainder))"
        }
        return DialInstruction(wholeTurns: turns, remainderClicks: remainder, summary: summary)
    }

    /// Elevation still available from the current zero. A positive rail cant points the scope down and frees more up-travel.
    static func elevationLimit(
        comeUpMOA: Double,
        zeroAngleMOA: Double,
        elevationTravelMOA: Double,
        railCantMOA: Double,
        clickUnit: ClickUnit
    ) -> TravelLimit? {
        guard elevationTravelMOA > 0 else { return nil }
        let availableMOA = comeUpMOA >= 0
            ? elevationTravelMOA / 2 - zeroAngleMOA + railCantMOA
            : elevationTravelMOA / 2 + zeroAngleMOA - railCantMOA
        return limit(requiredMOA: abs(comeUpMOA), availableMOA: availableMOA, clickUnit: clickUnit)
    }

    /// Windage available to either side of a centered zero.
    static func windageLimit(
        windageMOA: Double,
        windageTravelMOA: Double,
        clickUnit: ClickUnit
    ) -> TravelLimit? {
        guard windageTravelMOA > 0 else { return nil }
        return limit(requiredMOA: abs(windageMOA), availableMOA: windageTravelMOA / 2, clickUnit: clickUnit)
    }

    /// Angle to hold as the reticle reads it. Second focal plane marks grow as magnification drops below the power where they are true.
    static func indicatedHold(
        angleMOA: Double,
        reticleUnit: ClickUnit,
        focalPlane: FocalPlane,
        trueMagnification: Double,
        currentMagnification: Double
    ) -> Double {
        let trueAngle = abs(AngularScale.display(angleMOA, unit: reticleUnit))
        guard focalPlane == .sfp, trueMagnification > 0, currentMagnification > 0 else { return trueAngle }
        return trueAngle * (currentMagnification / trueMagnification)
    }

    static func hashCount(indicated: Double, hashSpacing: Double) -> Double? {
        guard hashSpacing > 0 else { return nil }
        return abs(indicated) / hashSpacing
    }

    static func hashSpacing(storedMIL: Double, unit: ClickUnit) -> Double {
        switch unit {
        case .mil: storedMIL
        case .moa: storedMIL * AngularScale.moaPerMil
        }
    }

    static func storedHashSpacingMIL(display: Double, unit: ClickUnit) -> Double {
        switch unit {
        case .mil: display
        case .moa: display * AngularScale.oneMOAInMil
        }
    }

    private static func limit(requiredMOA: Double, availableMOA: Double, clickUnit: ClickUnit) -> TravelLimit {
        let available = AngularScale.display(max(availableMOA, 0), unit: clickUnit)
        let required = AngularScale.display(requiredMOA, unit: clickUnit)
        let overBy = required - available
        return TravelLimit(available: available, required: required, overBy: overBy, isOver: overBy > 0.05)
    }

    private static func clickText(_ clicks: Double) -> String {
        String(format: "%.1f clicks", clicks)
    }
}
