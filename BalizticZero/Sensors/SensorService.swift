import CoreLocation
import CoreMotion
import Foundation
import Observation

struct SensorReading: Equatable {
    var latitude: Double?
    var longitude: Double?
    var altitudeFeet: Double?
    var magneticHeading: Double?
    var pressureInHg: Double?
    var inclineDegrees: Double?
}

@MainActor
@Observable
final class SensorService {
    private(set) var statusMessage = "Sensors are idle. Values stay editable either way."
    private(set) var altimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    private(set) var motionAvailable = false

    var onUpdate: ((SensorReading) -> Void)?
    var onFinished: (() -> Void)?

    @ObservationIgnored private let bridge = LocationBridge()
    @ObservationIgnored private let altimeter = CMAltimeter()
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var gotLocation = false
    @ObservationIgnored private var gotPressure = false
    @ObservationIgnored private var gotHeading = false
    @ObservationIgnored private let inclineSamples = SampleBucket()

    init() {
        motionAvailable = motion.isDeviceMotionAvailable
        bridge.onLocation = { [weak self] location in
            Task { @MainActor in
                self?.accept(location: location)
            }
        }
        bridge.onHeading = { [weak self] heading in
            Task { @MainActor in
                self?.accept(heading: heading)
            }
        }
        bridge.onAuthorization = { [weak self] status in
            Task { @MainActor in
                self?.accept(authorization: status)
            }
        }
        bridge.onFailure = { [weak self] message in
            Task { @MainActor in
                self?.statusMessage = message
            }
        }
    }

    func startLocationAndPressure() {
        gotLocation = false
        gotPressure = false
        gotHeading = false
        statusMessage = "Reading location, magnetic heading, and pressure…"
        bridge.start()
        startAltimeter()
    }

    func stopLocationAndPressure() {
        bridge.stop()
        altimeter.stopRelativeAltitudeUpdates()
    }

    func measureIncline() {
        guard motion.isDeviceMotionAvailable else {
            statusMessage = "This iPhone cannot measure incline. Enter the angle."
            return
        }
        inclineSamples.values.removeAll()
        statusMessage = "Point the top of the phone along the barrel."
        motion.deviceMotionUpdateInterval = 0.05
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let clamped = min(1, max(-1, -data.gravity.y))
            let degrees = asin(clamped) * 180 / .pi
            Task { @MainActor in
                self.inclineSamples.values.append(degrees)
                guard self.inclineSamples.values.count >= 8 else { return }
                self.motion.stopDeviceMotionUpdates()
                let average = self.inclineSamples.values.reduce(0, +) / Double(self.inclineSamples.values.count)
                self.statusMessage = String(format: "Incline measured at %.1f°.", average)
                self.onUpdate?(SensorReading(inclineDegrees: average))
            }
        }
    }

    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            altimeterAvailable = false
            return
        }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let inHg = data.pressure.doubleValue / 3.38638866667
            Task { @MainActor in
                self.gotPressure = true
                self.onUpdate?(SensorReading(pressureInHg: inHg))
                self.finishIfComplete()
            }
        }
    }

    private func accept(location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }
        gotLocation = true
        onUpdate?(SensorReading(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeFeet: location.altitude * 3.280839895
        ))
        finishIfComplete()
    }

    private func accept(heading: CLHeading) {
        guard heading.headingAccuracy >= 0 else { return }
        gotHeading = true
        onUpdate?(SensorReading(magneticHeading: heading.magneticHeading))
        finishIfComplete()
    }

    private func accept(authorization: CLAuthorizationStatus) {
        switch authorization {
        case .denied, .restricted:
            statusMessage = "Location access is off. Enter latitude, altitude, and azimuth yourself."
            stopLocationAndPressure()
        case .authorizedAlways, .authorizedWhenInUse:
            statusMessage = "Reading location, magnetic heading, and pressure…"
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    private func finishIfComplete() {
        let pressureReady = gotPressure || !altimeterAvailable
        guard gotLocation, pressureReady, gotHeading else { return }
        stopLocationAndPressure()
        statusMessage = "Sensor values filled. You can edit any field."
        onFinished?()
    }
}

private final class LocationBridge: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var onLocation: ((CLLocation) -> Void)?
    var onHeading: ((CLHeading) -> Void)?
    var onAuthorization: ((CLAuthorizationStatus) -> Void)?
    var onFailure: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 2
        manager.headingOrientation = .portrait
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocation?(location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        onHeading?(newHeading)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorization?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onFailure?(error.localizedDescription)
    }
}

private final class SampleBucket {
    var values: [Double] = []
}
