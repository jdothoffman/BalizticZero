import SwiftUI

/// The advisor's review of one recorded impact. The words come from the advisor;
/// the plot and every number come from the solver snapshot in `result`.
struct ShotReviewCard: View {
    let result: ShotReviewResult
    let unit: ClickUnit
    let metric: Bool

    private var review: ShotReview { result.review }
    private var verdictColor: Color { review.verdict.needsAttention ? Theme.caution : Theme.accent }

    var body: some View {
        Panel(title: "Shot review") {
            VStack(alignment: .leading, spacing: 18) {
                header
                Text(review.headline)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                measurements
                if !review.causes.isEmpty {
                    causes
                }
                nextShot
                if !review.caution.isEmpty {
                    Label(review.caution, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack {
            Label(review.verdict.title.uppercased(), systemImage: review.verdict.symbol)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(verdictColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(verdictColor.opacity(0.14), in: Capsule())
            Spacer()
            Text(result.reviewedAt, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var measurements: some View {
        HStack(alignment: .center, spacing: 16) {
            ImpactPlot(highMOA: result.impactHighMOA, rightMOA: result.impactRightMOA, unit: unit, dotColor: verdictColor)
                .frame(width: 124)
            VStack(alignment: .leading, spacing: 8) {
                fact("Miss", missText, detail: missAngleText)
                fact("Wind drift", lateral(result.windDriftInches))
                fact("Spin drift", lateral(result.spinDriftInches))
                if let share = result.windShare {
                    fact("Of the wind call", share.formatted(.percent.precision(.fractionLength(0))))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var causes: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Likely causes")
            ForEach(review.causes) { cause in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(cause.title)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(cause.likelihood.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LikelihoodBar(fill: cause.likelihood.fill, color: Theme.accent)
                    if !cause.note.isEmpty {
                        Text(cause.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var nextShot: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(verdictColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Next shot")
                Text(review.nextStep)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func fact(_ label: String, _ value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Formatting

    private var isOnCall: Bool {
        abs(result.impactHighMOA) < 0.005 && abs(result.impactRightMOA) < 0.005
    }

    private var missText: String {
        if isOnCall { return "On call" }
        return [lateral(result.missRightInches), vertical(result.missHighInches)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private var missAngleText: String? {
        if isOnCall { return nil }
        var parts: [String] = []
        if abs(result.impactRightMOA) >= 0.005 {
            parts.append(angle(result.impactRightMOA) + (result.impactRightMOA > 0 ? " R" : " L"))
        }
        if abs(result.impactHighMOA) >= 0.005 {
            parts.append(angle(result.impactHighMOA) + (result.impactHighMOA > 0 ? " H" : " L"))
        }
        return parts.joined(separator: " · ")
    }

    private func angle(_ moa: Double) -> String {
        String(format: "%.2f %@", AngularScale.display(abs(moa), unit: unit), unit.title)
    }

    private func lateral(_ inches: Double) -> String {
        let magnitude = DisplayFormat.drop(abs(inches), metric: metric)
        if abs(inches) < 0.05 { return magnitude }
        return inches > 0 ? "\(magnitude) right" : "\(magnitude) left"
    }

    private func vertical(_ inches: Double) -> String {
        if abs(inches) < 0.05 { return "" }
        let magnitude = DisplayFormat.drop(abs(inches), metric: metric)
        return inches > 0 ? "\(magnitude) high" : "\(magnitude) low"
    }
}

/// A short capsule bar. Its length is a word turned into a shape, not a probability.
private struct LikelihoodBar: View {
    let fill: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline)
                Capsule()
                    .fill(color.opacity(0.35 + 0.65 * fill))
                    .frame(width: max(6, proxy.size.width * fill))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// Point of aim at the centre, the recorded impact as a dot, with rings in the scope's unit.
struct ImpactPlot: View {
    let highMOA: Double
    let rightMOA: Double
    let unit: ClickUnit
    var dotColor: Color = Theme.accent

    var body: some View {
        let ring = Self.ringRadius(highMOA: highMOA, rightMOA: rightMOA, unit: unit)
        VStack(spacing: 6) {
            plot(ring: ring)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityElement()
                .accessibilityLabel("Impact plot")
                .accessibilityValue(accessibilityText)
            Text("Ring \(Self.ringLabel(ring, unit: unit))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityHidden(true)
        }
    }

    private func plot(ring: Double) -> some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side / 2 - 4
            let hairline = GraphicsContext.Shading.color(Theme.hairline)
            let faint = GraphicsContext.Shading.color(.secondary.opacity(0.6))

            for fraction in [1.0, 0.5] {
                let r = radius * fraction
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                               with: fraction == 1 ? .color(Theme.accent.opacity(0.28)) : hairline, lineWidth: 1)
            }
            var cross = Path()
            cross.move(to: CGPoint(x: center.x - radius, y: center.y))
            cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            cross.move(to: CGPoint(x: center.x, y: center.y - radius))
            cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
            context.stroke(cross, with: hairline, lineWidth: 1)

            var aim = Path()
            aim.move(to: CGPoint(x: center.x - 5, y: center.y))
            aim.addLine(to: CGPoint(x: center.x + 5, y: center.y))
            aim.move(to: CGPoint(x: center.x, y: center.y - 5))
            aim.addLine(to: CGPoint(x: center.x, y: center.y + 5))
            context.stroke(aim, with: faint, lineWidth: 1.5)

            let scale = radius / ring
            var dx = AngularScale.display(rightMOA, unit: unit) * scale
            var dy = -AngularScale.display(highMOA, unit: unit) * scale
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance > radius {
                dx *= radius / distance
                dy *= radius / distance
            }
            let impact = CGPoint(x: center.x + dx, y: center.y + dy)
            context.fill(Path(ellipseIn: CGRect(x: impact.x - 10, y: impact.y - 10, width: 20, height: 20)),
                         with: .color(dotColor.opacity(0.22)))
            context.fill(Path(ellipseIn: CGRect(x: impact.x - 5, y: impact.y - 5, width: 10, height: 10)),
                         with: .color(dotColor))
        }
    }

    private var accessibilityText: String {
        let right = AngularScale.display(rightMOA, unit: unit)
        let high = AngularScale.display(highMOA, unit: unit)
        if abs(right) < 0.005 && abs(high) < 0.005 { return "On the point of aim" }
        let horizontal = String(format: "%.2f %@ %@", abs(right), unit.title, right >= 0 ? "right" : "left")
        let verticalText = String(format: "%.2f %@ %@", abs(high), unit.title, high >= 0 ? "high" : "low")
        return "\(horizontal), \(verticalText) of the point of aim"
    }

    /// Outer ring in the display unit: the smallest tidy value that holds the impact with some room.
    static func ringRadius(highMOA: Double, rightMOA: Double, unit: ClickUnit) -> Double {
        let high = AngularScale.display(highMOA, unit: unit)
        let right = AngularScale.display(rightMOA, unit: unit)
        let needed = (high * high + right * right).squareRoot() * 1.2
        let steps: [Double] = unit == .mil
            ? [0.3, 0.5, 1, 2, 3, 5, 10]
            : [1, 2, 3, 5, 10, 20, 30]
        return steps.first { $0 >= needed } ?? steps[steps.count - 1]
    }

    static func ringLabel(_ value: Double, unit: ClickUnit) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)))
        return "\(number) \(unit.title)"
    }
}
