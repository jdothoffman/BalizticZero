import SwiftUI

struct TrajectoryTableView: View {
    var store: CalculatorStore

    var body: some View {
        Group {
            if let rows = store.solution?.rows, !rows.isEmpty {
                List(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DisplayFormat.distance(row.rangeYards, metric: store.useMetric))
                            .font(.headline)
                        Text(elevationLine(row))
                        Text(windLine(row))
                            .foregroundStyle(.secondary)
                        Text("\(DisplayFormat.speed(row.velocityFps, metric: store.useMetric))  ·  \(String(format: "%.2f s", row.timeSeconds))  ·  \(DisplayFormat.energy(row.energyFootPounds, metric: store.useMetric))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                ContentUnavailableView(
                    "No trajectory",
                    systemImage: "list.number",
                    description: Text(store.statusMessage ?? "A firing solution will list every 100 yards.")
                )
            }
        }
        .navigationTitle("Table")
    }

    private func elevationLine(_ row: TrajectoryRow) -> String {
        let direction = row.comeUpMOA >= 0 ? "up" : "down"
        return String(format: "%.2f MOA %@  ·  %.2f MIL  ·  %.0f clicks", abs(row.comeUpMOA), direction, abs(row.comeUpMIL), abs(row.elevationClicks))
    }

    private func windLine(_ row: TrajectoryRow) -> String {
        let direction = row.windageInches >= 0 ? "right" : "left"
        let linear = DisplayFormat.drop(abs(row.windageInches), metric: store.useMetric)
        return String(format: "%.2f MOA %@  ·  %@", abs(row.windageMOA), direction, linear)
    }
}
