import Foundation

struct TrajectorySample: Equatable {
    var horizontalFeet: Double
    var verticalFeet: Double
    var crossFeet: Double
    var velocityFps: Double
    var timeSeconds: Double

    func slantHeightFeet(lookAngleRadians: Double) -> Double {
        verticalFeet * cos(lookAngleRadians) - horizontalFeet * sin(lookAngleRadians)
    }
}

enum TrajectorySolver {
    private static let timeStep = 0.001
    private static let maximumTime = 45.0

    static func solve(_ request: ShotRequest) -> FiringSolution? {
        let load = request.load
        guard load.ballisticCoefficient > 0.01, load.muzzleVelocityFps > 100, load.clickValue > 0 else { return nil }
        let rangeYards = min(max(request.context.rangeYards, 10), 2000)
        let look = min(max(request.context.inclineDegrees, -65), 65) * .pi / 180
        guard let zero = zeroAngleRadians(load: load, atmosphere: request.atmosphere) else { return nil }

        let ranges = sampleRanges(targetYards: rangeYards, zeroYards: load.zeroRangeYards)
        let cosine = cos(look)
        guard abs(cosine) > 0.05 else { return nil }
        let horizontalTargets = ranges.map { $0 * 3 * cosine }
        let barrel = look + zero

        guard let withCoriolis = integrate(
            load: load,
            atmosphere: request.atmosphere,
            wind: request.wind,
            azimuthDegrees: request.context.azimuthDegrees,
            latitudeDegrees: request.context.latitudeDegrees,
            barrelElevationRadians: barrel,
            horizontalFeet: horizontalTargets
        ) else { return nil }

        guard let withoutCoriolis = integrate(
            load: load,
            atmosphere: request.atmosphere,
            wind: request.wind,
            azimuthDegrees: request.context.azimuthDegrees,
            latitudeDegrees: nil,
            barrelElevationRadians: barrel,
            horizontalFeet: [rangeYards * 3 * cosine]
        ) else { return nil }

        let rows = withCoriolis.enumerated().map { index, sample in
            row(
                rangeYards: ranges[index],
                sample: sample,
                lookAngleRadians: look,
                load: load,
                atmosphere: request.atmosphere
            )
        }
        guard let target = rows.last, let aero = withoutCoriolis.last, let full = withCoriolis.last else { return nil }

        let spin = SpinDrift.inches(
            timeSeconds: full.timeSeconds,
            muzzleVelocityFps: load.muzzleVelocityFps,
            weightGrains: load.bulletWeightGrains,
            diameterInches: load.diameterInches,
            lengthInches: load.lengthInches,
            twistInches: load.twistInches,
            temperatureF: request.atmosphere.temperatureF,
            pressureInHg: request.atmosphere.stationPressureInHg
        )
        let fullHeight = full.slantHeightFeet(lookAngleRadians: look)
        let aeroHeight = aero.slantHeightFeet(lookAngleRadians: look)

        return FiringSolution(
            rows: rows,
            target: target,
            zeroAngleMOA: zero * 180 / .pi * 60,
            densityRatio: AtmosphereModel.densityRatio(request.atmosphere),
            densityAltitudeFeet: AtmosphereModel.densityAltitudeFeet(request.atmosphere),
            speedOfSoundFps: AtmosphereModel.speedOfSoundFps(request.atmosphere),
            spinDriftInches: spin,
            coriolisHorizontalInches: (full.crossFeet - aero.crossFeet) * 12,
            coriolisVerticalInches: (fullHeight - aeroHeight) * 12,
            aerodynamicWindageInches: aero.crossFeet * 12
        )
    }

