import Foundation

struct TrajectoryRow: Equatable, Identifiable {
    var rangeYards: Double
    /// Perpendicular miss relative to the line of sight. Positive is above the line of sight.
    var pathInches: Double
    /// Positive is a dial-up correction.
    var comeUpMOA: Double
    var comeUpMIL: Double
    /// Positive is to the shooter's right.
    var windageInches: Double
    /// Positive is a dial-right correction.
    var windageMOA: Double
    var windageMIL: Double
    var velocityFps: Double
    var energyFootPounds: Double
    var timeSeconds: Double
    var elevationClicks: Double
    var windageClicks: Double

    var id: Double { rangeYards }
}

struct FiringSolution: Equatable {
    var rows: [TrajectoryRow]
    var target: TrajectoryRow
    /// Bore angle above the line of sight for a flat, no-wind zero in the current air.
    var zeroAngleMOA: Double
    var densityRatio: Double
    var densityAltitudeFeet: Double
    var speedOfSoundFps: Double
    /// Positive is right, for a right-hand twist.
    var spinDriftInches: Double
    /// Horizontal Coriolis, positive right.
    var coriolisHorizontalInches: Double
    /// Vertical Coriolis, positive raises the impact.
    var coriolisVerticalInches: Double
    /// Wind drift before spin drift and Coriolis. Positive is right.
    var aerodynamicWindageInches: Double
}

struct ShotRequest: Equatable {
    var load: BallisticLoad
    var atmosphere: Atmosphere
    var wind: Wind
    var context: ShotContext
}
