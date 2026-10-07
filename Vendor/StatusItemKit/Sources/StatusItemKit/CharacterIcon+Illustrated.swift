// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

// MARK: - Mac Daddy, illustrated

/// Mac Daddy's raster art, all on one 24x22pt canvas (1x + 2x reps each):
/// the bust, the same bust with eyes closed, the same bust tipping his hat, and
/// greyscale masks of the purple hat in the base/asleep art and in the hat-tip
/// art (gold band and feather excluded). The app ships these and passes them in.
public final class MacDaddyArt {
    public static let canvas = NSSize(width: 24, height: 22)
    /// Resource names, as shipped in an app's Resources/bundle (`<name>.png` + `<name>@2x.png`).
    public static let resourceNames = (base: "macdaddy-base", asleep: "macdaddy-asleep", hatTip: "macdaddy-hattip",
                                       hatMask: "macdaddy-hat-mask", hatTipMask: "macdaddy-hattip-hat-mask")

    public let base: NSImage, asleep: NSImage, hatTip: NSImage, hatMask: NSImage, hatTipMask: NSImage
    fileprivate var cache: [MacDaddyState: NSImage] = [:]

    public init(base: NSImage, asleep: NSImage, hatTip: NSImage, hatMask: NSImage, hatTipMask: NSImage) {
        self.base = base; self.asleep = asleep; self.hatTip = hatTip; self.hatMask = hatMask; self.hatTipMask = hatTipMask
    }

    /// The art from a bundle, or nil if any piece is missing.
    public static func load(from bundle: Bundle = .main) -> MacDaddyArt? {
        let n = resourceNames
        guard let base = IllustratedIcon.load(named: n.base, in: bundle),
              let asleep = IllustratedIcon.load(named: n.asleep, in: bundle),
              let hatTip = IllustratedIcon.load(named: n.hatTip, in: bundle),
              let hatMask = IllustratedIcon.load(named: n.hatMask, in: bundle),
              let hatTipMask = IllustratedIcon.load(named: n.hatTipMask, in: bundle) else { return nil }
        return MacDaddyArt(base: base, asleep: asleep, hatTip: hatTip, hatMask: hatMask, hatTipMask: hatTipMask)
    }
}

private struct MacDaddyState: Hashable { let level: MacDaddyLevel; let asleep: Bool; let flourish: MacDaddyFlourish? }

extension CharacterIcon {
    /// Mac Daddy from his illustrated art. The hat carries the load: purple as
    /// drawn when cool, amber with a sweat drop when sweating, red with two drops
    /// when red-hot. Asleep (every cleanup duty paused) he shows the eyes-closed
    /// art, greyed, with a blue "z" — but an amber or red hat and the sweat still
    /// show. `.hatTip` swaps in the hat-tip art; `.chainGlint` sparkles on the
    /// medallion. 24x22pt in every state, cached per state.
    ///
    /// - Parameter grin: how far through his once-a-minute grin he is, 0...1
    ///   (see `MacDaddyOverlay.grin`); 0 is no grin. Grin frames are not cached.
    public static func macDaddy(art: MacDaddyArt, level: MacDaddyLevel, asleep: Bool, flourish: MacDaddyFlourish?,
                                grin: CGFloat = 0) -> NSImage {
        let state = MacDaddyState(level: level, asleep: asleep, flourish: flourish)
        let grinning = grin > 0 && grin < 1 && !asleep
        if !grinning, let cached = art.cache[state] { return cached }
        let tipping = flourish == .hatTip && !asleep
        let picture = asleep ? art.asleep : (tipping ? art.hatTip : art.base)
        let mask = tipping ? art.hatTipMask : art.hatMask
        var recolor: [IllustratedIcon.Recolor] = []
        switch level {
        case .cool: break
        case .sweating: recolor.append(.init(mask: mask, color: MacDaddyOverlay.amber, strength: asleep ? 0.85 : 1))
        case .redHot: recolor.append(.init(mask: mask, color: MacDaddyOverlay.red, strength: asleep ? 0.85 : 1))
        }
        let image = IllustratedIcon.compose(size: MacDaddyArt.canvas, base: picture,
                                            desaturate: asleep ? 0.6 : 0, recolor: recolor,
                                            alpha: asleep ? 0.9 : 1) { _, scale in
            MacDaddyOverlay.sweat(level, scale: scale)
            if flourish == .chainGlint { MacDaddyOverlay.glint(scale: scale) }
            if asleep { MacDaddyOverlay.z(scale: scale) }
            if grinning { MacDaddyOverlay.grin(grin, mouth: MacDaddyOverlay.mouth) }
        }
        guard !grinning else { return image }
        art.cache[state] = image
        return image
    }
}

