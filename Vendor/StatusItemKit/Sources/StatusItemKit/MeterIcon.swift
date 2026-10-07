// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Custom-drawn, full-color (non-template) status-item glyphs. The pct-driven
/// meters (gauge/arc/pie/wedge) take a 0...1 fraction and a color; `dot` is a
/// plain filled circle for discrete-state apps. Ported from ProcessMonitor.
public enum MeterIcon {
    private static let side: CGFloat = 18

    private static func image(_ draw: @escaping (NSRect) -> Void) -> NSImage {
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            draw(rect); return true
        }
        img.isTemplate = false
        return img
    }

    private static func clamp(_ f: CGFloat) -> CGFloat { max(0, min(1, f)) }

    public static func dot(color: NSColor, diameter: CGFloat = 10) -> NSImage {
        let pad: CGFloat = 4
        let s = diameter + pad * 2
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            color.set()
            NSBezierPath(ovalIn: NSRect(x: pad, y: pad, width: diameter, height: diameter)).fill()
            return true
        }
        img.isTemplate = false
        return img
    }

    /// An SF Symbol inked in a single flat colour, on the same 18pt canvas as
    /// the meters, for discrete-state apps that want a *recognisable* glyph
    /// rather than a dot. Non-template on purpose: the colour is the state.
    ///
    /// Falls back to a `dot` of the same colour if the symbol name is unknown to
    /// this macOS, so an app never launches with an empty status item.
    public static func symbol(
        _ name: String,
        color: NSColor,
        pointSize: CGFloat = 12,
        weight: NSFont.Weight = .semibold
    ) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        else { return dot(color: color) }
        let glyph = base.size
        return image { rect in
            let origin = NSPoint(x: (rect.width - glyph.width) / 2, y: (rect.height - glyph.height) / 2)
            let frame = NSRect(origin: origin, size: glyph)
            base.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
            // Recolour: keep the glyph's alpha, replace its ink.
            color.set()
            frame.fill(using: .sourceAtop)
        }
    }

    /// Speedometer: needle angle proportional to fraction over a ~250° arc.
    public static func gauge(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY - 1.5)
            let radius: CGFloat = 6.5
            let startAngle: CGFloat = 215
            let endAngle: CGFloat = -35
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            track.lineWidth = 2.4
            track.lineCapStyle = .round
            color.withAlphaComponent(0.28).set()
            track.stroke()
            color.set()
            let needleAngle = (startAngle + (endAngle - startAngle) * frac) * .pi / 180
            let tip = NSPoint(x: center.x + cos(needleAngle) * (radius - 0.3),
                              y: center.y + sin(needleAngle) * (radius - 0.3))
            let needle = NSBezierPath()
            needle.move(to: center)
            needle.line(to: tip)
            needle.lineWidth = 2.8
            needle.lineCapStyle = .round
            needle.stroke()
            let hubR: CGFloat = 2.3
            NSBezierPath(ovalIn: NSRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)).fill()
        }
    }

    /// Radial arc: faint full track + bold arc filled to fraction.
    public static func arc(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY - 1.5)
            let radius: CGFloat = 6.5
            let startAngle: CGFloat = 215
            let endAngle: CGFloat = -35
            let lineWidth: CGFloat = 3.4
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            track.lineWidth = lineWidth
            track.lineCapStyle = .round
            color.withAlphaComponent(0.28).set()
            track.stroke()
            if frac > 0 {
                let fillEnd = startAngle + (endAngle - startAngle) * frac
                let fill = NSBezierPath()
                fill.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: fillEnd, clockwise: true)
                fill.lineWidth = lineWidth
                fill.lineCapStyle = .round
                color.set()
                fill.stroke()
            }
        }
    }

    /// Pie: full circle outline = cap; filled wedge = fraction in use.
    public static func pie(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7
            color.set()
            let circle = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            circle.lineWidth = 2.2
            circle.stroke()
            if frac > 0 {
                let wedgeRadius = radius - 1.4
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: wedgeRadius, startAngle: 90, endAngle: 90 - 360 * frac, clockwise: true)
                wedge.close()
                wedge.fill()
            }
        }
    }

    /// Pie variant: solid wedge = fraction; faint full disk = remaining cap.
    public static func wedge(fraction: CGFloat, color: NSColor) -> NSImage {
        let frac = clamp(fraction)
        return image { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.5
            color.withAlphaComponent(0.28).set()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
            if frac > 0 {
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * frac, clockwise: true)
                wedge.close()
                color.set()
                wedge.fill()
            }
        }
    }
}
