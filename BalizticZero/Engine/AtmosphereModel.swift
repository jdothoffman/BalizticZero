import Foundation

enum AtmosphereModel {
    static let gravityFps2 = 32.17405
    static let dragConstant = 2.08551e-04
    static let standardDensityKgM3 = 1.2250
    static let hPaPerInHg = 33.8638866667
    static let energyDivisor = 450400.0
    static let lapseKelvinPerFoot = -0.0019812
    static let pressureExponent = 5.255876

    static func densityRatio(_ atmosphere: Atmosphere, atVerticalFeet verticalFeet: Double = 0) -> Double {
        let base = seaLevelRelativeDensity(atmosphere)
        let delta = verticalFeet
        guard abs(delta) >= 1, atmosphere.stationPressureInHg > 0 else { return base }
        let baseTempC = celsius(fromFahrenheit: atmosphere.temperatureF)
        let tC = baseTempC + delta * lapseKelvinPerFoot
        let tK = tC + 273.15
        guard tK > 1 else { return base }
        let basePressure = atmosphere.stationPressureInHg * hPaPerInHg
        let factor = 1 + lapseKelvinPerFoot * delta / (baseTempC + 273.15)
        guard factor > 0 else { return base }
        let pressure = basePressure * pow(factor, pressureExponent)
        let densityScale = ((baseTempC + 273.15) * pressure) / (basePressure * tK)
        return base * densityScale
    }

    static func speedOfSoundFps(_ atmosphere: Atmosphere, atVerticalFeet verticalFeet: Double = 0) -> Double {
        let baseTempC = celsius(fromFahrenheit: atmosphere.temperatureF)
        let tC = baseTempC + verticalFeet * lapseKelvinPerFoot
        let tF = tC * 9 / 5 + 32
        return speedOfSoundFps(temperatureF: tF)
    }

    static func speedOfSoundFps(temperatureF: Double) -> Double {
        let rankine = temperatureF + 459.67
        guard rankine > 1 else { return 1 }
        return sqrt(rankine) * 49.0223
    }

    static func densityAltitudeFeet(_ atmosphere: Atmosphere) -> Double {
        let ratio = densityRatio(atmosphere)
        guard ratio > 0 else { return 0 }
        return 145442.16 * (1 - pow(ratio, 0.234969))
    }

    static func energyFootPounds(weightGrains: Double, velocityFps: Double) -> Double {
        weightGrains * velocityFps * velocityFps / energyDivisor
    }

    private static func seaLevelRelativeDensity(_ atmosphere: Atmosphere) -> Double {
        guard atmosphere.stationPressureInHg > 0 else { return 0 }
        let tempC = celsius(fromFahrenheit: atmosphere.temperatureF)
        let pressureHpa = atmosphere.stationPressureInHg * hPaPerInHg
        let density = cipmDensityKgM3(temperatureC: tempC, pressureHpa: pressureHpa, humidityPercent: atmosphere.humidityPercent)
        return density / standardDensityKgM3
    }

    /// CIPM-2007 moist-air density. Humidity is a percent from 0 to 100.
    static func cipmDensityKgM3(temperatureC: Double, pressureHpa: Double, humidityPercent: Double) -> Double {
        guard pressureHpa > 0 else { return 0 }
        let gasConstant = 8.314472
        let molarAir = 28.96546e-3
        let molarVapor = 18.01528e-3
        var relativeHumidity = humidityPercent
        if relativeHumidity > 1 { relativeHumidity /= 100 }
        relativeHumidity = min(1, max(0, relativeHumidity))

        let kelvin = temperatureC + 273.15
        guard kelvin > 1 else { return 0 }
        let pascals = pressureHpa * 100
        let saturation = saturationVaporPressure(kelvin)
        let enhancement = 1.00062 + 3.14e-8 * pascals + 5.6e-7 * temperatureC * temperatureC
        let vaporPressure = relativeHumidity * enhancement * saturation
        let moleFraction = min(0.2, max(0, vaporPressure / pascals))
        let compressibility = compressibilityFactor(pascals: pascals, kelvin: kelvin, moleFraction: moleFraction)
        guard compressibility > 0 else { return 0 }
        return (pascals * molarAir) / (compressibility * gasConstant * kelvin) * (1 - moleFraction * (1 - molarVapor / molarAir))
    }

    private static func saturationVaporPressure(_ kelvin: Double) -> Double {
        let a = [1.2378847e-5, -1.9121316e-2, 33.93711047, -6.3431645e3]
        return exp(a[0] * kelvin * kelvin + a[1] * kelvin + a[2] + a[3] / kelvin)
    }

    private static func compressibilityFactor(pascals: Double, kelvin: Double, moleFraction: Double) -> Double {
        let a0 = 1.58123e-6
        let a1 = -2.9331e-8
        let a2 = 1.1043e-10
        let b0 = 5.707e-6
        let b1 = -2.051e-8
        let c0 = 1.9898e-4
        let c1 = -2.376e-6
        let d = 1.83e-11
        let e = -0.765e-8
        let celsius = kelvin - 273.15
        let pOverT = pascals / kelvin
        return 1
            - pOverT * (a0 + a1 * celsius + a2 * celsius * celsius + (b0 + b1 * celsius) * moleFraction + (c0 + c1 * celsius) * moleFraction * moleFraction)
            + pOverT * pOverT * (d + e * moleFraction * moleFraction)
    }

    private static func celsius(fromFahrenheit fahrenheit: Double) -> Double {
        (fahrenheit - 32) * 5 / 9
    }
}