    /// Bore angle above a flat line of sight so the bullet crosses it at the zero range. No wind and no Coriolis.
    static func zeroAngleRadians(load: BallisticLoad, atmosphere: Atmosphere) -> Double? {
        let rangeFeet = load.zeroRangeYards * 3
        guard rangeFeet > 1 else { return nil }

        func height(at angle: Double) -> Double? {
            integrate(
                load: load,
                atmosphere: atmosphere,
                wind: Wind(speedMph: 0, fromDegrees: 0),
                azimuthDegrees: 0,
                latitudeDegrees: nil,
                barrelElevationRadians: angle,
                horizontalFeet: [rangeFeet]
            )?.first?.verticalFeet
        }

        var low = 0.0
        var high = 0.02
        guard var yHigh = height(at: high) else { return nil }
        var expansions = 0
        while yHigh < 0, expansions < 8 {
            high += 0.03
            guard let next = height(at: high) else { return nil }
            yHigh = next
            expansions += 1
        }
        guard yHigh >= 0, var yLow = height(at: low) else { return nil }
        if yLow > 0 { return low }

        for _ in 0..<28 {
            let mid = (low + high) / 2
            guard let yMid = height(at: mid) else { return nil }
            if yMid < 0 {
                low = mid
                yLow = yMid
            } else {
                high = mid
                yHigh = yMid
            }
        }
        return (low + high) / 2
    }

    /// Point-mass RK4 in a horizontal frame. `latitudeDegrees == nil` leaves Coriolis off.
    static func integrate(
        load: BallisticLoad,
        atmosphere: Atmosphere,
        wind: Wind,
        azimuthDegrees: Double,
        latitudeDegrees: Double?,
        barrelElevationRadians: Double,
        horizontalFeet: [Double]
    ) -> [TrajectorySample]? {
        let distances = Array(Set(horizontalFeet.filter { $0.isFinite })).sorted()
        guard !distances.isEmpty else { return [] }
        guard load.ballisticCoefficient > 0, load.muzzleVelocityFps > 0 else { return nil }

        let air = Wind.airVelocityFPS(
            speedMph: max(0, min(wind.speedMph, 200)),
            fromDegrees: wind.fromDegrees,
            azimuthDegrees: azimuthDegrees
        )
        var x = 0.0
        var y = -load.sightHeightInches / 12
        var z = 0.0
        var vx = load.muzzleVelocityFps * cos(barrelElevationRadians)
        var vy = load.muzzleVelocityFps * sin(barrelElevationRadians)
        var vz = 0.0
        var time = 0.0
        var pending = distances
        var samples: [TrajectorySample] = []
        let dt = timeStep

        while !pending.isEmpty {
            if time > maximumTime || vx < 1 { return nil }
            // `y` is height above the sight origin, so it is the lapse offset from the station.
            let densityRatio = AtmosphereModel.densityRatio(atmosphere, atVerticalFeet: y)
            let mach = AtmosphereModel.speedOfSoundFps(atmosphere, atVerticalFeet: y)

            func acceleration(vx: Double, vy: Double, vz: Double) -> (x: Double, y: Double, z: Double) {
                let rx = vx - air.downrange
                let ry = vy
                let rz = vz - air.right
                let speed = sqrt(rx * rx + ry * ry + rz * rz)
                let cd = DragTable.coefficient(model: load.dragModel, mach: speed / mach)
                let km = densityRatio * cd * AtmosphereModel.dragConstant / load.ballisticCoefficient
                var ax = -km * rx * speed
                var ay = -AtmosphereModel.gravityFps2 - km * ry * speed
                var az = -km * rz * speed
                if let latitude = latitudeDegrees {
                    let coriolis = Coriolis.acceleration(
                        velocityX: vx,
                        velocityY: vy,
                        velocityZ: vz,
                        latitudeDegrees: latitude,
                        azimuthDegrees: azimuthDegrees
                    )
                    ax += coriolis.x
                    ay += coriolis.y
                    az += coriolis.z
                }
                return (ax, ay, az)
            }

            let a1 = acceleration(vx: vx, vy: vy, vz: vz)
            let v2x = vx + 0.5 * dt * a1.x
            let v2y = vy + 0.5 * dt * a1.y
            let v2z = vz + 0.5 * dt * a1.z
            let a2 = acceleration(vx: v2x, vy: v2y, vz: v2z)
            let v3x = vx + 0.5 * dt * a2.x
            let v3y = vy + 0.5 * dt * a2.y
            let v3z = vz + 0.5 * dt * a2.z
            let a3 = acceleration(vx: v3x, vy: v3y, vz: v3z)
            let v4x = vx + dt * a3.x
            let v4y = vy + dt * a3.y
            let v4z = vz + dt * a3.z
            let a4 = acceleration(vx: v4x, vy: v4y, vz: v4z)

            let nx = x + (vx + 2 * v2x + 2 * v3x + v4x) * (dt / 6)
            let ny = y + (vy + 2 * v2y + 2 * v3y + v4y) * (dt / 6)
            let nz = z + (vz + 2 * v2z + 2 * v3z + v4z) * (dt / 6)
            let nvx = vx + (a1.x + 2 * a2.x + 2 * a3.x + a4.x) * (dt / 6)
            let nvy = vy + (a1.y + 2 * a2.y + 2 * a3.y + a4.y) * (dt / 6)
            let nvz = vz + (a1.z + 2 * a2.z + 2 * a3.z + a4.z) * (dt / 6)
            guard nx > x else { return nil }

            while let target = pending.first, nx >= target {
                let fraction = (target - x) / (nx - x)
                let px = x + (nx - x) * fraction
                let py = y + (ny - y) * fraction
                let pz = z + (nz - z) * fraction
                let pvx = vx + (nvx - vx) * fraction
                let pvy = vy + (nvy - vy) * fraction
                let pvz = vz + (nvz - vz) * fraction
                let speed = sqrt(pvx * pvx + pvy * pvy + pvz * pvz)
                samples.append(TrajectorySample(
                    horizontalFeet: px,
                    verticalFeet: py,
                    crossFeet: pz,
                    velocityFps: speed,
                    timeSeconds: time + dt * fraction
                ))
                pending.removeFirst()
            }

            x = nx
            y = ny
            z = nz
            vx = nvx
            vy = nvy
            vz = nvz
            time += dt
        }
        return samples
    }

