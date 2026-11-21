import SwiftUI

struct SolutionView: View {
    @Bindable var store: CalculatorStore

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
                } else {
                    ContentUnavailableView(
                        "No solution",
                        systemImage: "target",
                        description: Text(store.statusMessage ?? "Check the load and the range.")
                    )
                    .padding(.top, 60)
                }

                if store.advisor.isAvailable {
                    Button("Ask AI") {
                        Task { _ = await store.advisor.explain(solution: store.solution ?? emptySolution) }
                    }
                }

                Text("Estimate only. Confirm with live fire.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
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
            : String(format: "%.2f MIL", abs(mil))

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
            ("Zero angle", String(format: "%.2f MOA", solution.zeroAngleMOA)),
        ]
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

    private var emptySolution: FiringSolution {
        let row = TrajectoryRow(
            rangeYards: 0, pathInches: 0, comeUpMOA: 0, comeUpMIL: 0,
            windageInches: 0, windageMOA: 0, windageMIL: 0,
            velocityFps: 0, energyFootPounds: 0, timeSeconds: 0,
            elevationClicks: 0, windageClicks: 0
        )
        return FiringSolution(
            rows: [], target: row, zeroAngleMOA: 0, densityRatio: 0,
            densityAltitudeFeet: 0, speedOfSoundFps: 0, spinDriftInches: 0,
            coriolisHorizontalInches: 0, coriolisVerticalInches: 0,
            aerodynamicWindageInches: 0
        )
    }
}
