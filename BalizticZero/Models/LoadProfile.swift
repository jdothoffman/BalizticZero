import Foundation
import SwiftData

enum DragModel: String, Codable, CaseIterable, Identifiable {
    case g1
    case g7

    var id: String { rawValue }

    var title: String {
        switch self {
        case .g1: "G1"
        case .g7: "G7"
        }
    }
}

enum ClickUnit: String, Codable, CaseIterable, Identifiable {
    case moa
    case mil

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moa: "MOA"
        case .mil: "MRAD"
        }
    }

    /// Click size most turrets in this unit use, in this unit.
    var standardClickValue: Double {
        switch self {
        case .moa: 0.25
        case .mil: 0.1
        }
    }

    /// Travel in one turret revolution most scopes in this unit use, in this unit.
    var standardTravelPerTurn: Double {
        switch self {
        case .moa: 25
        case .mil: 10
        }
    }

    /// Spacing between the finest reticle hashes most reticles in this unit use, in this unit.
    var standardHashSpacing: Double {
        switch self {
        case .moa: 1
        case .mil: 0.2
        }
    }
}

/// Value snapshot the solver reads. Kept separate from the SwiftData record so a shot can be computed without a store.
struct BallisticLoad: Equatable {
    var muzzleVelocityFps: Double
    var bulletWeightGrains: Double
    var diameterInches: Double
    var lengthInches: Double
    var ballisticCoefficient: Double
    var dragModel: DragModel
    var sightHeightInches: Double
    var zeroRangeYards: Double
    var twistInches: Double
    var clickUnit: ClickUnit
    var clickValue: Double
    var travelPerTurnMOA: Double = 25
    var elevationTravelMOA: Double = 100
    var windageTravelMOA: Double = 80
    var railCantMOA: Double = 0
    var reticleUnit: ClickUnit = .moa
    var focalPlane: FocalPlane = .ffp
    var reticleTrueMagnification: Double = 25
    var hashSpacingMIL: Double = AngularScale.oneMOAInMil
}

@Model
final class LoadProfile {
    var id: UUID
    var name: String
    var muzzleVelocityFps: Double
    var bulletWeightGrains: Double
    var diameterInches: Double
    var lengthInches: Double
    var ballisticCoefficient: Double
    var dragModelRaw: String
    var sightHeightInches: Double
    var zeroRangeYards: Double
    var twistInches: Double
    var clickUnitRaw: String
    var clickValue: Double
    var travelPerTurnMOA: Double = 25
    var elevationTravelMOA: Double = 100
    var windageTravelMOA: Double = 80
    var railCantMOA: Double = 0
    var reticleUnitRaw: String = ClickUnit.moa.rawValue
    var focalPlaneRaw: String = FocalPlane.ffp.rawValue
    var reticleTrueMagnification: Double = 25
    var hashSpacingMIL: Double = AngularScale.oneMOAInMil
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        muzzleVelocityFps: Double,
        bulletWeightGrains: Double,
        diameterInches: Double,
        lengthInches: Double,
        ballisticCoefficient: Double,
        dragModel: DragModel,
        sightHeightInches: Double,
        zeroRangeYards: Double,
        twistInches: Double,
        clickUnit: ClickUnit,
        clickValue: Double,
        travelPerTurnMOA: Double = 25,
        elevationTravelMOA: Double = 100,
        windageTravelMOA: Double = 80,
        railCantMOA: Double = 0,
        reticleUnit: ClickUnit = .moa,
        focalPlane: FocalPlane = .ffp,
        reticleTrueMagnification: Double = 25,
        hashSpacingMIL: Double = AngularScale.oneMOAInMil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.muzzleVelocityFps = muzzleVelocityFps
        self.bulletWeightGrains = bulletWeightGrains
        self.diameterInches = diameterInches
        self.lengthInches = lengthInches
        self.ballisticCoefficient = ballisticCoefficient
        self.dragModelRaw = dragModel.rawValue
        self.sightHeightInches = sightHeightInches
        self.zeroRangeYards = zeroRangeYards
        self.twistInches = twistInches
        self.clickUnitRaw = clickUnit.rawValue
        self.clickValue = clickValue
        self.travelPerTurnMOA = travelPerTurnMOA
        self.elevationTravelMOA = elevationTravelMOA
        self.windageTravelMOA = windageTravelMOA
        self.railCantMOA = railCantMOA
        self.reticleUnitRaw = reticleUnit.rawValue
        self.focalPlaneRaw = focalPlane.rawValue
        self.reticleTrueMagnification = reticleTrueMagnification
        self.hashSpacingMIL = hashSpacingMIL
        self.createdAt = createdAt
    }

    var dragModel: DragModel {
        get { DragModel(rawValue: dragModelRaw) ?? .g7 }
        set { dragModelRaw = newValue.rawValue }
    }

    var clickUnit: ClickUnit {
        get { ClickUnit(rawValue: clickUnitRaw) ?? .moa }
        set { clickUnitRaw = newValue.rawValue }
    }

    var reticleUnit: ClickUnit {
        get { ClickUnit(rawValue: reticleUnitRaw) ?? .moa }
        set { reticleUnitRaw = newValue.rawValue }
    }

    var focalPlane: FocalPlane {
        get { FocalPlane(rawValue: focalPlaneRaw) ?? .ffp }
        set { focalPlaneRaw = newValue.rawValue }
    }

    var ballisticLoad: BallisticLoad {
        BallisticLoad(
            muzzleVelocityFps: muzzleVelocityFps,
            bulletWeightGrains: bulletWeightGrains,
            diameterInches: diameterInches,
            lengthInches: lengthInches,
            ballisticCoefficient: ballisticCoefficient,
            dragModel: dragModel,
            sightHeightInches: sightHeightInches,
            zeroRangeYards: zeroRangeYards,
            twistInches: twistInches,
            clickUnit: clickUnit,
            clickValue: clickValue,
            travelPerTurnMOA: travelPerTurnMOA,
            elevationTravelMOA: elevationTravelMOA,
            windageTravelMOA: windageTravelMOA,
            railCantMOA: railCantMOA,
            reticleUnit: reticleUnit,
            focalPlane: focalPlane,
            reticleTrueMagnification: reticleTrueMagnification,
            hashSpacingMIL: hashSpacingMIL
        )
    }

    static func standard308() -> LoadProfile {
        LoadProfile(
            name: ".308 175 gr",
            muzzleVelocityFps: 2600,
            bulletWeightGrains: 175,
            diameterInches: 0.308,
            lengthInches: 1.24,
            ballisticCoefficient: 0.243,
            dragModel: .g7,
            sightHeightInches: 1.5,
            zeroRangeYards: 100,
            twistInches: 11.25,
            clickUnit: .moa,
            clickValue: 0.25
        )
    }
}
