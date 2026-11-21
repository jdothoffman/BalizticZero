import SwiftUI

struct TrajectoryTableView: View {
    var store: CalculatorStore

    var body: some View {
        Group {
            if let rows = store.solution?.rows, !rows.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                line(row)
                                    .background(index.isMultiple(of: 2) ? Color.clear : Theme.surface)
                            }
                        } header: {
                            columnHeader
                        }
                    }
                    .padding(.bottom, 16)
                }
            } else {
                ContentUnavailableView(
                    "No trajectory",
                    systemImage: "list.number",
                    description: Text(store.statusMessage ?? "A firing solution will list every 100 yards.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Table")
    }

    private var unit: ClickUnit {
        store.selectedProfile?.clickUnit ?? .moa
    }

    private var columnHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                headerCell("Range", store.useMetric ? "m" : "yd", leading: true)
                headerCell("Elev", unit.title)
                headerCell("Wind", unit.title)
                headerCell("Vel", store.useMetric ? "m/s" : "fps")
                headerCell("TOF", "s")
                headerCell("Energy", store.useMetric ? "J" : "ft-lb")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
        .background(Theme.background)
    }

    private func headerCell(_ title: String, _ unit: String, leading: Bool = false) -> some View {
        VStack(alignment: leading ? .leading : .trailing, spacing: 1) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.0)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }

    private func line(_ row: TrajectoryRow) -> some View {
        let elevation = unit == .mil ? row.comeUpMIL : row.comeUpMOA
        let windage = unit == .mil ? row.windageMIL : row.windageMOA
        let range = store.useMetric ? UnitConverter.meters(fromYards: row.rangeYards) : row.rangeYards
        let velocity = store.useMetric ? UnitConverter.metersPerSecond(fromFps: row.velocityFps) : row.velocityFps
        let energy = store.useMetric ? UnitConverter.joules(fromFootPounds: row.energyFootPounds) : row.energyFootPounds

        return HStack(spacing: 4) {
            cell(UnitConverter.text(range, decimals: 0), leading: true)
                .foregroundStyle(.primary)
            cell(directional(elevation, positive: "U", negative: "D"))
            cell(directional(windage, positive: "R", negative: "L"))
            cell(UnitConverter.text(velocity, decimals: 0))
                .foregroundStyle(.secondary)
            cell(String(format: "%.2f", row.timeSeconds))
                .foregroundStyle(.secondary)
            cell(UnitConverter.text(energy, decimals: 0))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func cell(_ text: String, leading: Bool = false) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }

    /// Magnitude with a one-letter direction, so a column reads without signs.
    private func directional(_ value: Double, positive: String, negative: String) -> String {
        let magnitude = String(format: "%.2f", abs(value))
        if abs(value) < 0.005 { return magnitude + "  " }
        return magnitude + " " + (value > 0 ? positive : negative)
    }
}
