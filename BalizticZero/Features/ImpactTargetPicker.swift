import SwiftUI

/// A reticle-style target. The shooter drags the crosshair to where they held and the dot
/// to where the round hit; the miss is the dot minus the crosshair. Tapping empty space
/// drops the hit there.
///
/// Only a drag that starts on a marker moves it. Any other drag belongs to the page, so the
/// screen still scrolls when a finger or the mouse lands on the target.
struct ImpactTargetPicker: View {
    @Binding var aim: AngularPoint
    @Binding var impact: AngularPoint
    let unit: ClickUnit
    /// True while a marker is being dragged. The parent turns scrolling off for that time.
    @Binding var isDraggingMarker: Bool

    @State private var zoom = 1
    /// Which marker the current touch grabbed, and where on it. Nil when the touch is the page's.
    @GestureState private var grab: Grab?

    enum Marker { case aim, impact }

    struct Grab: Equatable {
        var marker: Marker
        var offset: CGSize
    }

    /// How close to a marker a touch must start to pick it up.
    private static let reach: CGFloat = 36
    /// Movement below this is a tap.
    private static let tapSlop: CGFloat = 6

    private var dragging: Marker? { grab?.marker }

    /// Half-width of the field, the grid spacing and the snap step, all in the display unit.
    struct Scale: Equatable {
        var span: Double
        var grid: Double
        var snap: Double
    }

    static func scales(for unit: ClickUnit) -> [Scale] {
        switch unit {
        case .mil:
            [Scale(span: 0.5, grid: 0.1, snap: 0.05), Scale(span: 1, grid: 0.2, snap: 0.05),
             Scale(span: 2, grid: 0.5, snap: 0.1), Scale(span: 5, grid: 1, snap: 0.2)]
        case .moa:
            [Scale(span: 2, grid: 0.5, snap: 0.25), Scale(span: 4, grid: 1, snap: 0.25),
             Scale(span: 8, grid: 2, snap: 0.5), Scale(span: 16, grid: 4, snap: 1)]
        }
    }

