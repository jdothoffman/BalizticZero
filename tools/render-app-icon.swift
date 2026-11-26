// Renders BalizticZero/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024x1024, opaque).
// Usage: swiftc -O tools/render-app-icon.swift -o /tmp/render-app-icon && /tmp/render-app-icon BalizticZero/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Baliztic Zero app icon: a rose gold scope reticle on black. The outer ring doubles as the "zero".
// A glowing hold point sits on the elevation ladder below center: the dialed come-up.

let size = 1024
let s = CGFloat(size)
let c = CGPoint(x: s / 2, y: s / 2)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: a
    )
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
// No alpha channel: App Store icons must be opaque.
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

// Core Graphics puts the origin bottom-left. Flip so y grows downward like a screen.
ctx.translateBy(x: 0, y: s)
ctx.scaleBy(x: 1, y: -1)

// Rose gold metal: highlight, body, shadow, a second glint, and deep shadow.
let metal = CGGradient(
    colorsSpace: space,
    colors: [
        rgb(0xFBE3D6), rgb(0xE8B3A0), rgb(0xC9836F), rgb(0x9E5E4E),
        rgb(0xF3CDBD), rgb(0xD69884), rgb(0x8A4C3F),
    ] as CFArray,
    locations: [0, 0.18, 0.38, 0.52, 0.66, 0.82, 1]
)!

func fillMetal(_ path: CGPath, from: CGPoint = CGPoint(x: 140, y: 120), to: CGPoint = CGPoint(x: 900, y: 920)) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip(using: .evenOdd)
    ctx.drawLinearGradient(metal, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func glow(_ color: CGColor, blur: CGFloat, _ draw: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: blur, color: color)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    draw()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

// 1. Background: near-black with a faint warm center, falling to pure black at the edges.
ctx.setFillColor(rgb(0x000000))
ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
let backdrop = CGGradient(
    colorsSpace: space,
    colors: [rgb(0x2A1A1A), rgb(0x120B0C), rgb(0x000000)] as CFArray,
    locations: [0, 0.45, 1]
)!
ctx.drawRadialGradient(backdrop, startCenter: c, startRadius: 0, endCenter: c, endRadius: 620, options: [])

// 2. Faint field-of-view disc inside the ring, slightly lifted so the glass reads.
let lens = CGGradient(
    colorsSpace: space,
    colors: [rgb(0x3A2424, 0.55), rgb(0x1A1011, 0.2), rgb(0x000000, 0)] as CFArray,
    locations: [0, 0.7, 1]
)!
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: c.x - 330, y: c.y - 330, width: 660, height: 660))
ctx.clip()
ctx.drawRadialGradient(lens, startCenter: CGPoint(x: c.x - 90, y: c.y - 110), startRadius: 0, endCenter: c, endRadius: 360, options: [])
ctx.restoreGState()

// 3. The zero: a heavy metal ring with a soft rose glow behind it.
let ringOuter: CGFloat = 392
let ringInner: CGFloat = 338
let ring = CGMutablePath()
ring.addEllipse(in: CGRect(x: c.x - ringOuter, y: c.y - ringOuter, width: ringOuter * 2, height: ringOuter * 2))
ring.addEllipse(in: CGRect(x: c.x - ringInner, y: c.y - ringInner, width: ringInner * 2, height: ringInner * 2))
glow(rgb(0xE0A795, 0.45), blur: 46) {
    fillMetal(ring)
}
// Machined edges: a bright lip on the outside, a dark groove on the inside.
ctx.setLineWidth(3)
ctx.setStrokeColor(rgb(0xFFE9DD, 0.55))
ctx.strokeEllipse(in: CGRect(x: c.x - ringOuter + 1.5, y: c.y - ringOuter + 1.5, width: ringOuter * 2 - 3, height: ringOuter * 2 - 3))
ctx.setStrokeColor(rgb(0x3B1F1A, 0.8))
ctx.strokeEllipse(in: CGRect(x: c.x - ringInner - 1.5, y: c.y - ringInner - 1.5, width: ringInner * 2 + 3, height: ringInner * 2 + 3))

// Turret-style knurling: short ticks around the outside of the ring at every 10 degrees, longer every 30.
ctx.saveGState()
ctx.setLineCap(.round)
for step in 0..<36 {
    let angle = CGFloat(step) * .pi / 18
    let major = step % 3 == 0
    let r0 = ringInner + 10
    let r1 = ringInner + (major ? 30 : 20)
    ctx.setLineWidth(major ? 5 : 3)
    ctx.setStrokeColor(rgb(0x5A3029, major ? 0.75 : 0.5))
    ctx.move(to: CGPoint(x: c.x + cos(angle) * r0, y: c.y + sin(angle) * r0))
    ctx.addLine(to: CGPoint(x: c.x + cos(angle) * r1, y: c.y + sin(angle) * r1))
    ctx.strokePath()
}
ctx.restoreGState()

// 4. Reticle: thick posts from the ring inward, thin crosshair to a gap at center.
let postInner: CGFloat = 210
let postWidth: CGFloat = 26
let thinWidth: CGFloat = 7
let centerGap: CGFloat = 34

