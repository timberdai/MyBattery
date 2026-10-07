// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

// MARK: - Mac Daddy

public enum MacDaddyLevel: Hashable { case cool, sweating, redHot }
public enum MacDaddyFlourish: Hashable { case hatTip, chainGlint }

extension CharacterIcon {
    /// How long Menu Pimp's grin lasts: the same 550 ms as Archimedes' blink.
    public static let macDaddyGrinDuration: TimeInterval = 0.55
}

extension CharacterIcon {
    /// Mac Daddy: a tiny pimp from the chest up, in the caterpillar's storybook
    /// style. Wide-brim hat with a feather, fur-collared suit, gold chain. The
    /// suit carries the process load — purple when cool, amber with a sweat drop
    /// when sweating, red with a popped collar and wide eyes when red-hot.
    /// Asleep (every cleanup duty paused) his eyes shut, a "z" floats by the hat
    /// and the suit greys, but sweat and red still show. `.hatTip` lifts and
    /// tilts the hat; `.chainGlint` puts a sparkle on the chain. One 24x22pt
    /// canvas for every state. Drawn at 8x, downsampled to 2x and 1x, cached.
    ///
    /// - Parameter grin: how far through his once-a-minute grin he is, 0...1;
    ///   0 is no grin. Grin frames are not cached.
    public static func macDaddy(level: MacDaddyLevel, asleep: Bool, flourish: MacDaddyFlourish?, grin: CGFloat = 0) -> NSImage {
        MacDaddyGlyph.image(.init(level: level, asleep: asleep, flourish: flourish,
                                  grin: grin > 0 && grin < 1 && !asleep ? grin : 0))
    }
}

private enum MacDaddyGlyph {
    struct State: Hashable { let level: MacDaddyLevel; let asleep: Bool; let flourish: MacDaddyFlourish?; var grin: CGFloat = 0 }

    static let size = NSSize(width: 24, height: 22)
    static let supersample: CGFloat = 8
    private static var cache: [State: NSImage] = [:]

    static func image(_ s: State) -> NSImage {
        if let cached = cache[s] { return cached }
        let big = render(s, scale: supersample)
        let image = NSImage(size: size)
        for scale in [2, 1] as [CGFloat] { if let rep = downsample(big, scale: scale) { image.addRepresentation(rep) } }
        image.isTemplate = false
        if s.grin == 0 { cache[s] = image }
        return image
    }

    // MARK: Palette

