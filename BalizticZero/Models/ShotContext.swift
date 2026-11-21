import Foundation

/// Where the rifle is pointed. Azimuth is magnetic until a declination model is added.
struct ShotContext: Equatable {
    var rangeYards: Double
    var azimuthDegrees: Double
    var inclineDegrees: Double
    var latitudeDegrees: Double
    var longitudeDegrees: Double
}
