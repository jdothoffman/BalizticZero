import SwiftUI

struct LoadListView: View {
    @Bindable var store: CalculatorStore

    var body: some View {
        List {
            ForEach(store.profiles) { profile in
                NavigationLink {
                    LoadEditorView(store: store, profile: profile)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                            Text(loadSummary(profile))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profile.id == store.selectedProfile?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets.sorted(by: >) {
                    store.delete(store.profiles[index])
                }
            }
        }
        .navigationTitle("Load")
        .toolbar {
            Button("Add", systemImage: "plus") {
                store.addProfile()
            }
        }
    }

    private func loadSummary(_ profile: LoadProfile) -> String {
        let speed = DisplayFormat.speed(profile.muzzleVelocityFps, metric: store.useMetric)
        return "\(profile.dragModel.title) \(String(format: "%.3f", profile.ballisticCoefficient)) · \(speed)"
    }
}

struct LoadEditorView: View {
    @Bindable var store: CalculatorStore
    @Bindable var profile: LoadProfile

    var body: some View {
        Form {
            Section {
                TextField("Name", text: nameBinding)
                Button("Use this load") {
                    store.select(profile)
                }
            }

            Section {
                NumericField(title: "Muzzle velocity", value: velocityBinding, unit: store.useMetric ? "m/s" : "fps", decimals: 0)
                NumericField(title: "Weight", value: weightBinding, unit: store.useMetric ? "g" : "gr", decimals: 1)
                NumericField(title: "Diameter", value: diameterBinding, unit: store.useMetric ? "mm" : "in", decimals: 3)
                NumericField(title: "Length", value: lengthBinding, unit: store.useMetric ? "mm" : "in", decimals: 3)
                NumericField(title: "Ballistic coefficient", value: bcBinding, unit: profile.dragModel.title, decimals: 3)
                Picker("Drag model", selection: dragBinding) {
                    ForEach(DragModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
            } header: {
                Text("Bullet")
            } footer: {
                Text("Use a G7 coefficient with the G7 model for a boat-tail match bullet. Diameter and length feed the spin-drift estimate.")
            }

            Section {
                NumericField(title: "Sight height", value: sightBinding, unit: store.useMetric ? "cm" : "in", decimals: 2)
                NumericField(title: "Zero", value: zeroBinding, unit: store.useMetric ? "m" : "yd", decimals: 0)
                NumericField(title: "Twist", value: twistBinding, unit: store.useMetric ? "mm" : "in", decimals: 2)
            } header: {
                Text("Rifle")
            } footer: {
                Text("Twist is inches per turn. Positive is a right-hand twist, which drifts right.")
            }

            Section {
                Picker("Clicks", selection: clickUnitBinding) {
                    ForEach(ClickUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                NumericField(title: "Click value", value: clickValueBinding, unit: profile.clickUnit.title, decimals: 3)
            } footer: {
                Text("Quarter-minute scopes use 0.25 MOA. Tenth-mil scopes use 0.1 MIL.")
            }
        }
        .navigationTitle(profile.name)
        .scrollDismissesKeyboard(.interactively)
    }

    private var nameBinding: Binding<String> {
        Binding(get: { profile.name }, set: { profile.name = $0 })
    }

    private var dragBinding: Binding<DragModel> {
        Binding(get: { profile.dragModel }, set: { profile.dragModel = $0; store.recompute() })
    }

    private var clickUnitBinding: Binding<ClickUnit> {
        Binding(get: { profile.clickUnit }, set: { profile.clickUnit = $0; store.recompute() })
    }

    private var velocityBinding: Binding<Double> { converted(\.muzzleVelocityFps, toDisplay: UnitConverter.metersPerSecond(fromFps:), fromDisplay: UnitConverter.fps(fromMetersPerSecond:)) }
    private var weightBinding: Binding<Double> { converted(\.bulletWeightGrains, toDisplay: UnitConverter.grams(fromGrains:), fromDisplay: UnitConverter.grains(fromGrams:)) }
    private var diameterBinding: Binding<Double> { converted(\.diameterInches, toDisplay: UnitConverter.millimeters(fromInches:), fromDisplay: UnitConverter.inches(fromMillimeters:)) }
    private var lengthBinding: Binding<Double> { converted(\.lengthInches, toDisplay: UnitConverter.millimeters(fromInches:), fromDisplay: UnitConverter.inches(fromMillimeters:)) }
    private var sightBinding: Binding<Double> { converted(\.sightHeightInches, toDisplay: UnitConverter.centimeters(fromInches:), fromDisplay: UnitConverter.inches(fromCentimeters:)) }
    private var zeroBinding: Binding<Double> { converted(\.zeroRangeYards, toDisplay: UnitConverter.meters(fromYards:), fromDisplay: UnitConverter.yards(fromMeters:)) }
    private var twistBinding: Binding<Double> { converted(\.twistInches, toDisplay: UnitConverter.millimeters(fromInches:), fromDisplay: UnitConverter.inches(fromMillimeters:), signed: true) }

    private var bcBinding: Binding<Double> {
        Binding(get: { profile.ballisticCoefficient }, set: { profile.ballisticCoefficient = $0; store.recompute() })
    }

    private var clickValueBinding: Binding<Double> {
        Binding(get: { profile.clickValue }, set: { profile.clickValue = $0; store.recompute() })
    }

    private func converted(
        _ keyPath: ReferenceWritableKeyPath<LoadProfile, Double>,
        toDisplay: @escaping (Double) -> Double,
        fromDisplay: @escaping (Double) -> Double,
        signed: Bool = false
    ) -> Binding<Double> {
        Binding(
            get: {
                let raw = profile[keyPath: keyPath]
                guard store.useMetric else { return raw }
                if signed, raw < 0 { return -toDisplay(-raw) }
                return toDisplay(raw)
            },
            set: { newValue in
                let stored: Double
                if store.useMetric {
                    if signed, newValue < 0 {
                        stored = -fromDisplay(-newValue)
                    } else {
                        stored = fromDisplay(newValue)
                    }
                } else {
                    stored = newValue
                }
                profile[keyPath: keyPath] = stored
                store.recompute()
            }
        )
    }
}
