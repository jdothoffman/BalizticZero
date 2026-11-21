import Foundation

enum UnitConverter {
    static func meters(fromYards yards: Double) -> Double { yards * 0.9144 }
    static func yards(fromMeters meters: Double) -> Double { meters / 0.9144 }
    static func meters(fromFeet feet: Double) -> Double { feet * 0.3048 }
    static func feet(fromMeters meters: Double) -> Double { meters / 0.3048 }
    static func celsius(fromFahrenheit fahrenheit: Double) -> Double { (fahrenheit - 32) * 5 / 9 }
    static func fahrenheit(fromCelsius celsius: Double) -> Double { celsius * 9 / 5 + 32 }
    static func hPa(fromInHg inHg: Double) -> Double { inHg * AtmosphereModel.hPaPerInHg }
    static func inHg(fromHPa hPa: Double) -> Double { hPa / AtmosphereModel.hPaPerInHg }
    static func metersPerSecond(fromMph mph: Double) -> Double { mph * 0.44704 }
    static func mph(fromMetersPerSecond mps: Double) -> Double { mps / 0.44704 }
    static func metersPerSecond(fromFps fps: Double) -> Double { fps * 0.3048 }
    static func fps(fromMetersPerSecond mps: Double) -> Double { mps / 0.3048 }
    static func centimeters(fromInches inches: Double) -> Double { inches * 2.54 }
    static func inches(fromCentimeters centimeters: Double) -> Double { centimeters / 2.54 }
    static func grams(fromGrains grains: Double) -> Double { grains * 0.06479891 }
    static func grains(fromGrams grams: Double) -> Double { grams / 0.06479891 }
    static func millimeters(fromInches inches: Double) -> Double { inches * 25.4 }
    static func inches(fromMillimeters millimeters: Double) -> Double { millimeters / 25.4 }
    static func joules(fromFootPounds footPounds: Double) -> Double { footPounds * 1.3558179483 }

    static func text(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

enum DisplayFormat {
    static func distance(_ yards: Double, metric: Bool) -> String {
        if metric {
            return UnitConverter.text(UnitConverter.meters(fromYards: yards), decimals: yards >= 100 ? 0 : 1) + " m"
        }
        return UnitConverter.text(yards, decimals: yards >= 100 ? 0 : 1) + " yd"
    }

    static func speed(_ fps: Double, metric: Bool) -> String {
        if metric {
            return UnitConverter.text(UnitConverter.metersPerSecond(fromFps: fps), decimals: 0) + " m/s"
        }
        return UnitConverter.text(fps, decimals: 0) + " fps"
    }

    static func drop(_ inches: Double, metric: Bool) -> String {
        if metric {
            return UnitConverter.text(UnitConverter.centimeters(fromInches: inches), decimals: 1) + " cm"
        }
        return UnitConverter.text(inches, decimals: 1) + " in"
    }

    static func energy(_ footPounds: Double, metric: Bool) -> String {
        if metric {
            return UnitConverter.text(UnitConverter.joules(fromFootPounds: footPounds), decimals: 0) + " J"
        }
        return UnitConverter.text(footPounds, decimals: 0) + " ft-lb"
    }

    static func altitude(_ feet: Double, metric: Bool) -> String {
        if metric {
            return UnitConverter.text(UnitConverter.meters(fromFeet: feet), decimals: 0) + " m"
        }
        return UnitConverter.text(feet, decimals: 0) + " ft"
    }

    static func signed(_ value: Double, decimals: Int) -> String {
        let number = UnitConverter.text(abs(value), decimals: decimals)
        if abs(value) < pow(10, Double(-decimals)) / 2 { return number }
        return value > 0 ? number : "−" + number
    }
}
