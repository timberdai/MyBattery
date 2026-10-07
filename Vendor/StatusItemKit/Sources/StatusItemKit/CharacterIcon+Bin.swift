// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

extension CharacterIcon {
    /// Download Recycler: its mascot, a wheelie bin with a face, drawn in the caterpillar's
    /// storybook style (ink outlines, soft shading). Active, it is green and wide awake, lid
    /// popped, grinning, a broom in its hand. Paused, it is grey and asleep — eyes shut, lid
    /// down, a "z" drifting up — with the broom leant against its side. One 24x22pt canvas
    /// for both, so the bar never shifts. Drawn at 8x and downsampled to 2x and 1x bitmaps,
    /// and cached.
    public static func bin(active: Bool) -> NSImage {
        BinGlyph.image(active: active)
    }
}

/// The bin's drawing. See `CharacterIcon.bin(active:)`.
private enum BinGlyph {
    static let size = NSSize(width: 24, height: 22)
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

    static let ink = NSColor(red: 0.22, green: 0.14, blue: 0.09, alpha: 1)
    static let cheek = NSColor(red: 0.98, green: 0.60, blue: 0.62, alpha: 0.9)
    static let tongue = NSColor(red: 0.96, green: 0.45, blue: 0.47, alpha: 1)
    static let wood = (light: NSColor(red: 0.80, green: 0.55, blue: 0.30, alpha: 1), dark: NSColor(red: 0.52, green: 0.32, blue: 0.15, alpha: 1))
    static let straw = (light: NSColor(red: 1.00, green: 0.86, blue: 0.42, alpha: 1), dark: NSColor(red: 0.88, green: 0.60, blue: 0.16, alpha: 1))
    static let band = NSColor(red: 0.85, green: 0.24, blue: 0.20, alpha: 1)