/// The code-drawn parts of the illustrated Mac Daddy, positioned on the art
/// (feature positions printed by mac-daddy-menubar's art/make_art.py).
enum MacDaddyOverlay {
    static let amber = NSColor(srgbRed: 0.98, green: 0.66, blue: 0.16, alpha: 1)
    static let red = NSColor(srgbRed: 0.93, green: 0.20, blue: 0.16, alpha: 1)
    static let ink = NSColor(srgbRed: 0.10, green: 0.08, blue: 0.08, alpha: 1)
    static let sweatBlue = NSColor(srgbRed: 0.50, green: 0.82, blue: 1.00, alpha: 1)
    static let zBlue = NSColor(srgbRed: 0.36, green: 0.62, blue: 1.00, alpha: 1)
    static let goldDark = NSColor(srgbRed: 0.80, green: 0.58, blue: 0.08, alpha: 1)

    /// Sweat drops by the temples: right first, then left.
    static let dropSpots = [NSPoint(x: 17.3, y: 10.2), NSPoint(x: 6.6, y: 10.2)]
    static let medallion = NSPoint(x: 11.77, y: 1.46)
    /// The middle of his mouth in the art.
    static let mouth = NSPoint(x: 11.8, y: 7.6)

    static let gold = NSColor(srgbRed: 1.00, green: 0.82, blue: 0.26, alpha: 1)