let posts = CGMutablePath()
// Top, bottom, left, right posts. They start just under the ring so they read as one machined piece.
let postReach = ringInner + 4
posts.addRect(CGRect(x: c.x - postWidth / 2, y: c.y - postReach, width: postWidth, height: postReach - postInner))
posts.addRect(CGRect(x: c.x - postWidth / 2, y: c.y + postInner, width: postWidth, height: postReach - postInner))
posts.addRect(CGRect(x: c.x - postReach, y: c.y - postWidth / 2, width: postReach - postInner, height: postWidth))
posts.addRect(CGRect(x: c.x + postInner, y: c.y - postWidth / 2, width: postReach - postInner, height: postWidth))
// Tapered tips where the posts meet the thin wire.
func taper(_ tip: CGPoint, _ base: CGPoint, horizontal: Bool) {
    let half = postWidth / 2
    posts.move(to: horizontal ? CGPoint(x: base.x, y: base.y - half) : CGPoint(x: base.x - half, y: base.y))
    posts.addLine(to: horizontal ? CGPoint(x: tip.x, y: tip.y - thinWidth / 2) : CGPoint(x: tip.x - thinWidth / 2, y: tip.y))
    posts.addLine(to: horizontal ? CGPoint(x: tip.x, y: tip.y + thinWidth / 2) : CGPoint(x: tip.x + thinWidth / 2, y: tip.y))
    posts.addLine(to: horizontal ? CGPoint(x: base.x, y: base.y + half) : CGPoint(x: base.x + half, y: base.y))
    posts.closeSubpath()
}
let taperLength: CGFloat = 26
taper(CGPoint(x: c.x, y: c.y - postInner + taperLength), CGPoint(x: c.x, y: c.y - postInner), horizontal: false)
taper(CGPoint(x: c.x, y: c.y + postInner - taperLength), CGPoint(x: c.x, y: c.y + postInner), horizontal: false)
taper(CGPoint(x: c.x - postInner + taperLength, y: c.y), CGPoint(x: c.x - postInner, y: c.y), horizontal: true)
taper(CGPoint(x: c.x + postInner - taperLength, y: c.y), CGPoint(x: c.x + postInner, y: c.y), horizontal: true)

let wires = CGMutablePath()
wires.addRect(CGRect(x: c.x - thinWidth / 2, y: c.y - postInner + taperLength, width: thinWidth, height: postInner - taperLength - centerGap))
wires.addRect(CGRect(x: c.x - thinWidth / 2, y: c.y + centerGap, width: thinWidth, height: postInner - taperLength - centerGap))
wires.addRect(CGRect(x: c.x - postInner + taperLength, y: c.y - thinWidth / 2, width: postInner - taperLength - centerGap, height: thinWidth))
wires.addRect(CGRect(x: c.x + centerGap, y: c.y - thinWidth / 2, width: postInner - taperLength - centerGap, height: thinWidth))

// Elevation ladder below center and windage hashes either side: the MRAD tree.
let hashes = CGMutablePath()
let hashSpacing: CGFloat = 34
for i in 1...4 {
    let y = c.y + centerGap + CGFloat(i) * hashSpacing - 10
    let half: CGFloat = i % 2 == 0 ? 30 : 18
    hashes.addRect(CGRect(x: c.x - half, y: y - 2.5, width: half * 2, height: 5))
}
for i in 1...4 {
    let x = CGFloat(i) * hashSpacing + centerGap - 10
    let half: CGFloat = i % 2 == 0 ? 20 : 12
    hashes.addRect(CGRect(x: c.x + x - 2.5, y: c.y - half, width: 5, height: half * 2))
    hashes.addRect(CGRect(x: c.x - x - 2.5, y: c.y - half, width: 5, height: half * 2))
}

let reticle = CGMutablePath()
reticle.addPath(posts)
reticle.addPath(wires)
reticle.addPath(hashes)
glow(rgb(0xE0A795, 0.5), blur: 22) {
    ctx.saveGState()
    ctx.addPath(reticle)
    ctx.clip()
    ctx.drawLinearGradient(metal, start: CGPoint(x: 260, y: 220), end: CGPoint(x: 780, y: 820), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

// 5. Center aiming dot: the zero.
let dotRadius: CGFloat = 11
ctx.setFillColor(rgb(0xFBE3D6))
ctx.fillEllipse(in: CGRect(x: c.x - dotRadius, y: c.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))

// 6. Hold point on the third hash of the ladder: a hot rose gold point with a bloom.
let hold = CGPoint(x: c.x, y: c.y + centerGap + 3 * hashSpacing - 10)
let bloom = CGGradient(
    colorsSpace: space,
    colors: [rgb(0xFFF1E8, 1), rgb(0xF2B9A4, 0.85), rgb(0xE0A795, 0.35), rgb(0xE0A795, 0)] as CFArray,
    locations: [0, 0.12, 0.38, 1]
)!
ctx.drawRadialGradient(bloom, startCenter: hold, startRadius: 0, endCenter: hold, endRadius: 78, options: [])
ctx.setFillColor(rgb(0xFFF6F0))
ctx.fillEllipse(in: CGRect(x: hold.x - 8, y: hold.y - 8, width: 16, height: 16))

// 7. Glass glint: a soft arc of light across the upper left of the lens.
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: c.x - ringInner, y: c.y - ringInner, width: ringInner * 2, height: ringInner * 2))
ctx.clip()
ctx.setLineCap(.round)
ctx.setLineWidth(18)
ctx.setStrokeColor(rgb(0xF6C9B8, 0.035))
ctx.addArc(center: c, radius: ringInner - 46, startAngle: .pi * 1.08, endAngle: .pi * 1.42, clockwise: false)
ctx.strokePath()
ctx.setLineWidth(5)
ctx.setStrokeColor(rgb(0xF6C9B8, 0.05))
ctx.addArc(center: c, radius: ringInner - 82, startAngle: .pi * 1.12, endAngle: .pi * 1.3, clockwise: false)
ctx.strokePath()
ctx.restoreGState()

let image = ctx.makeImage()!
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Could not write \(out.path)") }
print("Wrote \(out.path)")