    struct Palette {
        let light, mid, dark: NSColor
        init(active: Bool) {
            let base = active ? NSColor(red: 0.46, green: 0.76, blue: 0.27, alpha: 1) : NSColor(white: 0.64, alpha: 1)
            let cream = NSColor(red: 0.97, green: 0.96, blue: 0.84, alpha: 1)
            light = base.blended(withFraction: 0.35, of: cream) ?? base
            mid = base
            dark = base.blended(withFraction: 0.32, of: .black) ?? base
        }
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
        draw(active: active, palette: Palette(active: active))
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
    private static func shaded(_ path: NSBezierPath, light: NSColor, dark: NSColor, ink width: CGFloat = 0.55) {
        NSGradient(starting: light, ending: dark)?.draw(in: path, angle: -60)
        ink.set(); path.lineWidth = width; path.lineJoinStyle = .round; path.stroke()
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

    // MARK: Parts

    /// The broom: a wooden handle from `top` to `neck`, a red binding, and a straw fan
    /// splaying down to the ground.
    private static func broom(top: NSPoint, neck: NSPoint) {
        let handle = NSBezierPath(); handle.move(to: top); handle.line(to: neck); handle.lineCapStyle = .round
        ink.set(); handle.lineWidth = 1.55; handle.stroke()
        wood.light.set(); handle.lineWidth = 0.8; handle.stroke()
        // Straw: a fan below the neck, flat at the ground, with a couple of ink strands.
        let dx = neck.x - top.x, dy = neck.y - top.y, len = hypot(dx, dy)
        let ux = dx / len, uy = dy / len          // down the handle
        let nx = -uy, ny = ux                     // across it
        let bind = p(neck.x + ux * 0.9, neck.y + uy * 0.9)
        let fan = NSBezierPath()
        fan.move(to: p(neck.x + nx * 0.9, neck.y + ny * 0.9))
        fan.curve(to: p(bind.x + nx * 2.6 + ux * 3.6, 0.7), controlPoint1: p(bind.x + nx * 1.4, bind.y + ny * 1.4), controlPoint2: p(bind.x + nx * 2.4 + ux * 2.4, 2.0))
        fan.curve(to: p(bind.x - nx * 2.6 + ux * 3.6, 0.7), controlPoint1: p(bind.x + ux * 3.6, 0.2), controlPoint2: p(bind.x + ux * 3.6, 0.2))
        fan.curve(to: p(neck.x - nx * 0.9, neck.y - ny * 0.9), controlPoint1: p(bind.x - nx * 2.4 + ux * 2.4, 2.0), controlPoint2: p(bind.x - nx * 1.4, bind.y - ny * 1.4))
        fan.close()
        shaded(fan, light: straw.light, dark: straw.dark, ink: 0.5)
        ink.withAlphaComponent(0.55).set()
        for k in [-0.9, 0.9] as [CGFloat] {
            let s = NSBezierPath(); s.move(to: p(bind.x + nx * k * 0.5 + ux * 0.6, bind.y + ny * k * 0.5 + uy * 0.6))
            s.line(to: p(bind.x + nx * k * 1.5 + ux * 3.0, 1.5)); s.lineWidth = 0.3; s.lineCapStyle = .round; s.stroke()
        }
        // Binding: a red collar where the straw meets the handle.
        let collar = NSBezierPath()
        collar.move(to: p(neck.x + nx * 1.0, neck.y + ny * 1.0)); collar.line(to: p(neck.x - nx * 1.0, neck.y - ny * 1.0))
        collar.line(to: p(bind.x - nx * 1.2, bind.y - ny * 1.2)); collar.line(to: p(bind.x + nx * 1.2, bind.y + ny * 1.2)); collar.close()
        band.set(); collar.fill(); ink.set(); collar.lineWidth = 0.45; collar.stroke()
    }

    private static func draw(active: Bool, palette: Palette) {
        // Broom first when it is only leant against the bin (behind it); in the bin's
        // hand when active, so drawn after the body.
        let broomTop = active ? p(17.4, 19.6) : p(16.8, 19.2)
        let broomNeck = active ? p(20.4, 6.2) : p(19.4, 6.0)
        if !active { broom(top: broomTop, neck: broomNeck) }

        // Wheel peeking out behind the bottom right corner.
        let wheel = NSBezierPath(ovalIn: NSRect(x: 11.6, y: 0.4, width: 3.4, height: 3.4))
        shaded(wheel, light: NSColor(white: 0.40, alpha: 1), dark: NSColor(white: 0.10, alpha: 1), ink: 0.45)

        // Body: a tapered tub, rounded at the bottom corners.
        let body = NSBezierPath()
        body.move(to: p(2.4, 15.0))
        body.line(to: p(15.6, 15.0))
        body.line(to: p(14.5, 2.9))
        body.curve(to: p(12.9, 1.3), controlPoint1: p(14.4, 1.9), controlPoint2: p(13.9, 1.3))
        body.line(to: p(5.1, 1.3))
        body.curve(to: p(3.5, 2.9), controlPoint1: p(4.1, 1.3), controlPoint2: p(3.6, 1.9))
        body.close()
        shaded(body, light: palette.light, dark: palette.dark, ink: 0.6)
        // A soft highlight down the left flank, and a darker band under the lid.
        NSColor(white: 1, alpha: 0.45).set()
        let gloss = NSBezierPath(); gloss.move(to: p(3.9, 13.4)); gloss.line(to: p(4.7, 4.0)); gloss.lineWidth = 0.8; gloss.lineCapStyle = .round; gloss.stroke()
        palette.dark.withAlphaComponent(0.8).set()
        NSBezierPath(rect: NSRect(x: 2.7, y: 13.9, width: 12.6, height: 0.8)).fill()

        // Lid: a slab wider than the body with a grip on top. Active, it pops up at the
        // front (tilted about its back edge) as if the bin just gulped something down.
        let lid = NSBezierPath(roundedRect: NSRect(x: 1.4, y: 15.0, width: 15.2, height: 2.4), xRadius: 1.1, yRadius: 1.1)
        let grip = NSBezierPath(roundedRect: NSRect(x: 7.0, y: 17.0, width: 4.0, height: 1.9), xRadius: 0.8, yRadius: 0.8)
        NSGraphicsContext.saveGraphicsState()
        if active {
            let tilt = NSAffineTransform(); tilt.translateX(by: 1.6, yBy: 15.2); tilt.rotate(byDegrees: 7); tilt.translateX(by: -1.6, yBy: -15.2); tilt.concat()
            // the dark mouth of the bin under the raised lid
            ink.set()
            let gap = NSBezierPath(); gap.move(to: p(1.8, 15.1)); gap.line(to: p(16.2, 15.1)); gap.lineWidth = 0.6; gap.stroke()
        }
        shaded(grip, light: palette.mid, dark: palette.dark, ink: 0.5)
        shaded(lid, light: palette.light, dark: palette.dark, ink: 0.6)
        NSColor(white: 1, alpha: 0.5).set()
        let lidGloss = NSBezierPath(); lidGloss.move(to: p(3.0, 16.7)); lidGloss.line(to: p(8.0, 16.7)); lidGloss.lineWidth = 0.5; lidGloss.lineCapStyle = .round; lidGloss.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // Face.
        let eyeY: CGFloat = 8.4
        cheek.set()
        NSBezierPath(ovalIn: NSRect(x: 3.9, y: 5.6, width: 2.2, height: 1.4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 12.0, y: 5.6, width: 2.2, height: 1.4)).fill()
        if active {
            // Big eyes: white, pupil glancing toward the broom, glint.
            for cx in [6.5, 11.3] as [CGFloat] {
                let eye = NSBezierPath(ovalIn: NSRect(x: cx - 1.75, y: eyeY, width: 3.5, height: 4.2))
                NSColor.white.set(); eye.fill(); ink.set(); eye.lineWidth = 0.45; eye.stroke()
                NSBezierPath(ovalIn: NSRect(x: cx - 0.85, y: eyeY + 0.55, width: 2.3, height: 2.9)).fill()
                NSColor.white.set(); NSBezierPath(ovalIn: NSRect(x: cx + 0.35, y: eyeY + 2.35, width: 0.75, height: 0.75)).fill()
            }
            // Open grin with a tongue.
            let mouth = NSBezierPath()
            mouth.move(to: p(7.0, 6.9)); mouth.line(to: p(11.0, 6.9))
            mouth.curve(to: p(7.0, 6.9), controlPoint1: p(10.8, 4.2), controlPoint2: p(7.2, 4.2))
            mouth.close()
            ink.set(); mouth.fill()
            NSGraphicsContext.saveGraphicsState(); mouth.addClip()
            tongue.set(); NSBezierPath(ovalIn: NSRect(x: 7.9, y: 4.3, width: 2.6, height: 1.8)).fill()
            NSGraphicsContext.restoreGraphicsState()
            mouth.lineWidth = 0.45; mouth.lineJoinStyle = .round; mouth.stroke()
        } else {
            // Asleep: closed-eye arcs and a small calm mouth.
            ink.set()
            for cx in [6.5, 11.3] as [CGFloat] {
                let lid = NSBezierPath(); lid.move(to: p(cx - 1.6, eyeY + 1.6))
                lid.curve(to: p(cx + 1.6, eyeY + 1.6), controlPoint1: p(cx - 0.9, eyeY + 0.5), controlPoint2: p(cx + 0.9, eyeY + 0.5))
                lid.lineWidth = 0.65; lid.lineCapStyle = .round; lid.stroke()
            }
            let mouth = NSBezierPath(); mouth.move(to: p(8.3, 6.2))
            mouth.curve(to: p(9.7, 6.2), controlPoint1: p(8.7, 5.6), controlPoint2: p(9.3, 5.6))
            mouth.lineWidth = 0.55; mouth.lineCapStyle = .round; mouth.stroke()
        }

        if active {
            broom(top: broomTop, neck: broomNeck)
            // A stubby arm from the bin's side, its round hand closed on the handle.
            let arm = NSBezierPath(); arm.move(to: p(14.9, 8.2))
            arm.curve(to: p(18.6, 10.4), controlPoint1: p(16.4, 8.0), controlPoint2: p(17.6, 9.0))
            arm.lineCapStyle = .round
            ink.set(); arm.lineWidth = 1.9; arm.stroke()
            palette.mid.set(); arm.lineWidth = 1.0; arm.stroke()
            let hand = NSBezierPath(ovalIn: NSRect(x: 17.6, y: 9.6, width: 2.3, height: 2.3))
            shaded(hand, light: palette.light, dark: palette.mid, ink: 0.45)
        } else {
            // A "z" drifting up beside the lid.
            ink.set()
            let z = NSBezierPath(); z.move(to: p(19.4, 18.4)); z.line(to: p(21.8, 18.4)); z.line(to: p(19.4, 15.8)); z.line(to: p(21.8, 15.8))
            z.lineWidth = 1.7; z.lineCapStyle = .round; z.lineJoinStyle = .round; z.stroke()
            NSColor(white: 0.97, alpha: 1).set(); z.lineWidth = 0.8; z.stroke()
        }
    }
}
