// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

// MARK: - Raccoon (Media Tracking Killer)

extension CharacterIcon {
    /// Media Tracking Killer: a raccoon's head, front on, drawn in the caterpillar's
    /// storybook style (ink outlines, soft shading). Warm grey fur, white-rimmed ears
    /// with dark insides, white brows, the black bandit mask with a stripe up the
    /// forehead, a cream muzzle and a black nose. `active` (killing trackers): eyes
    /// wide open with red irises under brows angled down in a scowl. Paused: asleep —
    /// the fur cools to grey and fades a little, the eyes shut into lashed arcs, the
    /// brows relax and a blue "z" drifts up by the right ear. One 26x22pt canvas for
    /// both (the head is 24 wide; the last 2pt are the z's), so the bar never shifts.
    /// Drawn at 8x and downsampled to 2x and 1x bitmaps, and cached.
    public static func raccoon(active: Bool) -> NSImage {
        RaccoonGlyph.image(active: active)
    }
}

/// The raccoon's drawing. See `CharacterIcon.raccoon(active:)`.
private enum RaccoonGlyph {
    static let size = NSSize(width: 26, height: 22)
    static let supersample: CGFloat = 8
    private static var cache: [Bool: NSImage] = [:]

    static func image(active: Bool) -> NSImage {
        if let cached = cache[active] { return cached }
        let big = render(active: active, scale: supersample)
        let image = NSImage(size: size)
        for scale in [2, 1] as [CGFloat] {
            if let rep = downsample(big, scale: scale) { image.addRepresentation(rep) }
        }
        image.isTemplate = false
        cache[active] = image
        return image
    }

    // MARK: Palette

