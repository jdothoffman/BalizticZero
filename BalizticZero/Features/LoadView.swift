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
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.name)
                                .font(.body.weight(.medium))
                            Text(loadSummary(profile))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profile.id == store.selectedProfile?.id {
                            Text("IN USE")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .themedRows()
            }
            .onDelete { offsets in
                for index in offsets.sorted(by: >) {
                    store.delete(store.profiles[index])
                }
            }
        }
        .themedForm()
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

private enum LoadEntryMode: String, CaseIterable, Identifiable {
    case preset
    case build

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preset: "Preset"
        case .build: "Build"
        }
    }
}

struct LoadEditorView: View {
    @Bindable var store: CalculatorStore
    @Bindable var profile: LoadProfile
    @State private var entryMode: LoadEntryMode = .preset
    @State private var didChooseMode = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: nameBinding)
                Button("Use this load") {
                    store.select(profile)
                }
            }
            .themedRows()

            Section {
                Picker("Entry", selection: $entryMode) {
                    ForEach(LoadEntryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if entryMode == .preset {
                    Picker("Load", selection: presetBinding) {
                        if LoadCatalog.preset(matching: profile.loadIdentity) == nil {
                            Text("Choose a load").tag(LoadCatalog.customID)
                        }
                        ForEach(LoadCatalog.cartridges) { cartridge in
                            let loads = LoadCatalog.presets(for: cartridge.id)
                            if !loads.isEmpty {
                                Section(cartridge.name) {
                                    ForEach(loads) { load in
                                        Text(load.menuTitle).tag(load.id)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Picker("Caliber", selection: cartridgeBinding) {
                        if LoadCatalog.cartridge(for: profile.loadIdentity) == nil {
                            Text("Current").tag(LoadCatalog.customID)
                        }
                        ForEach(LoadCatalog.cartridges) { cartridge in
                            Text(cartridge.name).tag(cartridge.id)
                        }
                    }
                    Picker("Bullet", selection: bulletBinding) {
                        if LoadCatalog.bullet(matching: profile.loadIdentity) == nil {
                            Text("Current \(LoadCatalog.weight(profile.bulletWeightGrains, metric: false))").tag(LoadCatalog.customID)
                        }
                        ForEach(bulletChoices) { bullet in
                            Text(bullet.title).tag(bullet.id)
                        }
                    }
                    Picker("Drag model", selection: dragBinding) {
                        ForEach(DragModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    Picker("Muzzle velocity", selection: velocityBinding) {
                        ForEach(velocityChoices, id: \.self) { speed in
                            Text(LoadCatalog.velocity(speed, metric: store.useMetric)).tag(speed)
                        }
                    }
                    Picker("Twist", selection: twistBinding) {
                        ForEach(twistChoices, id: \.self) { twist in
                            Text(LoadCatalog.twist(twist, metric: store.useMetric)).tag(twist)
                        }
                    }
                }
                detailRow("Diameter", LoadCatalog.length(profile.diameterInches, metric: store.useMetric))
                detailRow("Weight", LoadCatalog.weight(profile.bulletWeightGrains, metric: store.useMetric))
                detailRow("Length", LoadCatalog.length(profile.lengthInches, metric: store.useMetric))
                detailRow("Ballistic coefficient", String(format: "%.3f %@", profile.ballisticCoefficient, profile.dragModel.title))
                if entryMode == .preset {
                    detailRow("Muzzle velocity", LoadCatalog.velocity(profile.muzzleVelocityFps, metric: store.useMetric))
                    detailRow("Twist", LoadCatalog.twist(profile.twistInches, metric: store.useMetric))
                }
            } header: {
                SectionLabel("Bullet")
            } footer: {
                Text(entryMode == .preset
                    ? "A preset fills the bullet, velocity, and twist with typical published values. Check them against the ammunition box."
                    : "Pick a common caliber, bullet, velocity, and twist. Diameter, length, and ballistic coefficient follow that bullet. G7 is the match-bullet coefficient.")
            }
            .themedRows()

            Section {
                Picker("Sight height", selection: sightBinding) {
                    ForEach(sightChoices, id: \.self) { height in
                        Text(LoadCatalog.sightHeight(height, metric: store.useMetric)).tag(height)
                    }
                }
                Picker("Zero", selection: zeroBinding) {
                    ForEach(zeroChoices, id: \.self) { range in
                        Text(LoadCatalog.zero(range, metric: store.useMetric)).tag(range)
                    }
                }
            } header: {
                SectionLabel("Rifle")
            } footer: {
                Text("Sight height is the center of the scope above the bore. Zero is the range where the bullet crosses the line of sight.")
            }
            .themedRows()

            Section {
                Picker("Clicks", selection: clickUnitBinding) {
                    ForEach(ClickUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                NumericField(title: "Click value", value: clickValueBinding, unit: profile.clickUnit.title, decimals: 3)
                NumericField(title: "Travel per turn", value: travelPerTurnBinding, unit: profile.clickUnit.title, decimals: 2)
                NumericField(title: "Elevation travel", value: elevationTravelBinding, unit: profile.clickUnit.title, decimals: 1)
                NumericField(title: "Windage travel", value: windageTravelBinding, unit: profile.clickUnit.title, decimals: 1)
                NumericField(title: "Rail", value: railBinding, unit: "MOA", decimals: 0)
            } footer: {
                Text("Travel follows the turret unit. Quarter-minute scopes are usually 0.25 MOA and 25 MOA per turn. A 20 MOA rail frees that much extra elevation above the zero.")
            }
            .themedRows()

            Section {
                Picker("Reticle", selection: reticleUnitBinding) {
                    ForEach(ClickUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                Picker("Focal plane", selection: focalPlaneBinding) {
                    ForEach(FocalPlane.allCases) { plane in
                        Text(plane.title).tag(plane)
                    }
                }
                NumericField(title: "Hash spacing", value: hashBinding, unit: profile.reticleUnit.title, decimals: 2)
                if profile.focalPlane == .sfp {
                    NumericField(title: "Reticle true at", value: trueMagnificationBinding, unit: "×", decimals: 1)
                }
            } footer: {
                Text("The reticle can be MIL while the turret is MOA. First focal plane marks stay true at every power. Second focal plane marks are true only at the power you enter.")
            }
            .themedRows()
        }
        .themedForm()
        .navigationTitle(profile.name)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            guard !didChooseMode else { return }
            didChooseMode = true
            entryMode = LoadCatalog.preset(matching: profile.loadIdentity) == nil ? .build : .preset
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
        } label: {
            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { profile.name }, set: { profile.name = $0 })
    }

    private var dragBinding: Binding<DragModel> {
        Binding(
            get: { profile.dragModel },
            set: { model in
                let bullet = LoadCatalog.bullet(matching: profile.loadIdentity)
                profile.dragModel = model
                if let bullet {
                    profile.ballisticCoefficient = bullet.coefficient(model)
                }
                store.recompute()
            }
        )
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: { LoadCatalog.preset(matching: profile.loadIdentity)?.id ?? LoadCatalog.customID },
            set: { id in
                guard let preset = LoadCatalog.preset(id: id),
                      LoadCatalog.preset(matching: profile.loadIdentity)?.id != id else { return }
                apply(preset)
            }
        )
    }

    private var cartridgeBinding: Binding<String> {
        Binding(
            get: { LoadCatalog.cartridge(for: profile.loadIdentity)?.id ?? LoadCatalog.customID },
            set: { id in
                guard let cartridge = LoadCatalog.cartridge(id: id) else { return }
                let current = LoadCatalog.bullet(matching: profile.loadIdentity)
                let bullet = cartridge.bullets.first { $0.id == current?.id }
                    ?? cartridge.bullets.first { $0.id == cartridge.featuredBulletID }
                    ?? cartridge.bullets[0]
                apply(cartridge: cartridge, bullet: bullet)
            }
        )
    }

    private var bulletBinding: Binding<String> {
        Binding(
            get: { LoadCatalog.bullet(matching: profile.loadIdentity)?.id ?? LoadCatalog.customID },
            set: { id in
                guard let bullet = LoadCatalog.bullet(id: id) else { return }
                let cartridge = LoadCatalog.cartridge(id: cartridgeBinding.wrappedValue)
                    ?? LoadCatalog.cartridges.first { $0.bullets.contains { $0.id == bullet.id } }
                guard let cartridge else { return }
                apply(cartridge: cartridge, bullet: bullet)
            }
        )
    }

    private var bulletChoices: [CatalogBullet] {
        if let cartridge = LoadCatalog.cartridge(for: profile.loadIdentity) {
            return cartridge.bullets
        }
        return LoadCatalog.cartridge(id: "308")?.bullets ?? []
    }

    private var velocityChoices: [Double] {
        let options = LoadCatalog.cartridge(for: profile.loadIdentity)?.velocitiesFps
            ?? LoadCatalog.cartridge(id: "308")?.velocitiesFps
            ?? []
        return LoadCatalog.choices(options, including: profile.muzzleVelocityFps, tolerance: 1)
    }

    private var twistChoices: [Double] {
        let options = LoadCatalog.cartridge(for: profile.loadIdentity)?.twistsInches
            ?? LoadCatalog.cartridge(id: "308")?.twistsInches
            ?? []
        return LoadCatalog.choices(options, including: profile.twistInches, tolerance: 0.01)
    }

    private var sightChoices: [Double] {
        LoadCatalog.choices(LoadCatalog.sightHeightsInches, including: profile.sightHeightInches, tolerance: 0.01)
    }

    private var zeroChoices: [Double] {
        LoadCatalog.choices(LoadCatalog.zeroRangesYards, including: profile.zeroRangeYards, tolerance: 0.5)
    }

    private var clickUnitBinding: Binding<ClickUnit> {
        Binding(get: { profile.clickUnit }, set: { profile.clickUnit = $0; store.recompute() })
    }

    private var reticleUnitBinding: Binding<ClickUnit> {
        Binding(get: { profile.reticleUnit }, set: { profile.reticleUnit = $0; store.recompute() })
    }

    private var focalPlaneBinding: Binding<FocalPlane> {
        Binding(get: { profile.focalPlane }, set: { profile.focalPlane = $0; store.recompute() })
    }

    private var velocityBinding: Binding<Double> {
        Binding(get: { profile.muzzleVelocityFps }, set: { profile.muzzleVelocityFps = $0; store.recompute() })
    }

    private var twistBinding: Binding<Double> {
        Binding(get: { profile.twistInches }, set: { profile.twistInches = $0; store.recompute() })
    }

    private var sightBinding: Binding<Double> {
        Binding(get: { profile.sightHeightInches }, set: { profile.sightHeightInches = $0; store.recompute() })
    }

    private var zeroBinding: Binding<Double> {
        Binding(get: { profile.zeroRangeYards }, set: { profile.zeroRangeYards = $0; store.recompute() })
    }

    private var clickValueBinding: Binding<Double> {
        Binding(get: { profile.clickValue }, set: { profile.clickValue = $0; store.recompute() })
    }

    private var travelPerTurnBinding: Binding<Double> { turretAngle(\.travelPerTurnMOA) }
    private var elevationTravelBinding: Binding<Double> { turretAngle(\.elevationTravelMOA) }
    private var windageTravelBinding: Binding<Double> { turretAngle(\.windageTravelMOA) }

    private var railBinding: Binding<Double> {
        Binding(get: { profile.railCantMOA }, set: { profile.railCantMOA = $0; store.recompute() })
    }

    private var trueMagnificationBinding: Binding<Double> {
        Binding(get: { profile.reticleTrueMagnification }, set: { profile.reticleTrueMagnification = $0; store.recompute() })
    }

    private var hashBinding: Binding<Double> {
        Binding(
            get: { ScopeDial.hashSpacing(storedMIL: profile.hashSpacingMIL, unit: profile.reticleUnit) },
            set: {
                profile.hashSpacingMIL = ScopeDial.storedHashSpacingMIL(display: $0, unit: profile.reticleUnit)
                store.recompute()
            }
        )
    }

    private func turretAngle(_ keyPath: ReferenceWritableKeyPath<LoadProfile, Double>) -> Binding<Double> {
        Binding(
            get: { AngularScale.display(profile[keyPath: keyPath], unit: profile.clickUnit) },
            set: {
                profile[keyPath: keyPath] = AngularScale.moa(fromDisplay: $0, unit: profile.clickUnit)
                store.recompute()
            }
        )
    }

    private func apply(_ preset: CatalogPreset) {
        guard let cartridge = LoadCatalog.cartridge(id: preset.cartridgeID),
              let bullet = LoadCatalog.bullet(id: preset.bulletID) else { return }
        profile.name = preset.name
        profile.diameterInches = cartridge.diameterInches
        profile.bulletWeightGrains = bullet.weightGrains
        profile.lengthInches = bullet.lengthInches
        profile.dragModel = preset.dragModel
        profile.ballisticCoefficient = bullet.coefficient(preset.dragModel)
        profile.muzzleVelocityFps = preset.muzzleVelocityFps
        profile.twistInches = preset.twistInches
        profile.sightHeightInches = preset.sightHeightInches
        profile.zeroRangeYards = preset.zeroRangeYards
        store.recompute()
    }

    private func apply(cartridge: CatalogCartridge, bullet: CatalogBullet) {
        profile.diameterInches = cartridge.diameterInches
        profile.bulletWeightGrains = bullet.weightGrains
        profile.lengthInches = bullet.lengthInches
        profile.ballisticCoefficient = bullet.coefficient(profile.dragModel)
        if !cartridge.velocitiesFps.contains(where: { abs($0 - profile.muzzleVelocityFps) < 1 }) {
            profile.muzzleVelocityFps = nearest(cartridge.velocitiesFps, to: profile.muzzleVelocityFps)
        }
        if !cartridge.twistsInches.contains(where: { abs($0 - profile.twistInches) < 0.01 }) {
            profile.twistInches = nearest(cartridge.twistsInches, to: profile.twistInches)
        }
        store.recompute()
    }

    private func nearest(_ options: [Double], to value: Double) -> Double {
        options.min { abs($0 - value) < abs($1 - value) } ?? value
    }
}
