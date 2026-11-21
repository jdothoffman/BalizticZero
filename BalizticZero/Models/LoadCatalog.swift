import Foundation

struct LoadIdentity: Equatable {
    var muzzleVelocityFps: Double
    var bulletWeightGrains: Double
    var diameterInches: Double
    var lengthInches: Double
    var ballisticCoefficient: Double
    var dragModel: DragModel
    var twistInches: Double
}

struct CatalogBullet: Identifiable, Equatable {
    let id: String
    let title: String
    let weightGrains: Double
    let lengthInches: Double
    let g1: Double
    let g7: Double

    func coefficient(_ model: DragModel) -> Double {
        model == .g1 ? g1 : g7
    }
}

struct CatalogCartridge: Identifiable, Equatable {
    let id: String
    let name: String
    let diameterInches: Double
    let bullets: [CatalogBullet]
    let velocitiesFps: [Double]
    let twistsInches: [Double]
    let featuredBulletID: String
}

struct CatalogPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let cartridgeID: String
    let bulletID: String
    let muzzleVelocityFps: Double
    let twistInches: Double
    let dragModel: DragModel
    let sightHeightInches: Double
    let zeroRangeYards: Double

    var menuTitle: String {
        guard let bullet = LoadCatalog.bullet(id: bulletID) else { return name }
        return bullet.title
    }
}

enum LoadCatalog {
    static let customID = "current"

    static let sightHeightsInches = [1.5, 1.75, 2.0, 2.5]
    static let zeroRangesYards = [50.0, 100, 200, 300]

    static let cartridges: [CatalogCartridge] = [
        cartridge("223", ".223 Rem", 0.224, twentyTwo, [2600, 2700, 2750, 2800, 2900, 3000, 3100, 3200], [7, 8, 9], "223-73-eldm"),
        cartridge("224v", ".224 Valkyrie", 0.224, twentyTwo, [2600, 2670, 2750, 2800], [6.5, 7], "224-88-eldm"),
        cartridge("6arc", "6mm ARC", 0.243, sixMillimeter, [2550, 2600, 2630, 2700, 2750], [7, 7.5], "6mm-108-eldm"),
        cartridge("243", ".243 Win", 0.243, sixMillimeter, [2800, 2900, 2960, 3050], [8, 9, 10], "6mm-108-eldm"),
        cartridge("6cm", "6mm Creedmoor", 0.243, sixMillimeter, [2850, 2900, 2960, 3050, 3100], [7, 7.5, 8], "6mm-108-eldm"),
        cartridge("25cm", ".25 Creedmoor", 0.257, twentyFive, [2750, 2800, 2850, 2900], [7.5, 8], "25-134-eldm"),
        cartridge("grendel", "6.5 Grendel", 0.264, sixFive, [2460, 2500, 2580, 2650], [7.5, 8], "65-123-eldm"),
        cartridge("65cm", "6.5 Creedmoor", 0.264, sixFive, [2550, 2600, 2650, 2695, 2710, 2750, 2800], [8, 8.5], "65-140-eldm"),
        cartridge("65prc", "6.5 PRC", 0.264, sixFive, [2800, 2850, 2910, 2960], [8], "65-147-eldm"),
        cartridge("260", ".260 Rem", 0.264, sixFive, [2600, 2700, 2750, 2800], [8, 8.5], "65-140-eldm"),
        cartridge("7rm", "7mm Rem Mag", 0.284, sevenMillimeter, [2800, 2900, 2940, 3000], [9, 9.5, 10], "7mm-162-eldm"),
        cartridge("7prc", "7mm PRC", 0.284, sevenMillimeter, [2900, 2950, 2975, 3000], [8, 8.5], "7mm-180-eldm"),
        cartridge("308", ".308 Win", 0.308, thirtyCaliber, [2450, 2500, 2550, 2600, 2650, 2700, 2750, 2800], [10, 11, 11.25, 12], "308-175-smk"),
        cartridge("3006", ".30-06", 0.308, thirtyCaliber, [2600, 2700, 2750, 2800, 2900], [10, 11], "308-178-eldm"),
        cartridge("300wm", ".300 Win Mag", 0.308, thirtyCaliber, [2800, 2850, 2900, 2950, 3000], [10, 11], "308-208-eldm"),
        cartridge("300prc", ".300 PRC", 0.308, thirtyCaliber, [2750, 2810, 2860, 2900], [8.5, 9, 10], "308-225-eldm"),
        cartridge("338", ".338 Lapua", 0.338, thirtyThree, [2650, 2700, 2745, 2800], [9, 9.3, 10], "338-285-eldm"),
    ]

