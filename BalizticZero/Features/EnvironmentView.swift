import SwiftUI

struct EnvironmentView: View {
    @Bindable var store: CalculatorStore

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: metricBinding) {
                    Text("Imperial").tag(false)
                    Text("Metric").tag(true)
                }
                .pickerStyle(.segmented)
            }
            .themedRows()

            Section {
                NumericField(title: "Temperature", value: temperatureBinding, unit: store.useMetric ? "°C" : "°F", decimals: 1)
                NumericField(title: "Pressure", value: pressureBinding, unit: store.useMetric ? "hPa" : "inHg", decimals: store.useMetric ? 0 : 2)
                NumericField(title: "Humidity", value: $store.humidityPercent, unit: "%", decimals: 0)
                NumericField(title: "Altitude", value: altitudeBinding, unit: store.useMetric ? "m" : "ft", decimals: 0)
            } header: {
                SectionLabel("Air")
            } footer: {
                Text("Density altitude \(DisplayFormat.altitude(store.solution?.densityAltitudeFeet ?? AtmosphereModel.densityAltitudeFeet(currentAtmosphere), metric: store.useMetric)). Density ratio \(String(format: "%.3f", store.solution?.densityRatio ?? AtmosphereModel.densityRatio(currentAtmosphere))). The phone has no thermometer or humidity sensor.")
            }
            .themedRows()

            Section {
                NumericField(title: "Latitude", value: latitudeBinding, unit: "°", decimals: 4)
                NumericField(title: "Longitude", value: longitudeBinding, unit: "°", decimals: 4)
                Button(store.acceptingSensors ? "Stop sensors" : "Use iPhone sensors") {
                    if store.acceptingSensors {
                        store.stopSensors()
                    } else {
                        store.usePhoneSensors()
                    }
                }
                Button("Standard pressure for this altitude") {
                    store.useStandardPressure()
                }
            } header: {
                SectionLabel("Location")
            } footer: {
                Text(store.sensors.statusMessage + " " + store.elevationProvider.sourceNote)
            }
            .themedRows()

            Section {
                Button("Update weather") {
                    Task { await store.refreshWeather() }
                }
                .disabled(!store.weatherProvider.isConfigured)
            } footer: {
                Text(store.weatherProvider.sourceNote)
            }
            .themedRows()
        }
        .themedForm()
        .navigationTitle("Conditions")
        .scrollDismissesKeyboard(.interactively)
    }

    private var currentAtmosphere: Atmosphere {
        Atmosphere(
            temperatureF: store.temperatureF,
            stationPressureInHg: store.pressureInHg,
            humidityPercent: store.humidityPercent,
            altitudeFeet: store.altitudeFeet
        )
    }

    private var metricBinding: Binding<Bool> {
        Binding(get: { store.useMetric }, set: { store.setUseMetric($0) })
    }

    private var temperatureBinding: Binding<Double> {
        Binding(
            get: { store.useMetric ? UnitConverter.celsius(fromFahrenheit: store.temperatureF) : store.temperatureF },
            set: { store.temperatureF = store.useMetric ? UnitConverter.fahrenheit(fromCelsius: $0) : $0 }
        )
    }

    private var pressureBinding: Binding<Double> {
        Binding(
            get: { store.useMetric ? UnitConverter.hPa(fromInHg: store.pressureInHg) : store.pressureInHg },
            set: {
                let inHg = store.useMetric ? UnitConverter.inHg(fromHPa: $0) : $0
                store.setPressure(inHg, source: .manual)
            }
        )
    }

    private var altitudeBinding: Binding<Double> {
        Binding(
            get: { store.useMetric ? UnitConverter.meters(fromFeet: store.altitudeFeet) : store.altitudeFeet },
            set: {
                store.holdManualSensorInput()
                let feet = store.useMetric ? UnitConverter.feet(fromMeters: $0) : $0
                store.setAltitude(feet)
            }
        )
    }

    private var latitudeBinding: Binding<Double> {
        Binding(
            get: { store.latitude },
            set: {
                store.holdManualSensorInput()
                store.latitude = $0
            }
        )
    }

    private var longitudeBinding: Binding<Double> {
        Binding(
            get: { store.longitude },
            set: {
                store.holdManualSensorInput()
                store.longitude = $0
            }
        )
    }
}
