import SwiftUI

struct SolutionView: View {
    @Bindable var store: CalculatorStore
    /// Scrolling pauses while a marker on the impact target is being dragged.
    @State private var isDraggingMarker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let solution = store.solution {
                    header(solution)
                    Panel {
                        correction(
                            label: "Elevation",
                            direction: solution.target.comeUpMOA >= 0 ? "UP" : "DOWN",
                            moa: solution.target.comeUpMOA,
                            mil: solution.target.comeUpMIL
                        )
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 1)
                        correction(
                            label: "Windage",
                            direction: solution.target.windageMOA >= 0 ? "RIGHT" : "LEFT",
                            moa: solution.target.windageMOA,
                            mil: solution.target.windageMIL
                        )
                    }
                    if let profile = store.selectedProfile {
                        DataPanel(title: "On the reticle", rows: reticleRows(solution, profile: profile))
                    }
                    DataPanel(title: "At target", rows: flightFacts(solution.target))
                    DataPanel(title: "What moved the impact", rows: breakdown(solution))
                    afterShot
                    if store.isReviewingShot {
                        reviewingPlaceholder
                    } else if let result = store.shotReview {
                        ShotReviewCard(result: result, unit: leadUnit, metric: store.useMetric)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                } else {
                    ContentUnavailableView(
                        "No solution",
                        systemImage: "target",
                        description: Text(store.statusMessage ?? "Check the load and the range.")
                    )
                    .padding(.top, 60)
                }

