// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

extension CharacterIcon {
    /// MacRecorder: the mascot's blue camcorder, drawn in the caterpillar's storybook
    /// style (ink outlines, top-left-lit shading). Two eyes over a big front lens for a
    /// snout, a yellow viewfinder and a tally light on top, a grey lens hood out the
    /// right side. Recording lights it up: the tally glows red, the lens glass turns
    /// red, and the eyes are wide open. Idle, the tally is a dark socket, the glass is
    /// dark and the eyes are half-lidded. 24x22pt either way, so the bar never shifts.
    public static func camcorder(recording: Bool) -> NSImage {
        canvas(width: 24, height: 22) { ctx in
            let ink = NSColor(red: 0.08, green: 0.12, blue: 0.24, alpha: 1)
            let blueLight = NSColor(red: 0.56, green: 0.80, blue: 1.00, alpha: 1)
            let blueDark = NSColor(red: 0.13, green: 0.42, blue: 0.82, alpha: 1)
            let greyLight = NSColor(red: 0.80, green: 0.83, blue: 0.88, alpha: 1)
            let greyDark = NSColor(red: 0.36, green: 0.40, blue: 0.48, alpha: 1)
            let red = NSColor(red: 1.00, green: 0.18, blue: 0.14, alpha: 1)
            // Fill with a top-left-lit gradient, then outline in ink.
            func shaded(_ p: NSBezierPath, _ light: NSColor, _ dark: NSColor, _ w: CGFloat = 0.7) {
                NSGradient(starting: light, ending: dark)?.draw(in: p, angle: -60)
                ink.set(); p.lineWidth = w; p.stroke()
            }
            func oval(_ c: NSPoint, _ rx: CGFloat, _ ry: CGFloat) -> NSBezierPath {
                NSBezierPath(ovalIn: NSRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
            }

            // Recording glow behind the tally, drawn first so the body sits over its foot.
            let tally = NSPoint(x: 15.2, y: 18.6)
            if recording {
                NSGradient(colors: [red.withAlphaComponent(0.9), red.withAlphaComponent(0)])?
                    .draw(in: oval(tally, 3.4, 3.4), relativeCenterPosition: .zero)
            }
            // Lens hood out the right side: a flared grey barrel with a dark mouth.
            let hood = NSBezierPath()
            hood.move(to: NSPoint(x: 17, y: 6.4)); hood.line(to: NSPoint(x: 22, y: 4.6))
            hood.curve(to: NSPoint(x: 22, y: 13.4), controlPoint1: NSPoint(x: 23.9, y: 6.2), controlPoint2: NSPoint(x: 23.9, y: 11.8))
            hood.line(to: NSPoint(x: 17, y: 11.6)); hood.close()
            shaded(hood, greyLight, greyDark)
            ctx.saveGraphicsState(); hood.addClip()
            NSColor(red: 0.20, green: 0.23, blue: 0.30, alpha: 1).set(); oval(NSPoint(x: 23, y: 9), 1.3, 4.3).fill()
            ctx.restoreGraphicsState()
            ink.set(); hood.stroke()
            // Viewfinder: a yellow block on top, left of centre.
            let finder = NSBezierPath(roundedRect: NSRect(x: 3.6, y: 14.6, width: 6.4, height: 3.8), xRadius: 1.1, yRadius: 1.1)
            shaded(finder, NSColor(red: 1, green: 0.92, blue: 0.45, alpha: 1), NSColor(red: 0.92, green: 0.64, blue: 0.05, alpha: 1))
            // Tally light on a short grey post.
            let post = NSBezierPath(rect: NSRect(x: 14.1, y: 15.6, width: 2.2, height: 2))
            shaded(post, greyLight, greyDark, 0.5)
            // Body: a chunky rounded box.
            let body = NSBezierPath(roundedRect: NSRect(x: 1, y: 1.4, width: 17.6, height: 15), xRadius: 3.4, yRadius: 3.4)
            shaded(body, blueLight, blueDark, 0.8)
            // gloss along the lit top-left edge
            let gloss = NSBezierPath()
            gloss.appendArc(withCenter: NSPoint(x: 4.6, y: 12.6), radius: 2.6, startAngle: 95, endAngle: 165, clockwise: false)
            gloss.lineWidth = 0.8; gloss.lineCapStyle = .round
            NSColor(white: 1, alpha: 0.6).set(); gloss.stroke()
            // Tally bulb: red with a glint while recording, a dark socket otherwise.
            let bulb = oval(tally, 2.4, 2.4)
            if recording {
                NSGradient(colors: [NSColor(red: 1, green: 0.62, blue: 0.55, alpha: 1), red, NSColor(red: 0.62, green: 0.05, blue: 0.05, alpha: 1)])?
                    .draw(in: bulb, relativeCenterPosition: NSPoint(x: -0.35, y: 0.35))
            } else {
                NSGradient(starting: NSColor(white: 0.45, alpha: 1), ending: NSColor(white: 0.16, alpha: 1))?.draw(in: bulb, angle: -60)
            }
            ink.set(); bulb.lineWidth = 0.6; bulb.stroke()
            NSColor(white: 1, alpha: recording ? 0.95 : 0.5).set(); oval(NSPoint(x: tally.x - 0.7, y: tally.y + 0.7), 0.55, 0.55).fill()

            // Eyes: whites, pupils glancing towards the lens hood, a glint each.
            // Idle, a blue lid covers the top half: dozing between takes.
            for cx in [CGFloat(5.9), 12.5] {
                let c = NSPoint(x: cx, y: 11.6)
                let eye = oval(c, 2.7, 3.1)
                NSColor.white.set(); eye.fill()
                ink.set(); oval(NSPoint(x: c.x + 0.5, y: c.y - 0.4), 1.45, 1.8).fill()
                NSColor.white.set(); oval(NSPoint(x: c.x + 1.0, y: c.y + 0.4), 0.5, 0.5).fill()
                if !recording {
                    ctx.saveGraphicsState(); eye.addClip()
                    let lid = NSRect(x: c.x - 3, y: c.y + 0.1, width: 6, height: 4)
                    NSGradient(starting: blueLight, ending: blueDark)?.draw(in: lid, angle: -90)
                    ctx.restoreGraphicsState()
                    let edge = NSBezierPath(); edge.move(to: NSPoint(x: c.x - 2.7, y: c.y + 0.1)); edge.line(to: NSPoint(x: c.x + 2.7, y: c.y + 0.1))
                    ink.set(); edge.lineWidth = 0.6; edge.stroke()
                }
                ink.set(); eye.lineWidth = 0.6; eye.stroke()
            }

            // Lens for a snout: grey barrel ring, glass inside (red and glowing while
            // recording, deep blue-black idle), a crescent glint.
            let lc = NSPoint(x: 9.2, y: 5.3)
            shaded(oval(lc, 3.7, 3.7), greyLight, greyDark, 0.7)
            let glass = oval(lc, 2.5, 2.5)
            NSGradient(colors: [NSColor(red: 0.30, green: 0.40, blue: 0.62, alpha: 1), NSColor(red: 0.06, green: 0.08, blue: 0.18, alpha: 1)])?
                .draw(in: glass, relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))
            if recording {   // the record light caught in the glass: a red iris ring
                let iris = oval(lc, 1.55, 1.55); iris.lineWidth = 0.9
                red.set(); iris.stroke()
            }
            ink.set(); glass.lineWidth = 0.5; glass.stroke()
            NSColor(white: 1, alpha: 0.9).set(); oval(NSPoint(x: lc.x - 0.9, y: lc.y + 0.9), 0.7, 0.7).fill()
        }
    }
}