    /// Menu Pimp's once-a-minute grin, `progress` 0...1 through it, all
    /// linear: the first fifth the smile widens and opens to show a row of
    /// white teeth, the middle three fifths a gold gleam sweeps across them
    /// left to right with a sparkle riding on it, and the last fifth the smile
    /// closes again.
    static func grin(_ progress: CGFloat, mouth m: NSPoint) {
        let p = max(0, min(1, progress))
        let open = min(1, p / 0.2, (1 - p) / 0.2)
        guard open > 0 else { return }
        // The smile: a flat-topped D whose bottom drops and corners lift as it opens.
        let half = 1.7 + 0.7 * open, drop = 1.5 * open, lift = 0.5 * open
        let top = m.y + 0.45
        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: m.x - half, y: top + lift))
        smile.curve(to: NSPoint(x: m.x + half, y: top + lift),
                    controlPoint1: NSPoint(x: m.x - half * 0.55, y: top), controlPoint2: NSPoint(x: m.x + half * 0.55, y: top))
        smile.curve(to: NSPoint(x: m.x - half, y: top + lift),
                    controlPoint1: NSPoint(x: m.x + half * 0.6, y: top - drop * 1.35), controlPoint2: NSPoint(x: m.x - half * 0.6, y: top - drop * 1.35))
        smile.close()
        NSColor(srgbRed: 0.30, green: 0.06, blue: 0.08, alpha: 1).set(); smile.fill()
        NSGraphicsContext.saveGraphicsState()
        smile.addClip()
        // Upper teeth: a white band under the top lip, split into teeth.
        let teethDepth = 0.95 * open
        let teeth = NSRect(x: m.x - half, y: top - teethDepth, width: half * 2, height: teethDepth + lift + 0.2)
        NSColor(white: 0.98, alpha: 1).set(); NSBezierPath(rect: teeth).fill()
        NSColor(white: 0.70, alpha: 1).set()
        var x = m.x - 1.5
        while x <= m.x + 1.6 {
            NSBezierPath(rect: NSRect(x: x - 0.06, y: teeth.minY, width: 0.12, height: teeth.height)).fill()
            x += 0.75
        }
        // The gleam: a slanted gold bar with a white core crossing the teeth.
        let sweep = (p - 0.2) / 0.6
        var gleamX: CGFloat?
        if sweep > 0 && sweep < 1 {
            let gx = m.x - half - 0.8 + sweep * (half * 2 + 1.6)
            gleamX = gx
            func bar(_ w: CGFloat) -> NSBezierPath {
                let b = NSBezierPath()
                b.move(to: NSPoint(x: gx - w / 2 + 0.5, y: teeth.maxY)); b.line(to: NSPoint(x: gx + w / 2 + 0.5, y: teeth.maxY))
                b.line(to: NSPoint(x: gx + w / 2 - 0.5, y: teeth.minY)); b.line(to: NSPoint(x: gx - w / 2 - 0.5, y: teeth.minY))
                b.close(); return b
            }
            NSBezierPath(rect: teeth).addClip()
            gold.set(); bar(1.1).fill()
            NSColor(srgbRed: 1, green: 0.97, blue: 0.80, alpha: 1).set(); bar(0.35).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        ink.set(); smile.lineWidth = 0.4; smile.lineJoinStyle = .round; smile.stroke()
        // A four-point sparkle riding the gleam, brightest mid-sweep.
        if let gx = gleamX {
            let glow = sin(sweep * .pi)
            let c = NSPoint(x: gx + 0.4, y: top + 0.1)
            let star = NSBezierPath()
            let long = 1.6 * glow + 0.4, short: CGFloat = 0.3
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4 + .pi / 2
                let r = i.isMultiple(of: 2) ? long : short
                let pt = NSPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                i == 0 ? star.move(to: pt) : star.line(to: pt)
            }
            star.close()
            NSGraphicsContext.saveGraphicsState()
            let shine = NSShadow(); shine.shadowColor = gold.withAlphaComponent(0.9)
            shine.shadowBlurRadius = 1.0; shine.shadowOffset = .zero; shine.set()
            NSColor(srgbRed: 1, green: 0.96, blue: 0.72, alpha: glow).set(); star.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    static func sweat(_ level: MacDaddyLevel, scale: CGFloat) {
        let count = level == .cool ? 0 : (level == .sweating ? 1 : 2)
        for d in dropSpots.prefix(count) {
            // A teardrop, point up, about 2.2pt wide and 3.2pt tall.
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: d.x, y: d.y + 1.9))
            drop.curve(to: NSPoint(x: d.x, y: d.y - 1.3), controlPoint1: NSPoint(x: d.x - 1.5, y: d.y + 0.1), controlPoint2: NSPoint(x: d.x - 1.3, y: d.y - 1.3))
            drop.curve(to: NSPoint(x: d.x, y: d.y + 1.9), controlPoint1: NSPoint(x: d.x + 1.3, y: d.y - 1.3), controlPoint2: NSPoint(x: d.x + 1.5, y: d.y + 0.1))
            drop.close()
            sweatBlue.set(); drop.fill()
            ink.set(); drop.lineWidth = scale >= 2 ? 0.5 : 0.7; drop.stroke()
            if scale >= 2 {
                NSColor.white.set()
                NSBezierPath(ovalIn: NSRect(x: d.x - 0.65, y: d.y - 0.55, width: 0.6, height: 0.8)).fill()
            }
        }
    }

    static func glint(scale: CGFloat) {
        let c = NSPoint(x: medallion.x + 1.1, y: medallion.y + 1.3)
        let star = NSBezierPath()
        let long: CGFloat = scale >= 2 ? 2.6 : 3.0, short: CGFloat = scale >= 2 ? 0.55 : 0.75
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4 + .pi / 2
            let r = i.isMultiple(of: 2) ? long : short
            let p = NSPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            i == 0 ? star.move(to: p) : star.line(to: p)
        }
        star.close()
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow(); glow.shadowColor = NSColor(srgbRed: 1, green: 0.95, blue: 0.6, alpha: 0.9)
        glow.shadowBlurRadius = 1.2; glow.shadowOffset = .zero; glow.set()
        NSColor.white.set(); star.fill()
        NSGraphicsContext.restoreGraphicsState()
        goldDark.set(); star.lineWidth = 0.3; star.stroke()
    }

    static func z(scale: CGFloat) {
        let z = NSBezierPath()
        z.move(to: NSPoint(x: 1.4, y: 20.9)); z.line(to: NSPoint(x: 4.4, y: 20.9))
        z.line(to: NSPoint(x: 1.4, y: 17.6)); z.line(to: NSPoint(x: 4.4, y: 17.6))
        z.lineCapStyle = .round; z.lineJoinStyle = .round
        // A dark keyline first so the z holds on a light bar and on the brim.
        ink.withAlphaComponent(0.55).set(); z.lineWidth = 1.9; z.stroke()
        zBlue.set(); z.lineWidth = 1.0; z.stroke()
    }
}

// MARK: - Lumen (KeyLight), illustrated

private struct LumenKey: Hashable { let art: ObjectIdentifier; let level: Int; let active: Bool }

extension CharacterIcon {
    private static var lumenCache: [LumenKey: NSImage] = [:]

    /// The canvas Lumen's keycap art is drawn on, and the glyph's size.
    public static let lumenCanvas = NSSize(width: 22, height: 22)

