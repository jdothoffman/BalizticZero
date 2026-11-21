import SwiftUI

struct ShotView: View {
    @Bindable var store: CalculatorStore

    var body: some View {
        Form {
            Section {
                NumericField(title: "Range", value: rangeBinding, unit: store.useMetric ? "m" : "yd", decimals: 0)
                NumericField(title: "Zero", value: zeroBinding, unit: store.useMetric ? "m" : "yd", decimals: 0)
                NumericField(title: "Incline", value: $store.inclineDegrees, unit: "°", decimals: 1)
                Button("Measure incline") {
                    store.measureIncline()
                }
            } header: {
                Text("Target")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if store.sensors.statusMessage.hasPrefix("Incline") || store.sensors.statusMessage.contains("cannot measure") {
                        Text(store.sensors.statusMessage)
                    }
                    Text("Point the top of the phone along the barrel, then measure. Positive incline is uphill. Zero is solved flat, in this air, with no wind.")
                }
            }

            Section {
                NumericField(title: "Wind speed", value: windSpeedBinding, unit: store.useMetric ? "m/s" : "mph", decimals: 1)
                NumericField(title: "Wind from", value: $store.windFromDegrees, unit: "°", decimals: 0)
                NumericField(title: "Azimuth", value: azimuthBinding, unit: "° mag", decimals: 0)
            } header: {
                Text("Wind")
            } footer: {
                Text("\(windSummary) Azimuth is magnetic. Coriolis uses it directly until declination is added. Wind from is the compass direction the wind comes from: 0 is north, 90 is east.")
            }
        }
        .navigationTitle("Shot")
        .scrollDismissesKeyboard(.interactively)
    }

    private var windSummary: String {
        let clock = Wind.clockLabel(fromDegrees: store.windFromDegrees, azimuthDegrees: store.azimuthDegrees)
        let words = Wind.directionWords(fromDegrees: store.windFromDegrees, azimuthDegrees: store.azimuthDegrees)
        let relative = Wind.relativeDegrees(fromDegrees: store.windFromDegrees, azimuthDegrees: store.azimuthDegrees) * .pi / 180
        let cross = abs(store.windSpeedMph * sin(relative))
        let crossText = store.useMetric
            ? String(format: "%.1f m/s", UnitConverter.metersPerSecond(fromMph: cross))
            : String(format: "%.1f mph", cross)
        return "\(clock), \(words). Crosswind \(crossText)."
    }

    private var rangeBinding: Binding<Double> {
        Binding(
            get: { store.useMetric ? UnitConverter.meters(fromYards: store.rangeYards) : store.rangeYards },
            set: { store.rangeYards = store.useMetric ? UnitConverter.yards(fromMeters: $0) : $0 }
        )
    }

    private var zeroBinding: Binding<Double> {
        Binding(
            get: {
                let yards = store.selectedProfile?.zeroRangeYards ?? 100
                return store.useMetric ? UnitConverter.meters(fromYards: yards) : yards
            },
            set: { newValue in
                let yards = store.useMetric ? UnitConverter.yards(fromMeters: newValue) : newValue
                store.updateProfile(\.zeroRangeYards, to: yards)
            }
        )
    }

    private var windSpeedBinding: Binding<Double> {
        Binding(
            get: { store.useMetric ? UnitConverter.metersPerSecond(fromMph: store.windSpeedMph) : store.windSpeedMph },
            set: { store.windSpeedMph = store.useMetric ? UnitConverter.mph(fromMetersPerSecond: $0) : $0 }
        )
    }

    private var azimuthBinding: Binding<Double> {
        Binding(
            get: { store.azimuthDegrees },
            set: {
                store.holdManualSensorInput()
                store.azimuthDegrees = $0
            }
        )
    }
}