    static let ink = NSColor(red: 0.13, green: 0.11, blue: 0.10, alpha: 1)
    static let mask = NSColor(red: 0.17, green: 0.15, blue: 0.14, alpha: 1)
    static let cream = NSColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1)
    static let creamShade = NSColor(red: 0.84, green: 0.81, blue: 0.76, alpha: 1)
    static let earInside = NSColor(red: 0.30, green: 0.25, blue: 0.23, alpha: 1)
    static let iris = NSColor(red: 0.93, green: 0.16, blue: 0.13, alpha: 1)
    static let irisDeep = NSColor(red: 0.62, green: 0.05, blue: 0.05, alpha: 1)

    /// Fur: warm grey when on the hunt, a cooler, flatter grey asleep.
    static func fur(_ active: Bool) -> (light: NSColor, dark: NSColor) {
        active ? (NSColor(red: 0.80, green: 0.77, blue: 0.73, alpha: 1), NSColor(red: 0.47, green: 0.44, blue: 0.41, alpha: 1))
               : (NSColor(white: 0.70, alpha: 1), NSColor(white: 0.47, alpha: 1))
    }

    // MARK: Rendering

    private static func render(active: Bool, scale: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        ctx.shouldAntialias = true
        let t = NSAffineTransform(); t.scale(by: scale); t.concat()
        draw(active: active)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func downsample(_ source: NSBitmapImageRep, scale: CGFloat) -> NSBitmapImageRep? {
        guard let cg = source.cgImage else { return nil }
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let out = context.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: out)
        rep.size = size
        return rep
    }

    /// Fills `path` with a top-left-lit gradient, then outlines it in ink.
    private static func shaded(_ path: NSBezierPath, light: NSColor, dark: NSColor, ink width: CGFloat = 0.6) {
        NSGradient(starting: light, ending: dark)?.draw(in: path, angle: -70)
        ink.set(); path.lineWidth = width; path.lineJoinStyle = .round; path.stroke()
    }

    /// An ellipse centred on `c`, tilted by `deg` degrees.
    private static func oval(_ c: NSPoint, _ w: CGFloat, _ h: CGFloat, tilt deg: CGFloat = 0) -> NSBezierPath {
        let p = NSBezierPath(ovalIn: NSRect(x: -w / 2, y: -h / 2, width: w, height: h))
        let t = NSAffineTransform(); t.translateX(by: c.x, yBy: c.y); t.rotate(byDegrees: deg); p.transform(using: t as AffineTransform)
        return p
    }

    /// Mirror of a left-half point about the face's centre line (x = 12).
    private static func m(_ p: NSPoint) -> NSPoint { NSPoint(x: 24 - p.x, y: p.y) }

    private static func draw(active: Bool) {
        let fur = fur(active)
        let dim: CGFloat = active ? 1 : 0.9
        // Asleep, the whole head fades back a little, like any paused status item.
        let cg = NSGraphicsContext.current!.cgContext
        if !active { cg.setAlpha(0.85); cg.beginTransparencyLayer(auxiliaryInfo: nil) }

        // Ears: go down first so the head overlaps their bases. Fur-coloured with a
        // pale rim, dark inside.
        for side in [false, true] {
            func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { side ? m(NSPoint(x: x, y: y)) : NSPoint(x: x, y: y) }
            let ear = NSBezierPath()
            ear.move(to: p(2.6, 11.5))
            ear.curve(to: p(4.3, 21.2), controlPoint1: p(2.2, 15.5), controlPoint2: p(2.8, 19.6))
            ear.curve(to: p(10.4, 15.0), controlPoint1: p(6.0, 21.0), controlPoint2: p(9.0, 18.0))
            ear.close()
            shaded(ear, light: cream, dark: creamShade)
            let inner = NSBezierPath()
            inner.move(to: p(3.9, 13.0))
            inner.curve(to: p(4.8, 19.4), controlPoint1: p(3.7, 15.8), controlPoint2: p(4.0, 18.4))
            inner.curve(to: p(8.8, 15.2), controlPoint1: p(6.0, 19.0), controlPoint2: p(7.8, 17.0))
            inner.close()
            earInside.withAlphaComponent(dim).set(); inner.fill()
        }

        // Head: broad crown, cheek ruffs flaring out and down in two tufts, narrowing
        // to the chin. Built as the left half, then mirrored.
        let leftHalf: [(NSPoint, NSPoint, NSPoint)] = [   // (to, cp1, cp2), from the crown going left
            (NSPoint(x: 2.4, y: 12.2), NSPoint(x: 7.0, y: 16.4), NSPoint(x: 3.0, y: 15.6)),
            (NSPoint(x: 0.4, y: 8.2), NSPoint(x: 2.0, y: 10.6), NSPoint(x: 1.0, y: 9.2)),
            (NSPoint(x: 2.0, y: 7.0), NSPoint(x: 0.9, y: 7.8), NSPoint(x: 1.5, y: 7.3)),
            (NSPoint(x: 0.9, y: 4.6), NSPoint(x: 1.6, y: 6.2), NSPoint(x: 1.2, y: 5.2)),
            (NSPoint(x: 6.6, y: 2.6), NSPoint(x: 2.8, y: 3.8), NSPoint(x: 5.0, y: 3.4)),
            (NSPoint(x: 12.0, y: 0.6), NSPoint(x: 8.2, y: 1.2), NSPoint(x: 10.2, y: 0.6)),
        ]
        let head = NSBezierPath()
        head.move(to: NSPoint(x: 12, y: 16.2))
        for (to, c1, c2) in leftHalf { head.curve(to: to, controlPoint1: c1, controlPoint2: c2) }
        // right half: the same segments walked backwards and mirrored
        for i in stride(from: leftHalf.count - 1, through: 0, by: -1) {
            let start = i == 0 ? NSPoint(x: 12, y: 16.2) : leftHalf[i - 1].0
            head.curve(to: m(start), controlPoint1: m(leftHalf[i].2), controlPoint2: m(leftHalf[i].1))
        }
        head.close()
        shaded(head, light: fur.light, dark: fur.dark, ink: 0.65)

        ctx { head.addClip()
            // Pale muzzle and lower cheeks.
            let muzzle = oval(NSPoint(x: 12, y: 3.6), 10.4, 6.6)
            NSGradient(starting: cream, ending: creamShade)?.draw(in: muzzle, angle: -80)
            // White brows over the mask, angled down toward the nose (a scowl) when
            // active, lifted and relaxed asleep.
            cream.set()
            oval(NSPoint(x: 7.0, y: 12.2), 6.0, 2.6, tilt: active ? -16 : 4).fill()
            oval(NSPoint(x: 17.0, y: 12.2), 6.0, 2.6, tilt: active ? 16 : -4).fill()
            // Bandit mask: a lobe round each eye sweeping down and out across the
            // cheek, joined over the nose bridge, with a dark stripe up the forehead.
            let band = oval(NSPoint(x: 6.8, y: 8.7), 8.2, 4.8, tilt: -14)
            band.append(oval(NSPoint(x: 17.2, y: 8.7), 8.2, 4.8, tilt: 14))
            band.append(NSBezierPath(roundedRect: NSRect(x: 9.6, y: 7.6, width: 4.8, height: 3.4), xRadius: 1.2, yRadius: 1.2))
            let stripe = NSBezierPath()
            stripe.move(to: NSPoint(x: 10.7, y: 10)); stripe.curve(to: NSPoint(x: 12, y: 16.4), controlPoint1: NSPoint(x: 10.9, y: 13), controlPoint2: NSPoint(x: 11.2, y: 15.4))
            stripe.curve(to: NSPoint(x: 13.3, y: 10), controlPoint1: NSPoint(x: 12.8, y: 15.4), controlPoint2: NSPoint(x: 13.1, y: 13))
            stripe.close(); band.append(stripe)
            band.windingRule = .nonZero
            mask.withAlphaComponent(active ? 1 : 0.92).set(); band.fill()
        }
        ink.set(); head.lineWidth = 0.65; head.stroke()

        // Eyes.
        for cx in [CGFloat(7.3), 16.7] {
            let c = NSPoint(x: cx, y: 9.0)
            if active {
                let white = oval(c, 4.0, 3.6)
                cream.set(); white.fill()
                let ir = oval(NSPoint(x: c.x + (cx < 12 ? 0.35 : -0.35), y: c.y - 0.1), 2.9, 2.9)
                NSGradient(starting: iris, ending: irisDeep)?.draw(in: ir, relativeCenterPosition: NSPoint(x: -0.2, y: 0.3))
                ink.set(); oval(NSPoint(x: c.x + (cx < 12 ? 0.4 : -0.4), y: c.y - 0.1), 1.2, 1.5).fill()
                NSColor.white.set(); oval(NSPoint(x: c.x + (cx < 12 ? -0.3 : 0.5), y: c.y + 0.7), 0.9, 0.9).fill()
                // heavy upper lid line so the eye reads narrowed under the brow
                ink.set()
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: c.x - 2.1, y: c.y + (cx < 12 ? 0.9 : 1.6)))
                lid.line(to: NSPoint(x: c.x + 2.1, y: c.y + (cx < 12 ? 1.6 : 0.9)))
                lid.lineWidth = 0.7; lid.lineCapStyle = .round; lid.stroke()
            } else {
                // shut: a soft downward arc with a lash tick, pale against the mask
                let arc = NSBezierPath()
                arc.move(to: NSPoint(x: c.x - 1.7, y: c.y + 0.2))
                arc.curve(to: NSPoint(x: c.x + 1.7, y: c.y + 0.2), controlPoint1: NSPoint(x: c.x - 0.9, y: c.y - 0.9), controlPoint2: NSPoint(x: c.x + 0.9, y: c.y - 0.9))
                // two lashes hanging off the outer half of the lid
                let out: CGFloat = cx < 12 ? -1 : 1
                arc.move(to: NSPoint(x: c.x + out * 1.1, y: c.y - 0.45)); arc.line(to: NSPoint(x: c.x + out * 1.6, y: c.y - 1.2))
                arc.move(to: NSPoint(x: c.x + out * 0.2, y: c.y - 0.65)); arc.line(to: NSPoint(x: c.x + out * 0.35, y: c.y - 1.5))
                arc.lineWidth = 0.85; arc.lineCapStyle = .round
                cream.set(); arc.stroke()
            }
        }

        // Nose: a rounded black wedge with a glint, and a small mouth under it.
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 10.2, y: 6.0))
        nose.curve(to: NSPoint(x: 13.8, y: 6.0), controlPoint1: NSPoint(x: 11.0, y: 6.9), controlPoint2: NSPoint(x: 13.0, y: 6.9))
        nose.curve(to: NSPoint(x: 12.0, y: 4.0), controlPoint1: NSPoint(x: 14.2, y: 5.2), controlPoint2: NSPoint(x: 12.8, y: 4.0))
        nose.curve(to: NSPoint(x: 10.2, y: 6.0), controlPoint1: NSPoint(x: 11.2, y: 4.0), controlPoint2: NSPoint(x: 9.8, y: 5.2))
        ink.set(); nose.fill()
        NSColor(white: 1, alpha: 0.7).set(); oval(NSPoint(x: 11.4, y: 6.0), 1.0, 0.5).fill()
        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: 12, y: 4.2)); mouth.line(to: NSPoint(x: 12, y: 3.2))
        mouth.move(to: NSPoint(x: 10.4, y: 3.0)); mouth.curve(to: NSPoint(x: 12, y: 3.2), controlPoint1: NSPoint(x: 11.0, y: 2.4), controlPoint2: NSPoint(x: 11.7, y: 2.5))
        mouth.curve(to: NSPoint(x: 13.6, y: 3.0), controlPoint1: NSPoint(x: 12.3, y: 2.5), controlPoint2: NSPoint(x: 13.0, y: 2.4))
        mouth.lineWidth = 0.5; mouth.lineCapStyle = .round; ink.set(); mouth.stroke()

        if !active { cg.endTransparencyLayer(); cg.setAlpha(1) }

        // Asleep: a sky-blue "z" drifting up past the right ear; mid-bright, so it
        // reads on a light bar and a dark one alike.
        if !active {
            let z = NSBezierPath()
            z.move(to: NSPoint(x: 22.0, y: 21.0)); z.line(to: NSPoint(x: 25.4, y: 21.0)); z.line(to: NSPoint(x: 22.0, y: 16.8)); z.line(to: NSPoint(x: 25.4, y: 16.8))
            z.lineJoinStyle = .round; z.lineCapStyle = .round
            NSColor(red: 0.35, green: 0.62, blue: 0.98, alpha: 1).set(); z.lineWidth = 1.2; z.stroke()
        }
    }

    /// Runs `body` inside a saved graphics state (for clips).
    private static func ctx(_ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState(); body(); NSGraphicsContext.restoreGraphicsState()
    }
}
