import Foundation

/// Miller stability and the Litz time-of-flight spin-drift approximation.
/// Twist is inches per turn. Positive twist is right-hand and drifts to the right.
enum SpinDrift {
    static func inches(
        timeSeconds: Double,
        muzzleVelocityFps: Double,
        weightGrains: Double,
        diameterInches: Double,
        lengthInches: Double,
        twistInches: Double,
        temperatureF: Double,
        pressureInHg: Double
    ) -> Double {
        guard timeSeconds > 0,
              twistInches != 0,
              lengthInches > 0,
              diameterInches > 0,
              weightGrains > 0,
              pressureInHg > 0,
              muzzleVelocityFps > 0
        else { return 0 }

        let twistCalibers = abs(twistInches) / diameterInches
        let lengthCalibers = lengthInches / diameterInches
        let denominator = twistCalibers * twistCalibers
            * diameterInches * diameterInches * diameterInches
            * lengthCalibers
            * (1 + lengthCalibers * lengthCalibers)
        guard denominator > 0 else { return 0 }

        let miller = 30 * weightGrains / denominator
        let velocityFactor = pow(muzzleVelocityFps / 2800, 1.0 / 3.0)
        let atmosphereFactor = ((temperatureF + 460) / (59 + 460)) * (29.92 / pressureInHg)
        let stability = miller * velocityFactor * atmosphereFactor
        let sign: Double = twistInches > 0 ? 1 : -1
        return sign * 1.25 * (stability + 1.2) * pow(timeSeconds, 1.83)
    }
}