    private static func sampleRanges(targetYards: Double, zeroYards: Double) -> [Double] {
        var ranges: [Double] = []
        if zeroYards >= 10, zeroYards < targetYards - 0.5 {
            ranges.append(zeroYards)
        }
        var step = 100.0
        while step < targetYards - 0.5 {
            ranges.append(step)
            step += 100
        }
        ranges.append(targetYards)
        return Array(Set(ranges)).sorted()
    }

    private static func row(
        rangeYards: Double,
        sample: TrajectorySample,
        lookAngleRadians: Double,
        load: BallisticLoad,
        atmosphere: Atmosphere
    ) -> TrajectoryRow {
        let slantFeet = sample.horizontalFeet * cos(lookAngleRadians) + sample.verticalFeet * sin(lookAngleRadians)
        let pathFeet = sample.slantHeightFeet(lookAngleRadians: lookAngleRadians)
        let bulletAngle = atan2(sample.verticalFeet, sample.horizontalFeet)
        let comeUp = lookAngleRadians - bulletAngle
        let spin = SpinDrift.inches(
            timeSeconds: sample.timeSeconds,
            muzzleVelocityFps: load.muzzleVelocityFps,
            weightGrains: load.bulletWeightGrains,
            diameterInches: load.diameterInches,
            lengthInches: load.lengthInches,
            twistInches: load.twistInches,
            temperatureF: atmosphere.temperatureF,
            pressureInHg: atmosphere.stationPressureInHg
        )
        let windageFeet = sample.crossFeet + spin / 12
        let windageAngle = atan2(windageFeet, max(slantFeet, 1))
        let comeUpMOA = comeUp * 180 / .pi * 60
        let comeUpMIL = comeUp * 1000
        let windageMOA = windageAngle * 180 / .pi * 60
        let windageMIL = windageAngle * 1000
        let elevationClicks: Double
        let windageClicks: Double
        switch load.clickUnit {
        case .moa:
            elevationClicks = comeUpMOA / load.clickValue
            windageClicks = windageMOA / load.clickValue
        case .mil:
            elevationClicks = comeUpMIL / load.clickValue
            windageClicks = windageMIL / load.clickValue
        }
        return TrajectoryRow(
            rangeYards: rangeYards,
            pathInches: pathFeet * 12,
            comeUpMOA: comeUpMOA,
            comeUpMIL: comeUpMIL,
            windageInches: windageFeet * 12,
            windageMOA: windageMOA,
            windageMIL: windageMIL,
            velocityFps: sample.velocityFps,
            energyFootPounds: AtmosphereModel.energyFootPounds(weightGrains: load.bulletWeightGrains, velocityFps: sample.velocityFps),
            timeSeconds: sample.timeSeconds,
            elevationClicks: elevationClicks,
            windageClicks: windageClicks
        )
    }
}
