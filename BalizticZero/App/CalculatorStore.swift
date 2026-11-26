import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CalculatorStore {
    var rangeYards = 800.0
    var windSpeedMph = 10.0
    var windFromDegrees = 90.0
    var azimuthDegrees = 0.0
    var inclineDegrees = 0.0
    var latitude = 0.0
    var longitude = 0.0
    var altitudeFeet = 0.0
    var temperatureF = Atmosphere.icaoSeaLevel.temperatureF
    var pressureInHg = Atmosphere.icaoSeaLevel.stationPressureInHg
    var humidityPercent = 0.0
    /// Power the scope is set to. Used when the reticle is second focal plane.
    var magnification = 25.0
    var pressureSource: PressureSource = .standardForAltitude
    var useMetric = UserDefaults.standard.bool(forKey: Keys.useMetric)
    var acceptingSensors = false
    var statusMessage: String?
    var solution: FiringSolution?

    let weatherProvider: any WeatherProviding
    let elevationProvider: any ElevationProviding
    let advisor: any BallisticAdvising
    let sensors: SensorService

    private let context: ModelContext
    private var selectedProfileID: UUID?
    private var sensorToken = 0
    private(set) var profiles: [LoadProfile] = []

    init(
        context: ModelContext,
        weatherProvider: any WeatherProviding = UnconfiguredWeatherProvider(),
        elevationProvider: any ElevationProviding = UnconfiguredElevationProvider(),
        advisor: any BallisticAdvising = UnavailableBallisticAdvisor()
    ) {
        self.context = context
        self.weatherProvider = weatherProvider
        self.elevationProvider = elevationProvider
        self.advisor = advisor
        sensors = SensorService()
        if let stored = UserDefaults.standard.string(forKey: Keys.profileID) {
            selectedProfileID = UUID(uuidString: stored)
        }
        sensors.onUpdate = { [weak self] reading in
            self?.apply(reading)
        }
        sensors.onFinished = { [weak self] in
            self?.acceptingSensors = false
        }
        reloadProfiles()
        recompute()
    }

    var selectedProfile: LoadProfile? {
        profiles.first { $0.id == selectedProfileID } ?? profiles.first
    }

    var inputFingerprint: String {
        var parts: [String] = []
        func add(_ value: Double) { parts.append(String(format: "%.5f", value)) }
        add(rangeYards)
        add(windSpeedMph)
        add(windFromDegrees)
        add(azimuthDegrees)
        add(inclineDegrees)
        add(latitude)
        add(longitude)
        add(altitudeFeet)
        add(temperatureF)
        add(pressureInHg)
        add(humidityPercent)
        if let load = selectedProfile?.ballisticLoad {
            add(load.muzzleVelocityFps)
            add(load.bulletWeightGrains)
            add(load.diameterInches)
            add(load.lengthInches)
            add(load.ballisticCoefficient)
            add(load.sightHeightInches)
            add(load.zeroRangeYards)
            add(load.twistInches)
            add(load.clickValue)
            add(load.travelPerTurnMOA)
            add(load.elevationTravelMOA)
            add(load.windageTravelMOA)
            add(load.railCantMOA)
            add(load.reticleTrueMagnification)
            add(load.hashSpacingMIL)
            parts.append(load.dragModel.rawValue)
            parts.append(load.clickUnit.rawValue)
            parts.append(load.reticleUnit.rawValue)
            parts.append(load.focalPlane.rawValue)
        }
        add(magnification)
        parts.append(useMetric ? "metric" : "imperial")
        parts.append(selectedProfile?.id.uuidString ?? "")
        return parts.joined(separator: "|")
    }

    func recompute() {
        if rangeYards > 2000 { rangeYards = 2000 }
        if rangeYards < 10 { rangeYards = 10 }
        if inclineDegrees > 65 { inclineDegrees = 65 }
        if inclineDegrees < -65 { inclineDegrees = -65 }
        if magnification < 1 { magnification = 1 }
        if magnification > 100 { magnification = 100 }
        guard let load = selectedProfile?.ballisticLoad else {
            solution = nil
            statusMessage = "Add a load profile to calculate a shot."
            return
        }
        guard load.ballisticCoefficient > 0.01 else {
            solution = nil
            statusMessage = "Enter a ballistic coefficient greater than 0.01."
            return
        }
        guard load.muzzleVelocityFps > 100 else {
            solution = nil
            statusMessage = "Enter a muzzle velocity."
            return
        }
        guard load.clickValue > 0 else {
            solution = nil
            statusMessage = "Enter a scope click value, such as 0.25 MOA or 0.1 MRAD."
            return
        }
        let request = ShotRequest(
            load: load,
            atmosphere: Atmosphere(
                temperatureF: temperatureF,
                stationPressureInHg: pressureInHg,
                humidityPercent: humidityPercent,
                altitudeFeet: altitudeFeet
            ),
            wind: Wind(speedMph: windSpeedMph, fromDegrees: windFromDegrees),
            context: ShotContext(
                rangeYards: rangeYards,
                azimuthDegrees: azimuthDegrees,
                inclineDegrees: inclineDegrees,
                latitudeDegrees: latitude,
                longitudeDegrees: longitude
            )
        )
        if let solution = TrajectorySolver.solve(request) {
            self.solution = solution
            statusMessage = nil
        } else {
            solution = nil
            statusMessage = "This load does not reach that range."
        }
    }

    func select(_ profile: LoadProfile) {
        selectedProfileID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: Keys.profileID)
        recompute()
    }

    func addProfile() {
        let profile = LoadProfile(
            name: "New load",
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
        context.insert(profile)
        try? context.save()
        profiles.append(profile)
        select(profile)
    }

    func delete(_ profile: LoadProfile) {
        context.delete(profile)
        try? context.save()
        profiles.removeAll { $0.id == profile.id }
        if profiles.isEmpty {
            let replacement = LoadProfile.standard308()
            context.insert(replacement)
            try? context.save()
            profiles = [replacement]
        }
        if selectedProfileID == profile.id {
            select(profiles[0])
        } else {
            recompute()
        }
    }

    func setUseMetric(_ metric: Bool) {
        useMetric = metric
        UserDefaults.standard.set(metric, forKey: Keys.useMetric)
    }

    func setAltitude(_ feet: Double) {
        altitudeFeet = feet
        if pressureSource == .standardForAltitude {
            pressureInHg = Atmosphere.standardPressureInHg(altitudeFeet: feet)
        }
        recompute()
    }

    func setPressure(_ inHg: Double, source: PressureSource) {
        pressureInHg = inHg
        pressureSource = source
        recompute()
    }

    func useStandardPressure() {
        pressureSource = .standardForAltitude
        pressureInHg = Atmosphere.standardPressureInHg(altitudeFeet: altitudeFeet)
        recompute()
    }

    func usePhoneSensors() {
        sensorToken += 1
        let token = sensorToken
        acceptingSensors = true
        sensors.startLocationAndPressure()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(20))
            guard token == self.sensorToken, self.acceptingSensors else { return }
            self.stopSensors(message: self.sensors.receivedLocation
                ? "Sensor reading finished. Edit any value that needs it."
                : "No location fix in 20 seconds. Try again with a clear view of the sky, or enter latitude and longitude yourself.")
        }
    }

    func stopSensors(message: String? = nil) {
        acceptingSensors = false
        sensors.stopLocationAndPressure(message: message ?? "Sensor updates stopped. Fields stay as they are.")
    }

    func holdManualSensorInput() {
        if acceptingSensors {
            stopSensors(message: "Manual edit kept. Sensor fill is off.")
        }
    }

    func measureIncline() {
        sensors.measureIncline()
    }

    func refreshWeather() async {
        guard weatherProvider.isConfigured else { return }
        do {
            let conditions = try await weatherProvider.fetchConditions(latitude: latitude, longitude: longitude)
            temperatureF = conditions.temperatureF
            setPressure(conditions.stationPressureInHg, source: .manual)
            humidityPercent = conditions.humidityPercent
            windSpeedMph = conditions.windSpeedMph
            windFromDegrees = conditions.windFromDegrees
            recompute()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func updateProfile(_ keyPath: ReferenceWritableKeyPath<LoadProfile, Double>, to value: Double) {
        selectedProfile?[keyPath: keyPath] = value
        recompute()
    }

    private func apply(_ reading: SensorReading) {
        guard acceptingSensors || reading.inclineDegrees != nil else { return }
        if let latitude = reading.latitude {
            self.latitude = latitude
        }
        if let longitude = reading.longitude {
            self.longitude = longitude
        }
        if let altitude = reading.altitudeFeet {
            altitudeFeet = altitude
            if pressureSource == .standardForAltitude {
                pressureInHg = Atmosphere.standardPressureInHg(altitudeFeet: altitude)
            }
        }
        if let heading = reading.magneticHeading {
            azimuthDegrees = heading
        }
        if let pressure = reading.pressureInHg {
            pressureInHg = pressure
            pressureSource = .barometer
        }
        if let incline = reading.inclineDegrees {
            inclineDegrees = min(65, max(-65, incline))
        }
        recompute()
    }

    private func reloadProfiles() {
        let descriptor = FetchDescriptor<LoadProfile>(sortBy: [SortDescriptor(\.createdAt)])
        let found = (try? context.fetch(descriptor)) ?? []
        if found.isEmpty {
            let profile = LoadProfile.standard308()
            context.insert(profile)
            try? context.save()
            profiles = [profile]
        } else {
            profiles = found
        }
        if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
            selectedProfileID = profiles.first?.id
            if let id = selectedProfileID {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.profileID)
            }
        }
    }

    private enum Keys {
        static let useMetric = "useMetric"
        static let profileID = "selectedProfileID"
    }
}