    static let ink = NSColor(red: 0.12, green: 0.10, blue: 0.10, alpha: 1)
    static let skin = (light: NSColor(red: 0.45, green: 0.29, blue: 0.20, alpha: 1), dark: NSColor(red: 0.30, green: 0.18, blue: 0.12, alpha: 1))
    static let beard = (light: NSColor(white: 0.62, alpha: 1), dark: NSColor(white: 0.38, alpha: 1))
    static let iris = NSColor(red: 0.35, green: 0.62, blue: 0.92, alpha: 1)
    static let hat = (light: NSColor(red: 0.56, green: 0.30, blue: 0.76, alpha: 1), dark: NSColor(red: 0.30, green: 0.12, blue: 0.46, alpha: 1))
    static let band = NSColor(red: 0.96, green: 0.80, blue: 0.20, alpha: 1)
    static let feather = (light: NSColor(red: 0.98, green: 0.45, blue: 0.70, alpha: 1), dark: NSColor(red: 0.78, green: 0.20, blue: 0.48, alpha: 1))
    static let fur = (light: NSColor(white: 0.99, alpha: 1), dark: NSColor(white: 0.80, alpha: 1))
    static let gold = (light: NSColor(red: 1.00, green: 0.88, blue: 0.35, alpha: 1), dark: NSColor(red: 0.80, green: 0.60, blue: 0.10, alpha: 1))
    static let sweat = NSColor(red: 0.45, green: 0.78, blue: 1.00, alpha: 1)
    static let zBlue = NSColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1)

    static func suit(_ s: State) -> (light: NSColor, dark: NSColor) {
        var c: (light: NSColor, dark: NSColor)
        switch s.level {
        case .cool: c = (NSColor(red: 0.58, green: 0.32, blue: 0.80, alpha: 1), NSColor(red: 0.32, green: 0.13, blue: 0.48, alpha: 1))
        case .sweating: c = (NSColor(red: 0.98, green: 0.68, blue: 0.22, alpha: 1), NSColor(red: 0.70, green: 0.40, blue: 0.06, alpha: 1))
        case .redHot: c = (NSColor(red: 0.94, green: 0.24, blue: 0.20, alpha: 1), NSColor(red: 0.58, green: 0.07, blue: 0.06, alpha: 1))
        }
        if s.asleep {
            // Cool and asleep goes fully grey; a hot suit keeps some of its warning colour.
            let f: CGFloat = s.level == .cool ? 0.8 : 0.35
            c = (c.light.blended(withFraction: f, of: NSColor(white: 0.72, alpha: 1)) ?? c.light,
                 c.dark.blended(withFraction: f, of: NSColor(white: 0.45, alpha: 1)) ?? c.dark)
        }
        return c
    }

    // MARK: Rendering (same pipeline as the raccoon)

    private static func render(_ s: State, scale: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        ctx.shouldAntialias = true
        let t = NSAffineTransform(); t.scale(by: scale); t.concat()
        draw(s)
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

    private static func shaded(_ path: NSBezierPath, _ c: (light: NSColor, dark: NSColor), ink width: CGFloat = 0.6) {
        NSGradient(starting: c.light, ending: c.dark)?.draw(in: path, angle: -70)
        ink.set(); path.lineWidth = width; path.lineJoinStyle = .round; path.stroke()
    }

    private static func oval(_ c: NSPoint, _ w: CGFloat, _ h: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
    }

    private static func draw(_ s: State) {
        let cg = NSGraphicsContext.current!.cgContext
        if s.asleep { cg.setAlpha(0.88); cg.beginTransparencyLayer(auxiliaryInfo: nil) }

        // Suit: shoulders across the bottom, a flat neckline hidden by the fur collar.
        let suitPath = NSBezierPath()
        suitPath.move(to: NSPoint(x: 2.5, y: 0))
        suitPath.curve(to: NSPoint(x: 8, y: 5.6), controlPoint1: NSPoint(x: 2.8, y: 3.4), controlPoint2: NSPoint(x: 5, y: 5.2))
        suitPath.line(to: NSPoint(x: 16, y: 5.6))
        suitPath.curve(to: NSPoint(x: 21.5, y: 0), controlPoint1: NSPoint(x: 19, y: 5.2), controlPoint2: NSPoint(x: 21.2, y: 3.4))
        suitPath.close()
        shaded(suitPath, suit(s))

        // Fur collar: two fluffy rolls; popped higher when red-hot (the collar tug).
        let collarRise: CGFloat = s.level == .redHot ? 1.2 : 0
        for x in [CGFloat(6.6), 17.4] {
            shaded(oval(NSPoint(x: x, y: 4.6 + collarRise), 5.2, 3.0 + collarRise), fur, ink: 0.45)
        }

        // Head.
        let head = oval(NSPoint(x: 12, y: 9.4), 8.6, 8.4)
        shaded(head, skin, ink: 0.6)

        // Short grey beard: jaw and chin, with the moustache dipping over the mouth.
        let beardPath = NSBezierPath()
        beardPath.move(to: NSPoint(x: 7.8, y: 8.6))
        beardPath.curve(to: NSPoint(x: 12, y: 5.0), controlPoint1: NSPoint(x: 7.6, y: 6.6), controlPoint2: NSPoint(x: 9.4, y: 5.0))
        beardPath.curve(to: NSPoint(x: 16.2, y: 8.6), controlPoint1: NSPoint(x: 14.6, y: 5.0), controlPoint2: NSPoint(x: 16.4, y: 6.6))
        beardPath.curve(to: NSPoint(x: 12, y: 7.9), controlPoint1: NSPoint(x: 15.4, y: 7.7), controlPoint2: NSPoint(x: 13.6, y: 8.2))
        beardPath.curve(to: NSPoint(x: 7.8, y: 8.6), controlPoint1: NSPoint(x: 10.4, y: 8.2), controlPoint2: NSPoint(x: 8.6, y: 7.7))
        beardPath.close()
        shaded(beardPath, beard, ink: 0.6)

        // Gold chain: a sagging arc across the chest with a medallion.
        let chain = NSBezierPath()
        chain.move(to: NSPoint(x: 8.2, y: 4.4))
        chain.curve(to: NSPoint(x: 15.8, y: 4.4), controlPoint1: NSPoint(x: 9.5, y: 1.4), controlPoint2: NSPoint(x: 14.5, y: 1.4))
        gold.dark.set(); chain.lineWidth = 0.9; chain.stroke()
        shaded(oval(NSPoint(x: 12, y: 2.3), 2.4, 2.4), gold, ink: 0.4)

        // Face.
        let eyeY: CGFloat = 9.8
        for x in [CGFloat(10.1), 13.9] {
            if s.asleep {
                let lid = NSBezierPath()
                lid.move(to: NSPoint(x: x - 1.1, y: eyeY))
                lid.curve(to: NSPoint(x: x + 1.1, y: eyeY), controlPoint1: NSPoint(x: x - 0.5, y: eyeY - 0.7), controlPoint2: NSPoint(x: x + 0.5, y: eyeY - 0.7))
                ink.set(); lid.lineWidth = 0.55; lid.lineCapStyle = .round; lid.stroke()
            } else {
                let open: CGFloat = s.level == .cool ? 1.1 : (s.level == .sweating ? 1.8 : 2.4)
                NSColor.white.set(); oval(NSPoint(x: x, y: eyeY), 2.2, open).fill()
                iris.set(); oval(NSPoint(x: x, y: eyeY - 0.1), 1.4, min(open, 1.5)).fill()
                ink.set(); oval(NSPoint(x: x, y: eyeY - 0.1), 0.8, min(open, 1.0)).fill()
                if s.level == .cool {
                    // half-lidded: a heavy lid line across the top of the eye
                    let lid = NSBezierPath()
                    lid.move(to: NSPoint(x: x - 1.2, y: eyeY + 0.35)); lid.line(to: NSPoint(x: x + 1.2, y: eyeY + 0.35))
                    lid.lineWidth = 0.75; lid.lineCapStyle = .round; lid.stroke()
                }
            }
        }
        // Mouth: a sly smile with a gold tooth; a tight grimace when red-hot.
        let mouth = NSBezierPath()
        if s.level == .redHot && !s.asleep {
            mouth.move(to: NSPoint(x: 10.4, y: 7.0)); mouth.line(to: NSPoint(x: 13.6, y: 7.0))
        } else {
            mouth.move(to: NSPoint(x: 10.2, y: 7.3))
            mouth.curve(to: NSPoint(x: 13.8, y: 7.1), controlPoint1: NSPoint(x: 11.2, y: 6.2), controlPoint2: NSPoint(x: 13.0, y: 6.3))
        }
        ink.set(); mouth.lineWidth = 0.55; mouth.lineCapStyle = .round; mouth.stroke()
        if !s.asleep { gold.light.set(); NSBezierPath(rect: NSRect(x: 12.3, y: 6.5, width: 0.7, height: 0.6)).fill() }
        if s.grin > 0 { MacDaddyOverlay.grin(s.grin, mouth: NSPoint(x: 12, y: 6.9)) }

        // Sweat: one drop when sweating, two when red-hot — drawn even asleep.
        let drops: [NSPoint] = s.level == .cool ? [] : (s.level == .sweating ? [NSPoint(x: 16.6, y: 10.6)] : [NSPoint(x: 16.6, y: 10.6), NSPoint(x: 7.3, y: 10.0)])
        for d in drops {
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: d.x, y: d.y + 1.4))
            drop.curve(to: NSPoint(x: d.x, y: d.y - 0.6), controlPoint1: NSPoint(x: d.x - 1.0, y: d.y + 0.2), controlPoint2: NSPoint(x: d.x - 0.8, y: d.y - 0.6))
            drop.curve(to: NSPoint(x: d.x, y: d.y + 1.4), controlPoint1: NSPoint(x: d.x + 0.8, y: d.y - 0.6), controlPoint2: NSPoint(x: d.x + 1.0, y: d.y + 0.2))
            sweat.set(); drop.fill(); ink.set(); drop.lineWidth = 0.35; drop.stroke()
        }

        // Hat: brim + crown + band + feather. Lifted 1pt and tilted (clockwise) on a hat tip.
        NSGraphicsContext.saveGraphicsState()
        if s.flourish == .hatTip {
            let t = NSAffineTransform()
            t.translateX(by: 12, yBy: 13.5); t.rotate(byDegrees: -10); t.translateX(by: -12, yBy: -13.5 + 1.0); t.concat()
        }
        let brim = oval(NSPoint(x: 12, y: 13.4), 22.0, 3.0)
        shaded(brim, hat, ink: 0.55)
        let crown = NSBezierPath(roundedRect: NSRect(x: 7.6, y: 13.6, width: 8.8, height: 5.6), xRadius: 1.6, yRadius: 1.6)
        shaded(crown, hat, ink: 0.55)
        band.set(); NSBezierPath(rect: NSRect(x: 7.7, y: 14.2, width: 8.6, height: 1.2)).fill()
        let plume = NSBezierPath()
        plume.move(to: NSPoint(x: 15.6, y: 14.6))
        plume.curve(to: NSPoint(x: 21.4, y: 21.0), controlPoint1: NSPoint(x: 18.5, y: 16.0), controlPoint2: NSPoint(x: 20.5, y: 18.2))
        plume.curve(to: NSPoint(x: 16.4, y: 15.6), controlPoint1: NSPoint(x: 19.2, y: 19.2), controlPoint2: NSPoint(x: 17.8, y: 17.0))
        plume.close()
        shaded(plume, feather, ink: 0.4)
        NSGraphicsContext.restoreGraphicsState()

        // Chain glint: a four-point sparkle on the medallion.
        if s.flourish == .chainGlint {
            let c = NSPoint(x: 13.4, y: 3.2)
            let star = NSBezierPath()
            for (i, r) in [CGFloat(2.4), 0.6, 2.4, 0.6, 2.4, 0.6, 2.4, 0.6].enumerated() {
                let a = CGFloat(i) * .pi / 4 + .pi / 2
                let p = NSPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                i == 0 ? star.move(to: p) : star.line(to: p)
            }
            star.close()
            NSColor.white.set(); star.fill(); gold.dark.set(); star.lineWidth = 0.3; star.stroke()
        }

        // Asleep: a blue "z" by the left of the hat.
        if s.asleep {
            let z = NSBezierPath()
            z.move(to: NSPoint(x: 0.8, y: 21.2)); z.line(to: NSPoint(x: 3.2, y: 21.2))
            z.line(to: NSPoint(x: 0.8, y: 18.6)); z.line(to: NSPoint(x: 3.2, y: 18.6))
            zBlue.set(); z.lineWidth = 0.7; z.lineCapStyle = .round; z.lineJoinStyle = .round; z.stroke()
            cg.endTransparencyLayer()
        }
    }
}