                Text("Estimate only. Confirm with live fire.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .animation(.easeOut(duration: 0.25), value: store.isReviewingShot)
        }
        .scrollDisabled(isDraggingMarker)
        .background(Theme.background)
        .navigationTitle("Solution")
    }

    /// The scope's own unit leads, so the big number is the one you dial.
    private var leadUnit: ClickUnit {
        store.selectedProfile?.clickUnit ?? .moa
    }

    private func header(_ solution: FiringSolution) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel("Target")
                Text(DisplayFormat.distance(solution.target.rangeYards, metric: store.useMetric))
                    .font(.title2.weight(.semibold).monospacedDigit())
            }
            Spacer()
            if let profile = store.selectedProfile {
                VStack(alignment: .trailing, spacing: 2) {
                    SectionLabel("Load")
                    Text(profile.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func correction(label: String, direction: String, moa: Double, mil: Double) -> some View {
        let lead = leadUnit == .mil ? mil : moa
        let other = leadUnit == .mil
            ? String(format: "%.2f MOA", abs(moa))
            : String(format: "%.2f %@", abs(mil), ClickUnit.mil.title)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(label)
                Spacer()
                Text(direction)
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.2f", abs(lead)))
                    .font(.system(size: 60, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(leadUnit.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text("\(other)  ·  \(dialLine(moa: moa))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if let warning = travelWarning(moa: moa, label: label) {
                Text(warning)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(16)
    }

    private func dialLine(moa: Double) -> String {
        guard let profile = store.selectedProfile else { return "—" }
        let dial = ScopeDial.instruction(
            angleMOA: moa,
            clickUnit: profile.clickUnit,
            clickValue: profile.clickValue,
            travelPerTurnMOA: profile.travelPerTurnMOA
        )
        return dial.summary
    }

    private func travelWarning(moa: Double, label: String) -> String? {
        guard let profile = store.selectedProfile, let solution = store.solution else { return nil }
        let limit: TravelLimit?
        let noun: String
        if label == "Elevation" {
            limit = ScopeDial.elevationLimit(
                comeUpMOA: moa,
                zeroAngleMOA: solution.zeroAngleMOA,
                elevationTravelMOA: profile.elevationTravelMOA,
                railCantMOA: profile.railCantMOA,
                clickUnit: profile.clickUnit
            )
            noun = "elevation"
        } else {
            limit = ScopeDial.windageLimit(
                windageMOA: moa,
                windageTravelMOA: profile.windageTravelMOA,
                clickUnit: profile.clickUnit
            )
            noun = "windage"
        }
        guard let limit, limit.isOver else { return nil }
        return String(format: "Past %@ travel by %.1f %@", noun, limit.overBy, profile.clickUnit.title)
    }

    private func reticleRows(_ solution: FiringSolution, profile: LoadProfile) -> [(label: String, value: String)] {
        let load = profile.ballisticLoad
        let elevation = ScopeDial.indicatedHold(
            angleMOA: solution.target.comeUpMOA,
            reticleUnit: load.reticleUnit,
            focalPlane: load.focalPlane,
            trueMagnification: load.reticleTrueMagnification,
            currentMagnification: store.magnification
        )
        let windage = ScopeDial.indicatedHold(
            angleMOA: solution.target.windageMOA,
            reticleUnit: load.reticleUnit,
            focalPlane: load.focalPlane,
            trueMagnification: load.reticleTrueMagnification,
            currentMagnification: store.magnification
        )
        let unit = load.reticleUnit.title
        let elevationWord = solution.target.comeUpMOA >= 0 ? "up" : "down"
        let windageWord = solution.target.windageMOA >= 0 ? "right" : "left"
        var rows = [
            ("Elevation", String(format: "%.2f %@ %@", elevation, unit, elevationWord)),
            ("Windage", String(format: "%.2f %@ %@", windage, unit, windageWord)),
        ]
        let spacing = ScopeDial.hashSpacing(storedMIL: load.hashSpacingMIL, unit: load.reticleUnit)
        if let hashes = ScopeDial.hashCount(indicated: elevation, hashSpacing: spacing) {
            rows.append(("Elevation hashes", String(format: "%.1f %@", hashes, elevationWord)))
        }
        if let hashes = ScopeDial.hashCount(indicated: windage, hashSpacing: spacing) {
            rows.append(("Windage hashes", String(format: "%.1f %@", hashes, windageWord)))
        }
        if load.focalPlane == .sfp {
            let trueElevation = abs(AngularScale.display(solution.target.comeUpMOA, unit: load.reticleUnit))
            rows.append(("True elevation", String(format: "%.2f %@ at %g×", trueElevation, unit, load.reticleTrueMagnification)))
        }
        return rows
    }

    private func flightFacts(_ row: TrajectoryRow) -> [(label: String, value: String)] {
        [
            ("Path", DisplayFormat.drop(row.pathInches, metric: store.useMetric)),
            ("Windage", DisplayFormat.drop(row.windageInches, metric: store.useMetric)),
            ("Time of flight", String(format: "%.3f s", row.timeSeconds)),
            ("Velocity", DisplayFormat.speed(row.velocityFps, metric: store.useMetric)),
            ("Energy", DisplayFormat.energy(row.energyFootPounds, metric: store.useMetric)),
        ]
    }

    private func breakdown(_ solution: FiringSolution) -> [(label: String, value: String)] {
        [
            ("Wind drift", lateral(solution.aerodynamicWindageInches)),
            ("Spin drift", lateral(solution.spinDriftInches)),
            ("Coriolis, horizontal", lateral(solution.coriolisHorizontalInches)),
            ("Coriolis, vertical", vertical(solution.coriolisVerticalInches)),
            ("Zero angle", String(format: "%.2f %@", AngularScale.display(solution.zeroAngleMOA, unit: leadUnit), leadUnit.title)),
        ]
    }

    private var afterShot: some View {
        Panel(title: "After the shot") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fire the dialed correction. Drag the crosshair to where you held and the dot to where the round hit, or tap where it hit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ImpactTargetPicker(aim: $store.aimPoint, impact: $store.impactPoint, unit: leadUnit, isDraggingMarker: $isDraggingMarker)
                missReadout
                DisclosureGroup("Type the miss instead") {
                    VStack(alignment: .leading, spacing: 10) {
                        missField("Elevation", value: impactHighBinding)
                        missField("Windage", value: impactRightBinding)
                        Text("Positive elevation is high. Positive windage is right.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline)
                .tint(Theme.accent)
                Button {
                    Task { await store.reviewShot() }
                } label: {
                    if store.isReviewingShot {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Review this shot")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(store.isReviewingShot)
                if let message = store.shotReviewError {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.caution)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup("Advisor server") {
                    TextField("https://your-server", text: $store.advisorURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    SecureField("Development token", text: $store.advisorToken)
                }
                .font(.subheadline)
                .tint(Theme.accent)
                Text("The address and development token identify this app to your server. The Anthropic key stays there.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    /// The miss in the scope's unit, and in inches or centimetres at the target.
    private var missReadout: some View {
        let high = store.impactHighMOA
        let right = store.impactRightMOA
        let onCall = abs(high) < 0.005 && abs(right) < 0.005
        let range = store.solution?.target.rangeYards ?? store.rangeYards
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Miss")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(onCall ? "On the point of aim" : angularMiss(high: high, right: right))
                    .monospacedDigit()
            }
            .font(.subheadline)
            if !onCall {
                Text(linearMiss(high: high, right: right, rangeYards: range))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func angularMiss(high: Double, right: Double) -> String {
        var parts: [String] = []
        if abs(right) >= 0.005 {
            parts.append(String(format: "%.2f %@ %@", AngularScale.display(abs(right), unit: leadUnit), leadUnit.title, right > 0 ? "right" : "left"))
        }
        if abs(high) >= 0.005 {
            parts.append(String(format: "%.2f %@ %@", AngularScale.display(abs(high), unit: leadUnit), leadUnit.title, high > 0 ? "high" : "low"))
        }
        return parts.joined(separator: " · ")
    }

    private func linearMiss(high: Double, right: Double, rangeYards: Double) -> String {
        var parts: [String] = []
        let rightInches = AngularScale.inches(fromMOA: right, atYards: rangeYards)
        let highInches = AngularScale.inches(fromMOA: high, atYards: rangeYards)
        if abs(right) >= 0.005 {
            parts.append(DisplayFormat.drop(abs(rightInches), metric: store.useMetric) + (right > 0 ? " right" : " left"))
        }
        if abs(high) >= 0.005 {
            parts.append(DisplayFormat.drop(abs(highInches), metric: store.useMetric) + (high > 0 ? " high" : " low"))
        }
        return parts.joined(separator: ", ") + " at " + DisplayFormat.distance(rangeYards, metric: store.useMetric)
    }

    private var reviewingPlaceholder: some View {
        Panel(title: "Shot review") {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviewing the shot")
                        .font(.subheadline)
                    Text("This can take up to 45 seconds.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private var impactHighBinding: Binding<Double> {
        Binding(
            get: { AngularScale.display(store.impactHighMOA, unit: leadUnit) },
            set: { store.impactHighMOA = AngularScale.moa(fromDisplay: $0, unit: leadUnit) }
        )
    }

    private var impactRightBinding: Binding<Double> {
        Binding(
            get: { AngularScale.display(store.impactRightMOA, unit: leadUnit) },
            set: { store.impactRightMOA = AngularScale.moa(fromDisplay: $0, unit: leadUnit) }
        )
    }

    private func missField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(title, value: value, format: .number.precision(.fractionLength(0...2)).sign(strategy: .automatic))
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text(leadUnit.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 36, alignment: .leading)
            }
        } label: {
            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    private func lateral(_ inches: Double) -> String {
        let magnitude = DisplayFormat.drop(abs(inches), metric: store.useMetric)
        if abs(inches) < 0.05 { return magnitude }
        return inches > 0 ? "\(magnitude) right" : "\(magnitude) left"
    }

    private func vertical(_ inches: Double) -> String {
        let magnitude = DisplayFormat.drop(abs(inches), metric: store.useMetric)
        if abs(inches) < 0.05 { return magnitude }
        return inches > 0 ? "\(magnitude) up" : "\(magnitude) down"
    }
}
