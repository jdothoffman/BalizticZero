import SwiftUI

struct SolutionView: View {
    @Bindable var store: CalculatorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let solution = store.solution {
                    Text(DisplayFormat.distance(solution.target.rangeYards, metric: store.useMetric))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    correctionBlock(
                        title: verticalWord(solution.target.comeUpMOA),
                        moa: solution.target.comeUpMOA,
                        mil: solution.target.comeUpMIL,
                        clicks: solution.target.elevationClicks,
                        direction: solution.target.comeUpMOA >= 0 ? "up" : "down"
                    )
                    correctionBlock(
                        title: solution.target.windageMOA >= 0 ? "RIGHT" : "LEFT",
                        moa: solution.target.windageMOA,
                        mil: solution.target.windageMIL,
                        clicks: solution.target.windageClicks,
                        direction: solution.target.windageMOA >= 0 ? "right" : "left"
                    )
                    flightFacts(solution.target)
                    breakdown(solution)
                } else {
                    ContentUnavailableView(
                        "No solution",
                        systemImage: "target",
                        description: Text(store.statusMessage ?? "Check the load and the range.")
                    )
                }

                Button("Ask AI") {
                    Task { _ = await store.advisor.explain(solution: store.solution ?? emptySolution) }
                }
                .disabled(!store.advisor.isAvailable)
                Text("Not available yet. The advisor seam is ready for a later model.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Estimate only. Confirm with live fire.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Solution")
    }

    private func correctionBlock(title: String, moa: Double, mil: Double, clicks: Double, direction: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f MOA", abs(moa)))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
            Text(String(format: "%.2f MIL  ·  %.1f clicks %@", abs(mil), abs(clicks), direction))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func flightFacts(_ row: TrajectoryRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            labeled("Path", DisplayFormat.drop(row.pathInches, metric: store.useMetric))
            labeled("Windage", DisplayFormat.drop(row.windageInches, metric: store.useMetric))
            labeled("Time", String(format: "%.3f s", row.timeSeconds))
            labeled("Velocity", DisplayFormat.speed(row.velocityFps, metric: store.useMetric))
            labeled("Energy", DisplayFormat.energy(row.energyFootPounds, metric: store.useMetric))
        }
        .padding(.top, 4)
    }

    private func breakdown(_ solution: FiringSolution) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What moved the impact")
                .font(.headline)
                .padding(.top, 8)
            labeled("Wind drift", lateral(solution.aerodynamicWindageInches))
            labeled("Spin drift", lateral(solution.spinDriftInches))
            labeled("Coriolis, horizontal", lateral(solution.coriolisHorizontalInches))
            labeled("Coriolis, vertical", vertical(solution.coriolisVerticalInches))
            labeled("Zero angle", String(format: "%.2f MOA", solution.zeroAngleMOA))
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
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

    private func verticalWord(_ moa: Double) -> String {
        moa >= 0 ? "UP" : "DOWN"
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
