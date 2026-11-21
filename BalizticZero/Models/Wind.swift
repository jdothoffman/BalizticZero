import Foundation

/// Wind the air is coming from, in degrees clockwise from north. 0 is a north wind.
struct Wind: Equatable {
    var speedMph: Double
    var fromDegrees: Double

    /// Air velocity in the shot frame. Positive downrange is a tailwind. Positive right blows toward the shooter's right.
    /// A headwind (coming from the target) has a negative downrange component.
    static func airVelocityFPS(speedMph: Double, fromDegrees: Double, azimuthDegrees: Double) -> (downrange: Double, right: Double) {
        let relative = (fromDegrees - azimuthDegrees) * .pi / 180
        let fps = speedMph * 22 / 15
        return (-fps * cos(relative), -fps * sin(relative))
    }

    /// 0° is a headwind (12 o'clock). 90° is from the shooter's right (3 o'clock).
    static func relativeDegrees(fromDegrees: Double, azimuthDegrees: Double) -> Double {
        var relative = (fromDegrees - azimuthDegrees).truncatingRemainder(dividingBy: 360)
        if relative < 0 { relative += 360 }
        return relative
    }

    static func clockLabel(fromDegrees: Double, azimuthDegrees: Double) -> String {
        let relative = relativeDegrees(fromDegrees: fromDegrees, azimuthDegrees: azimuthDegrees)
        let hour = relative / 30
        if hour < 0.05 || hour >= 11.95 {
            return "12 o'clock"
        }
        return String(format: "%.1f o'clock", hour)
    }

    static func directionWords(fromDegrees: Double, azimuthDegrees: Double) -> String {
        let relative = relativeDegrees(fromDegrees: fromDegrees, azimuthDegrees: azimuthDegrees)
        switch relative {
        case 0..<22.5, 337.5...360:
            return "headwind"
        case 157.5..<202.5:
            return "tailwind"
        case 22.5..<157.5:
            return "from the right"
        default:
            return "from the left"
        }
    }
}
