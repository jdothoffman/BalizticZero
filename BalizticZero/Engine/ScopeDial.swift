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

    /// Linear size of an angle at the target. One true MOA is 1.0472 inches at 100 yards.
    static func inches(fromMOA moa: Double, atYards yards: Double) -> Double {
        moa * (.pi / 10_800) * yards * 36
    }
}

struct DialInstruction: Equatable {
    var wholeTurns: Int
    var remainderClicks: Double
    /// Number to set on the turret's markings after the whole turns, in the turret unit.
    var turretReading: Double
    var summary: String
}

struct TurretSettings: Equatable {
    var clickValue: Double
    var travelPerTurnMOA: Double
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
        var turns = 0
        var remainder = roundedClicks
        if perTurn > 0.5 {
            turns = Int((roundedClicks / perTurn).rounded(.down))
            remainder = roundedClicks - Double(turns) * perTurn
            if remainder >= perTurn - 0.05 {
                turns += 1
                remainder = 0
            }
        }

        // The turret can only stop on a click, so the reading is the nearest click's marking.
        let reading = remainder.rounded() * clickValue
        let setting = "\(readingText(reading, unit: clickUnit, clickValue: clickValue)) (\(clickText(remainder)))"
        let summary: String
        if turns == 0 {
            summary = setting
        } else {
            let turnText = "\(turns) \(turns == 1 ? "turn" : "turns")"
            summary = remainder < 0.05 ? turnText : "\(turnText) + \(setting)"
        }
        return DialInstruction(wholeTurns: turns, remainderClicks: remainder, turretReading: reading, summary: summary)
    }

    /// Turret settings after the shooter changes the turret unit. A click value only means something in its own unit, so it moves to the new unit's standard. Travel per turn moves too when it was still the old unit's standard; a value typed for a specific scope keeps its angle.
    static func turretSettings(
        changingFrom old: ClickUnit,
        to new: ClickUnit,
        clickValue: Double,
        travelPerTurnMOA: Double
    ) -> TurretSettings {
        guard old != new else { return TurretSettings(clickValue: clickValue, travelPerTurnMOA: travelPerTurnMOA) }
        let oldTurn = AngularScale.display(travelPerTurnMOA, unit: old)
        let travel = abs(oldTurn - old.standardTravelPerTurn) < 0.01
            ? AngularScale.moa(fromDisplay: new.standardTravelPerTurn, unit: new)
            : travelPerTurnMOA
        return TurretSettings(clickValue: new.standardClickValue, travelPerTurnMOA: travel)
    }

    /// Hash spacing after the shooter changes the reticle unit. The old unit's standard moves to the new unit's standard; a value typed for a specific reticle keeps its angle.
    static func hashSpacingMIL(changingFrom old: ClickUnit, to new: ClickUnit, storedMIL: Double) -> Double {
        guard old != new, abs(hashSpacing(storedMIL: storedMIL, unit: old) - old.standardHashSpacing) < 0.001 else {
            return storedMIL
        }
        return storedHashSpacingMIL(display: new.standardHashSpacing, unit: new)
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

    /// Shows the reading with as many decimals as the click value, so 0.1 MRAD clicks read 4.6 and 0.25 MOA clicks read 3.25.
    private static func readingText(_ reading: Double, unit: ClickUnit, clickValue: Double) -> String {
        let decimals = (0...3).first { places in
            let scaled = clickValue * pow(10, Double(places))
            return abs(scaled - scaled.rounded()) < 1e-6
        } ?? 3
        return String(format: "%.\(decimals)f %@", reading, unit.title)
    }
}