    static let presets: [CatalogPreset] = [
        preset("223-73", ".223 Rem 73 gr ELD-M", "223", "223-73-eldm", 2750, 8),
        preset("223-77", ".223 Rem 77 gr TMK", "223", "223-77-tmk", 2750, 8),
        preset("224-88", ".224 Valkyrie 88 gr ELD-M", "224v", "224-88-eldm", 2670, 6.5),
        preset("6arc-108", "6mm ARC 108 gr ELD-M", "6arc", "6mm-108-eldm", 2700, 7.5),
        preset("6cm-108", "6mm Creedmoor 108 gr ELD-M", "6cm", "6mm-108-eldm", 2960, 7.5),
        preset("243-108", ".243 Win 108 gr ELD-M", "243", "6mm-108-eldm", 2960, 10),
        preset("25-134", ".25 Creedmoor 134 gr ELD-M", "25cm", "25-134-eldm", 2850, 8),
        preset("grendel-123", "6.5 Grendel 123 gr ELD-M", "grendel", "65-123-eldm", 2580, 8),
        preset("65-140", "6.5 Creedmoor 140 gr ELD-M", "65cm", "65-140-eldm", 2710, 8),
        preset("65-147", "6.5 Creedmoor 147 gr ELD-M", "65cm", "65-147-eldm", 2695, 8),
        preset("65prc-147", "6.5 PRC 147 gr ELD-M", "65prc", "65-147-eldm", 2910, 8),
        preset("260-140", ".260 Rem 140 gr ELD-M", "260", "65-140-eldm", 2750, 8),
        preset("7rm-162", "7mm Rem Mag 162 gr ELD-M", "7rm", "7mm-162-eldm", 2940, 9.5),
        preset("7prc-180", "7mm PRC 180 gr ELD-M", "7prc", "7mm-180-eldm", 2975, 8),
        preset("308-168", ".308 Win 168 gr SMK", "308", "308-168-smk", 2650, 12),
        preset("308-175", ".308 Win 175 gr SMK", "308", "308-175-smk", 2600, 11.25),
        preset("308-178", ".308 Win 178 gr ELD-M", "308", "308-178-eldm", 2600, 11),
        preset("3006-178", ".30-06 178 gr ELD-M", "3006", "308-178-eldm", 2750, 10),
        preset("300wm-208", ".300 Win Mag 208 gr ELD-M", "300wm", "308-208-eldm", 2850, 10),
        preset("300prc-225", ".300 PRC 225 gr ELD-M", "300prc", "308-225-eldm", 2810, 9),
        preset("338-285", ".338 Lapua 285 gr ELD-M", "338", "338-285-eldm", 2745, 9.3),
    ]

    static func cartridge(id: String) -> CatalogCartridge? {
        cartridges.first { $0.id == id }
    }

    static func bullet(id: String) -> CatalogBullet? {
        cartridges.lazy.compactMap { $0.bullets.first { $0.id == id } }.first
    }

    static func preset(id: String) -> CatalogPreset? {
        presets.first { $0.id == id }
    }

    static func presets(for cartridgeID: String) -> [CatalogPreset] {
        presets.filter { $0.cartridgeID == cartridgeID }
    }

    static func bullet(matching identity: LoadIdentity) -> CatalogBullet? {
        cartridges.lazy.compactMap { cartridge in
            guard abs(cartridge.diameterInches - identity.diameterInches) < 0.001 else { return nil }
            return cartridge.bullets.first { bullet in
                abs(bullet.weightGrains - identity.bulletWeightGrains) < 0.2
                    && abs(bullet.coefficient(identity.dragModel) - identity.ballisticCoefficient) < 0.002
            }
        }.first
    }

