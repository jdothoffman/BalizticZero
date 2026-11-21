import Foundation

/// Coriolis acceleration in the local shot frame: x downrange and horizontal, y up, z to the shooter's right.
/// Azimuth is degrees clockwise from north. Latitude is degrees, north positive.
enum Coriolis {
    static let earthRotationRadPerSecond = 7.2921159e-5

    static func acceleration(
        velocityX: Double,
        velocityY: Double,
        velocityZ: Double,
        latitudeDegrees: Double,
        azimuthDegrees: Double
    ) -> (x: Double, y: Double, z: Double) {
        let latitude = latitudeDegrees * .pi / 180
        let azimuth = azimuthDegrees * .pi / 180
        let sinLat = sin(latitude)
        let cosLat = cos(latitude)
        let sinAz = sin(azimuth)
        let cosAz = cos(azimuth)

        let rangeEast = sinAz
        let rangeNorth = cosAz
        let crossEast = cosAz
        let crossNorth = -sinAz

        let velEast = velocityX * rangeEast + velocityZ * crossEast
        let velNorth = velocityX * rangeNorth + velocityZ * crossNorth
        let velUp = velocityY

        let factor = -2 * earthRotationRadPerSecond
        let accelEast = factor * (cosLat * velUp - sinLat * velNorth)
        let accelNorth = factor * (sinLat * velEast)
        let accelUp = factor * (-cosLat * velEast)

        let accelRange = accelEast * rangeEast + accelNorth * rangeNorth
        let accelCross = accelEast * crossEast + accelNorth * crossNorth
        return (accelRange, accelUp, accelCross)
    }
}