    private var scales: [Scale] { Self.scales(for: unit) }
    private var scale: Scale { scales[min(max(zoom, 0), scales.count - 1)] }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let field = Field(size: proxy.size, span: scale.span)
                Canvas { context, _ in
                    draw(in: &context, field: field)
                }
                .contentShape(Rectangle())
                // Simultaneous, so the scroll view still sees every touch. A grab turns
                // scrolling off through isDraggingMarker before the page starts to move.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($grab) { value, state, _ in
                            if state == nil {
                                state = grabbed(at: value.startLocation, field: field)
                            }
                        }
                        .onChanged { value in drag(value, field: field) }
                        .onEnded { value in endDrag(value, field: field) }
                )
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement()
            .accessibilityLabel("Impact target")
            .accessibilityValue(accessibilityText)
            .accessibilityHint("Drag the crosshair to where you held and the dot to where the round hit. Or use Type the miss instead.")

            HStack(spacing: 12) {
                Picker("Zoom", selection: $zoom) {
                    ForEach(Array(scales.enumerated()), id: \.offset) { index, scale in
                        Text("±" + scale.span.formatted(.number.precision(.fractionLength(0...1)))).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                Button("Reset") {
                    aim = AngularPoint()
                    impact = AngularPoint()
                }
                .font(.subheadline)
                .disabled(aim == AngularPoint() && impact == AngularPoint())
            }
        }
        .sensoryFeedback(.selection, trigger: impact)
        .sensoryFeedback(.selection, trigger: aim)
        .onChange(of: grab != nil) { _, grabbing in
            isDraggingMarker = grabbing
        }
    }

    // MARK: - Gesture

    /// The marker under the start of a touch, if any. The dot wins when both are close.
    private func grabbed(at start: CGPoint, field: Field) -> Grab? {
        let aimSpot = field.clampedPoint(display(aim))
        let impactSpot = field.clampedPoint(display(impact))
        let toAim = distance(start, aimSpot)
        let toImpact = distance(start, impactSpot)
        if toImpact <= Self.reach, toImpact <= toAim {
            return Grab(marker: .impact, offset: CGSize(width: impactSpot.x - start.x, height: impactSpot.y - start.y))
        }
        if toAim <= Self.reach {
            return Grab(marker: .aim, offset: CGSize(width: aimSpot.x - start.x, height: aimSpot.y - start.y))
        }
        return nil
    }

    private func drag(_ value: DragGesture.Value, field: Field) {
        guard let grab else { return }
        let location = CGPoint(x: value.location.x + grab.offset.width, y: value.location.y + grab.offset.height)
        place(grab.marker, at: location, field: field)
    }

    /// A tap on empty target drops the hit there. A drag that was not on a marker did nothing here.
    private func endDrag(_ value: DragGesture.Value, field: Field) {
        let moved = hypot(value.translation.width, value.translation.height)
        guard moved < Self.tapSlop, grabbed(at: value.startLocation, field: field) == nil else { return }
        place(.impact, at: value.location, field: field)
    }

    private func place(_ marker: Marker, at location: CGPoint, field: Field) {
        let spot = Self.snapped(field.angle(location), step: scale.snap, span: scale.span)
        let moa = AngularPoint(
            rightMOA: AngularScale.moa(fromDisplay: spot.x, unit: unit),
            highMOA: AngularScale.moa(fromDisplay: spot.y, unit: unit)
        )
        switch marker {
        case .aim: if aim != moa { aim = moa }
        case .impact: if impact != moa { impact = moa }
        }
    }

    /// Rounds to the snap step and keeps the spot on the field.
    static func snapped(_ spot: CGPoint, step: Double, span: Double) -> CGPoint {
        func one(_ value: Double) -> Double {
            let clamped = min(max(value, -span), span)
            let rounded = (clamped / step).rounded() * step
            return abs(rounded) < step / 2 ? 0 : rounded
        }
        return CGPoint(x: one(spot.x), y: one(spot.y))
    }

    private func display(_ point: AngularPoint) -> CGPoint {
        CGPoint(x: AngularScale.display(point.rightMOA, unit: unit), y: AngularScale.display(point.highMOA, unit: unit))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, field: Field) {
        let center = field.center
        let radius = field.radius
        let rings = Int((scale.span / scale.grid).rounded())

        context.fill(Path(ellipseIn: field.rect(radius: radius)), with: .color(.black))
        for ring in 1...max(rings, 1) {
            let r = radius * CGFloat(Double(ring) * scale.grid / scale.span)
            let strong = ring == rings || ring % 2 == 0
            context.stroke(Path(ellipseIn: field.rect(radius: r)),
                           with: .color(Theme.accent.opacity(strong ? 0.22 : 0.1)), lineWidth: 1)
        }

        var axes = Path()
        axes.move(to: CGPoint(x: center.x - radius, y: center.y))
        axes.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        axes.move(to: CGPoint(x: center.x, y: center.y - radius))
        axes.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        context.stroke(axes, with: .color(Theme.accent.opacity(0.3)), lineWidth: 1)

        // Hash marks every snap step, longer on the grid lines, like a reticle.
        let steps = Int((scale.span / scale.snap).rounded())
        var hashes = Path()
        for step in 1...max(steps, 1) {
            let value = Double(step) * scale.snap
            let onGrid = abs((value / scale.grid).rounded() * scale.grid - value) < 1e-9
            let length: CGFloat = onGrid ? 6 : 3
            let offset = radius * CGFloat(value / scale.span)
            for sign in [-1.0, 1.0] {
                let d = offset * CGFloat(sign)
                hashes.move(to: CGPoint(x: center.x + d, y: center.y - length))
                hashes.addLine(to: CGPoint(x: center.x + d, y: center.y + length))
                hashes.move(to: CGPoint(x: center.x - length, y: center.y + d))
                hashes.addLine(to: CGPoint(x: center.x + length, y: center.y + d))
            }
        }
        context.stroke(hashes, with: .color(Theme.accent.opacity(0.45)), lineWidth: 1)

        let labelEvery = rings > 5 ? 2 : 1
        for ring in stride(from: labelEvery, through: rings, by: labelEvery) {
            let value = Double(ring) * scale.grid
            let x = center.x + radius * CGFloat(value / scale.span)
            context.draw(
                Text(value.formatted(.number.precision(.fractionLength(0...2))))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(Color.secondary),
                at: CGPoint(x: x - 2, y: center.y + 8), anchor: .topTrailing
            )
        }
        context.draw(
            Text(unit.title).font(.caption2.weight(.semibold)).foregroundStyle(Color.secondary),
            at: CGPoint(x: field.size.width - 2, y: 2), anchor: .topTrailing
        )

        let aimSpot = field.clampedPoint(display(aim))
        let impactSpot = field.clampedPoint(display(impact))

        if distance(aimSpot, impactSpot) > 4 {
            var miss = Path()
            miss.move(to: aimSpot)
            miss.addLine(to: impactSpot)
            context.stroke(miss, with: .color(Theme.accent.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }

        // Aim: an open crosshair.
        var aimMark = Path()
        aimMark.addEllipse(in: CGRect(x: aimSpot.x - 11, y: aimSpot.y - 11, width: 22, height: 22))
        for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
            aimMark.move(to: CGPoint(x: aimSpot.x + 5 * dx, y: aimSpot.y + 5 * dy))
            aimMark.addLine(to: CGPoint(x: aimSpot.x + 16 * dx, y: aimSpot.y + 16 * dy))
        }
        context.stroke(aimMark, with: .color(.white.opacity(dragging == .aim ? 1 : 0.85)), lineWidth: dragging == .aim ? 2 : 1.5)
        let aimLabel = Self.labelPlacement(for: aimSpot, awayFrom: impactSpot, gap: 14)
        context.draw(
            Text("AIM").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.white.opacity(0.75)),
            at: aimLabel.point, anchor: aimLabel.anchor
        )

        // Impact: a filled dot with a halo.
        let halo: CGFloat = dragging == .impact ? 18 : 13
        context.fill(Path(ellipseIn: CGRect(x: impactSpot.x - halo, y: impactSpot.y - halo, width: halo * 2, height: halo * 2)),
                     with: .color(Theme.accent.opacity(0.25)))
        let dot = Path(ellipseIn: CGRect(x: impactSpot.x - 7, y: impactSpot.y - 7, width: 14, height: 14))
        context.fill(dot, with: .color(Theme.accent))
        context.stroke(dot, with: .color(.black.opacity(0.6)), lineWidth: 1)
        let hitLabel = Self.labelPlacement(for: impactSpot, awayFrom: aimSpot, gap: 13)
        context.draw(
            Text("HIT").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent),
            at: hitLabel.point, anchor: hitLabel.anchor
        )
    }

    /// Puts a marker's label on the diagonal facing away from the other marker, so it never sits on the miss line.
    static func labelPlacement(for spot: CGPoint, awayFrom other: CGPoint, gap: CGFloat) -> (point: CGPoint, anchor: UnitPoint) {
        let right = spot.x >= other.x
        let below = spot.y > other.y
        let point = CGPoint(x: spot.x + (right ? gap : -gap), y: spot.y + (below ? gap : -gap))
        let anchor: UnitPoint = switch (right, below) {
        case (true, true): .topLeading
        case (true, false): .bottomLeading
        case (false, true): .topTrailing
        case (false, false): .bottomTrailing
        }
        return (point, anchor)
    }

    private var accessibilityText: String {
        let right = AngularScale.display(impact.rightMOA - aim.rightMOA, unit: unit)
        let high = AngularScale.display(impact.highMOA - aim.highMOA, unit: unit)
        if abs(right) < 0.005 && abs(high) < 0.005 { return "Hit on the point of aim" }
        let horizontal = String(format: "%.2f %@ %@", abs(right), unit.title, right >= 0 ? "right" : "left")
        let vertical = String(format: "%.2f %@ %@", abs(high), unit.title, high >= 0 ? "high" : "low")
        return "Hit \(horizontal), \(vertical) of the point of aim"
    }
}

/// Maps between angles in the display unit and points on the drawn field.
private struct Field {
    let size: CGSize
    let span: Double

    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
    /// Leaves room at the edge for the markers and labels.
    var radius: CGFloat { min(size.width, size.height) / 2 - 14 }

    func point(_ angle: CGPoint) -> CGPoint {
        CGPoint(x: center.x + radius * angle.x / span, y: center.y - radius * angle.y / span)
    }

    /// A point that stays on the field when a marker lies outside the current zoom.
    func clampedPoint(_ angle: CGPoint) -> CGPoint {
        point(CGPoint(x: min(max(angle.x, -span), span), y: min(max(angle.y, -span), span)))
    }

    func angle(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - center.x) / radius * span, y: -(point.y - center.y) / radius * span)
    }

    func rect(radius r: CGFloat) -> CGRect {
        CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
    }
}