    static func cartridge(for identity: LoadIdentity) -> CatalogCartridge? {
        guard let bullet = bullet(matching: identity) else { return nil }
        let candidates = cartridges.filter { cartridge in
            abs(cartridge.diameterInches - identity.diameterInches) < 0.001
                && cartridge.bullets.contains { $0.id == bullet.id }
        }
        return candidates.min { lhs, rhs in
            score(lhs, bullet: bullet, identity: identity) < score(rhs, bullet: bullet, identity: identity)
        }
    }

    static func preset(matching identity: LoadIdentity) -> CatalogPreset? {
        presets.first { preset in
            guard let cartridge = cartridge(id: preset.cartridgeID),
                  let bullet = self.bullet(id: preset.bulletID),
                  identity.dragModel == preset.dragModel else { return false }
            return abs(identity.diameterInches - cartridge.diameterInches) < 0.001
                && abs(identity.bulletWeightGrains - bullet.weightGrains) < 0.2
                && abs(identity.lengthInches - bullet.lengthInches) < 0.02
                && abs(identity.ballisticCoefficient - bullet.coefficient(identity.dragModel)) < 0.002
                && abs(identity.muzzleVelocityFps - preset.muzzleVelocityFps) < 1
                && abs(identity.twistInches - preset.twistInches) < 0.01
        }
    }

    static func choices(_ options: [Double], including current: Double, tolerance: Double) -> [Double] {
        if options.contains(where: { abs($0 - current) < tolerance }) { return options }
        return (options + [current]).sorted()
    }

    static func weight(_ grains: Double, metric: Bool) -> String {
        if metric {
            return String(format: "%.1f g", UnitConverter.grams(fromGrains: grains))
        }
        return String(format: "%.0f gr", grains)
    }

    static func velocity(_ fps: Double, metric: Bool) -> String {
        DisplayFormat.speed(fps, metric: metric)
    }

    static func length(_ inches: Double, metric: Bool) -> String {
        if metric {
            return String(format: "%.2f mm", UnitConverter.millimeters(fromInches: inches))
        }
        return String(format: "%.3f in", inches)
    }

    static func twist(_ inches: Double, metric: Bool) -> String {
        if metric {
            return "1:" + String(format: "%.0f mm", UnitConverter.millimeters(fromInches: inches))
        }
        let number = inches.rounded() == inches
            ? String(format: "%.0f", inches)
            : String(format: "%g", inches)
        return "1:" + number
    }

    static func sightHeight(_ inches: Double, metric: Bool) -> String {
        if metric {
            return String(format: "%.2f cm", UnitConverter.centimeters(fromInches: inches))
        }
        return String(format: "%.2f in", inches)
    }

    static func zero(_ yards: Double, metric: Bool) -> String {
        DisplayFormat.distance(yards, metric: metric)
    }

    private static func score(_ cartridge: CatalogCartridge, bullet: CatalogBullet, identity: LoadIdentity) -> Double {
        let velocityGap = cartridge.velocitiesFps.map { abs($0 - identity.muzzleVelocityFps) }.min() ?? 1_000
        let velocityPenalty = velocityGap < 1 ? 0 : velocityGap
        let twistGap = cartridge.twistsInches.map { abs($0 - identity.twistInches) }.min() ?? 5
        let twistPenalty = twistGap < 0.01 ? 0 : twistGap * 1_000
        let presetPenalty: Double
        if let preset = presets.first(where: { $0.cartridgeID == cartridge.id && $0.bulletID == bullet.id }) {
            presetPenalty = abs(preset.muzzleVelocityFps - identity.muzzleVelocityFps) / 10
                + abs(preset.twistInches - identity.twistInches) * 20
        } else {
            presetPenalty = 200
        }
        return velocityPenalty + twistPenalty + presetPenalty
    }

    private static func cartridge(
        _ id: String,
        _ name: String,
        _ diameter: Double,
        _ bullets: [CatalogBullet],
        _ velocities: [Double],
        _ twists: [Double],
        _ featured: String
    ) -> CatalogCartridge {
        CatalogCartridge(
            id: id,
            name: name,
            diameterInches: diameter,
            bullets: bullets,
            velocitiesFps: velocities,
            twistsInches: twists,
            featuredBulletID: featured
        )
    }