    /// Lumen, KeyLight's keycap in sunglasses, from its illustrated art (a 22x22pt
    /// canvas with the keycap centred, no rays). Eight sun rays are drawn around
    /// it in code and light clockwise from the top with the backlight `level`:
    /// any light at all lights the first, full lights all eight and brightens
    /// them. Off (level 0) or inactive, the keycap greys and the rays go.
    public static func lumen(keycap: NSImage, level: CGFloat, active: Bool = true) -> NSImage {
        let f = max(0, min(1, level.isFinite ? level : 0))
        let q = Int((f * 64).rounded())   // cache in 64ths
        let key = LumenKey(art: ObjectIdentifier(keycap), level: active ? q : 0, active: active)
        if let cached = lumenCache[key] { return cached }
        let on = active && f > 0
        let lit = on ? max(1, Int((f * 8).rounded())) : 0
        let image = IllustratedIcon.compose(size: lumenCanvas, base: keycap,
                                            desaturate: on ? 0 : 1, alpha: on ? 1 : 0.85) { _, scale in
            guard on else { return }
            LumenRays.draw(lit: lit, brightness: 0.6 + 0.4 * f, scale: scale)
        }
        lumenCache[key] = image
        return image
    }

    /// How many of Lumen's eight rays a level lights (0 when off or inactive).
    public static func lumenRaysLit(level: CGFloat, active: Bool = true) -> Int {
        let f = max(0, min(1, level.isFinite ? level : 0))
        return active && f > 0 ? max(1, Int((f * 8).rounded())) : 0
    }
}

enum LumenRays {
    /// The keycap's centre and half-extent on the 22pt canvas (see keylight-menubar art/make_art.py).
    static let center = NSPoint(x: 11, y: 11.2)
    static let half = NSSize(width: 6.0, height: 5.3)
    static let gold = NSColor(srgbRed: 1.00, green: 0.84, blue: 0.22, alpha: 1)
    static let orange = NSColor(srgbRed: 1.00, green: 0.60, blue: 0.10, alpha: 1)
    static let deepGold = NSColor(srgbRed: 1.00, green: 0.74, blue: 0.10, alpha: 1)
    static let edge = NSColor(srgbRed: 0.78, green: 0.42, blue: 0.02, alpha: 1)

    /// Ray `i` (0 = top, clockwise): a tapered spike from just off the keycap's edge outward.
    static func path(_ i: Int) -> NSBezierPath {
        let a = CGFloat(90 - i * 45) * .pi / 180
        let dx = cos(a), dy = sin(a)
        let diagonal = i % 2 == 1
        // Distance to the keycap's edge along this direction, then a small gap.
        let toEdge = min(abs(dx) > 0.001 ? half.width / abs(dx) : .infinity,
                         abs(dy) > 0.001 ? half.height / abs(dy) : .infinity)
        let inner = toEdge + (diagonal ? 0.2 : 0.7)
        let outer: CGFloat = diagonal ? 10.6 : (abs(dy) > 0.5 ? 10.5 : 10.3)
        let width: CGFloat = diagonal ? 2.0 : 2.4
        let px = -dy, py = dx
        let p = NSBezierPath()
        p.move(to: NSPoint(x: center.x + dx * inner + px * width / 2, y: center.y + dy * inner + py * width / 2))
        p.line(to: NSPoint(x: center.x + dx * outer, y: center.y + dy * outer))
        p.line(to: NSPoint(x: center.x + dx * inner - px * width / 2, y: center.y + dy * inner - py * width / 2))
        p.close()
        p.lineJoinStyle = .round
        return p
    }

    static func draw(lit: Int, brightness: CGFloat, scale: CGFloat) {
        for i in 0..<lit {
            let ray = path(i)
            NSGraphicsContext.saveGraphicsState()
            if scale >= 2 {
                let glow = NSShadow()
                glow.shadowColor = gold.withAlphaComponent(0.75 * brightness)
                glow.shadowBlurRadius = 1.4 * brightness
                glow.shadowOffset = .zero
                glow.set()
            }
            // At 1x a darker keyline smears into brown, so the ray is one deeper gold instead.
            let fill = scale >= 2 ? gold : deepGold
            fill.blended(withFraction: (1 - brightness) * 0.6, of: orange)?.withAlphaComponent(min(1, brightness + 0.15)).set()
            ray.fill()
            NSGraphicsContext.restoreGraphicsState()
            if scale >= 2 { edge.withAlphaComponent(0.8 * brightness).set(); ray.lineWidth = 0.35; ray.stroke() }
        }
    }
}