    private static func preset(
        _ id: String,
        _ name: String,
        _ cartridgeID: String,
        _ bulletID: String,
        _ velocity: Double,
        _ twist: Double
    ) -> CatalogPreset {
        CatalogPreset(
            id: id,
            name: name,
            cartridgeID: cartridgeID,
            bulletID: bulletID,
            muzzleVelocityFps: velocity,
            twistInches: twist,
            dragModel: .g7,
            sightHeightInches: 1.5,
            zeroRangeYards: 100
        )
    }

    private static func bullet(
        _ id: String,
        _ title: String,
        _ grains: Double,
        _ length: Double,
        _ g1: Double,
        _ g7: Double
    ) -> CatalogBullet {
        CatalogBullet(id: id, title: title, weightGrains: grains, lengthInches: length, g1: g1, g7: g7)
    }

    /// Hornady ELD Match coefficients are the published Mach 2.25 values. Sierra SMK and TMK coefficients are the published G1/G7 box values. Lengths are typical bullet lengths for the spin-drift estimate.
    private static let twentyTwo: [CatalogBullet] = [
        bullet("223-73-eldm", "73 gr ELD-M", 73, 1.070, 0.398, 0.200),
        bullet("223-75-eldm", "75 gr ELD-M", 75, 1.120, 0.467, 0.235),
        bullet("223-77-tmk", "77 gr TMK", 77, 0.994, 0.372, 0.190),
        bullet("223-80-eldm", "80 gr ELD-M", 80, 1.150, 0.485, 0.244),
        bullet("224-88-eldm", "88 gr ELD-M", 88, 1.245, 0.545, 0.274),
    ]

    private static let sixMillimeter: [CatalogBullet] = [
        bullet("6mm-108-eldm", "108 gr ELD-M", 108, 1.255, 0.536, 0.270),
    ]

    private static let twentyFive: [CatalogBullet] = [
        bullet("25-134-eldm", "134 gr ELD-M", 134, 1.420, 0.645, 0.325),
    ]

    private static let sixFive: [CatalogBullet] = [
        bullet("65-120-eldm", "120 gr ELD-M", 120, 1.250, 0.486, 0.245),
        bullet("65-123-eldm", "123 gr ELD-M", 123, 1.288, 0.506, 0.255),
        bullet("65-130-eldm", "130 gr ELD-M", 130, 1.335, 0.554, 0.279),
        bullet("65-140-eldm", "140 gr ELD-M", 140, 1.381, 0.646, 0.326),
        bullet("65-147-eldm", "147 gr ELD-M", 147, 1.451, 0.697, 0.351),
    ]

    private static let sevenMillimeter: [CatalogBullet] = [
        bullet("7mm-162-eldm", "162 gr ELD-M", 162, 1.490, 0.670, 0.338),
        bullet("7mm-180-eldm", "180 gr ELD-M", 180, 1.640, 0.796, 0.401),
    ]

    private static let thirtyCaliber: [CatalogBullet] = [
        bullet("308-155-eldm", "155 gr ELD-M", 155, 1.190, 0.461, 0.232),
        bullet("308-168-eldm", "168 gr ELD-M", 168, 1.270, 0.523, 0.263),
        bullet("308-168-smk", "168 gr SMK", 168, 1.215, 0.462, 0.218),
        bullet("308-175-smk", "175 gr SMK", 175, 1.240, 0.505, 0.243),
        bullet("308-178-eldm", "178 gr ELD-M", 178, 1.320, 0.547, 0.275),
        bullet("308-195-eldm", "195 gr ELD-M", 195, 1.430, 0.584, 0.294),
        bullet("308-208-eldm", "208 gr ELD-M", 208, 1.520, 0.690, 0.348),
        bullet("308-225-eldm", "225 gr ELD-M", 225, 1.640, 0.777, 0.391),
    ]

    private static let thirtyThree: [CatalogBullet] = [
        bullet("338-285-eldm", "285 gr ELD-M", 285, 1.825, 0.829, 0.417),
    ]
}

extension LoadProfile {
    var loadIdentity: LoadIdentity {
        LoadIdentity(
            muzzleVelocityFps: muzzleVelocityFps,
            bulletWeightGrains: bulletWeightGrains,
            diameterInches: diameterInches,
            lengthInches: lengthInches,
            ballisticCoefficient: ballisticCoefficient,
            dragModel: dragModel,
            twistInches: twistInches
        )
    }
}
