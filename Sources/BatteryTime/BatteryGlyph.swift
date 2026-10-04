// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Fill colour override of the battery glyph. `.none` adapts automatically.
public enum BatteryFill {
    case none, yellow, blue, red
}

/// The menu-bar battery glyph:
/// - Charging: green battery + centered lightning bolt ⚡
/// - Plugged & not charging (e.g. 80% bypass / limit): green battery + centered white plug 🔌 (matching macOS Battery UI)
/// - On battery: standard battery fill without icons (red when <= 20%)
public enum BatteryGlyph {
    public static func image(
        pct: Int,
        charging: Bool,
        plugged: Bool = false,
        lead: String,
        trailing: String,
        ink: NSColor,
        fill fillKind: BatteryFill
    ) -> NSImage {
        let batteryPct = max(0, min(100, pct))
        let isGreenFill = plugged && fillKind == .none

        // Fill color
        let fill: NSColor = {
            if isGreenFill { return .systemGreen }
            switch fillKind {
            case .yellow: return .systemYellow
            case .blue:   return .systemBlue
            case .red:    return .systemRed
            case .none:   return ink
            }
        }()

        // Text formatting (balanced size, matching macOS status bar standard)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .regular)
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ink,
            .kern: 0.15
        ]
        let leadStr = NSAttributedString(string: lead, attributes: textAttrs)
        let textStr = NSAttributedString(string: trailing, attributes: textAttrs)
        let leadSize = lead.isEmpty ? NSSize.zero : leadStr.size()
        let textSize = trailing.isEmpty ? NSSize.zero : textStr.size()
        let fontH = ceil(font.ascender - font.descender)

        // Battery metrics (balanced & prominent, slightly larger for clear visibility)
        let bodyW: CGFloat = 21.0, bodyH: CGFloat = 11.5, nubW: CGFloat = 1.6
        let radius: CGFloat = 3.0, lineW: CGFloat = 1.0, fillInset: CGFloat = 1.3, gap: CGFloat = 2.8

        let glyphW: CGFloat = bodyW + nubW
        let leadGap: CGFloat = (!lead.isEmpty && glyphW > 0) ? gap : 0
        let trailGap: CGFloat = (!trailing.isEmpty && glyphW > 0) ? gap : 0
        let width = max(1, ceil(leadSize.width + leadGap + glyphW + trailGap + textSize.width))
        let height = max(1, ceil(max(fontH, leadSize.height, textSize.height, bodyH + 3.0)))

        // Large, bold lightning bolt
        func boltPath(in rect: NSRect) -> NSBezierPath {
            let pts: [(CGFloat, CGFloat)] = [
                (0.55, 1.00),
                (0.12, 0.46),
                (0.48, 0.46),
                (0.38, 0.00),
                (0.88, 0.58),
                (0.55, 0.58)
            ]
            let xs = pts.map { $0.0 }, ys = pts.map { $0.1 }
            let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
            let sw = rect.width / (maxX - minX), sh = rect.height / (maxY - minY)
            let p = NSBezierPath()
            for (i, pt) in pts.enumerated() {
                let x = rect.minX + (pt.0 - minX) * sw, y = rect.minY + (pt.1 - minY) * sh
                if i == 0 { p.move(to: NSPoint(x: x, y: y)) } else { p.line(to: NSPoint(x: x, y: y)) }
            }
            p.close()
            return p
        }

        func drawProminentPlug(ctx: CGContext, cx: CGFloat, cy: CGFloat) {
            let pw: CGFloat = 6.6
            let ph: CGFloat = 4.9
            let prongW: CGFloat = 1.1
            let prongH: CGFloat = 3.0
            let cordW: CGFloat = 1.3
            let cordH: CGFloat = 3.5

            let bRect = NSRect(x: cx - pw / 2, y: cy - ph / 2, width: pw, height: ph)
            let pr1 = NSRect(x: cx - pw / 2 + 0.9, y: bRect.maxY, width: prongW, height: prongH)
            let pr2 = NSRect(x: cx + pw / 2 - 0.9 - prongW, y: bRect.maxY, width: prongW, height: prongH)
            let cRect = NSRect(x: cx - cordW / 2, y: bRect.minY - cordH, width: cordW, height: cordH)

            // --- 1. KNOCKOUT CUTOUT MASK: Cut green bar & bottom border with pure transparency ---
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            let m: CGFloat = 1.2 // 1.2pt breathing cutout

            let cordMask = NSRect(x: cx - cordW / 2 - m, y: cRect.minY - m, width: cordW + 2 * m, height: cordH + 2 * m)
            NSBezierPath(rect: cordMask).fill()

            let bMask = NSRect(x: cx - pw / 2 - m, y: bRect.minY - m, width: pw + 2 * m, height: ph + 2 * m)
            NSBezierPath(roundedRect: bMask, xRadius: 1.8, yRadius: 1.8).fill()

            let pr1Mask = NSRect(x: pr1.minX - m, y: pr1.minY - m, width: prongW + 2 * m, height: prongH + 2 * m)
            let pr2Mask = NSRect(x: pr2.minX - m, y: pr2.minY - m, width: prongW + 2 * m, height: prongH + 2 * m)
            NSBezierPath(roundedRect: pr1Mask, xRadius: 1.0, yRadius: 1.0).fill()
            NSBezierPath(roundedRect: pr2Mask, xRadius: 1.0, yRadius: 1.0).fill()
            ctx.restoreGState()

            // --- 2. DRAW SOLID FLOATING PLUG ---
            ink.setFill()
            NSBezierPath(rect: cRect).fill()
            NSBezierPath(roundedRect: bRect, xRadius: 1.1, yRadius: 1.1).fill()
            NSBezierPath(roundedRect: pr1, xRadius: 0.5, yRadius: 0.5).fill()
            NSBezierPath(roundedRect: pr2, xRadius: 0.5, yRadius: 0.5).fill()
        }

        func drawBattery(ctx: CGContext, pctValue: Int, originX: CGFloat) {
            let by = (height - bodyH) / 2
            let bodyRect = NSRect(x: originX + lineW/2, y: by + lineW/2, width: bodyW - lineW, height: bodyH - lineW)
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
            bodyPath.lineWidth = lineW

            // Refined semi-transparent shell (matches 231-0.webp)
            let shellColor = ink.withAlphaComponent(0.42)
            shellColor.setStroke()
            bodyPath.stroke()

            // Triangular positive terminal (nub, identical to competitor)
            let nubX = originX + bodyW - lineW
            let nubCY = height / 2
            let nubPath = NSBezierPath()
            nubPath.move(to: NSPoint(x: nubX, y: nubCY - 2.2))
            nubPath.line(to: NSPoint(x: nubX + 1.6, y: nubCY))
            nubPath.line(to: NSPoint(x: nubX, y: nubCY + 2.2))
            nubPath.close()
            shellColor.setFill()
            nubPath.fill()

            // Level fill
            let innerW = bodyRect.width - 2 * fillInset
            let fillW = max(0, innerW * CGFloat(pctValue) / 100.0)
            let fillRect = NSRect(x: bodyRect.minX + fillInset, y: bodyRect.minY + fillInset, width: fillW, height: bodyRect.height - 2 * fillInset)
            if fillW > 0 {
                fill.setFill()
                NSBezierPath(roundedRect: fillRect, xRadius: 1.2, yRadius: 1.2).fill()
            }

            let cx = originX + bodyW / 2, cy = height / 2

            if charging {
                // ⚡ Prominent Lightning bolt with breathing knockout mask
                let boltH: CGFloat = 10.2
                let boltW: CGFloat = 6.0
                let r = NSRect(x: cx - boltW / 2, y: cy - boltH / 2, width: boltW, height: boltH)
                
                ctx.saveGState()
                ctx.setBlendMode(.clear)
                let maskR = r.insetBy(dx: -1.0, dy: -1.0)
                boltPath(in: maskR).fill()
                ctx.restoreGState()

                ink.setFill()
                boltPath(in: r).fill()
            } else if plugged {
                // 🔌 Prominent Floating Power Plug with knockout cutout
                drawProminentPlug(ctx: ctx, cx: cx, cy: cy)
            }
        }

        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            var x: CGFloat = 0
            if !lead.isEmpty {
                leadStr.draw(at: NSPoint(x: x, y: (height - leadSize.height) / 2))
                x += leadSize.width + leadGap
            }
            drawBattery(ctx: ctx, pctValue: batteryPct, originX: x)
            x += glyphW + trailGap
            if !trailing.isEmpty {
                textStr.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2))
            }
            return true
        }

        // Plugged or colored fills are not monochrome templates
        img.isTemplate = !plugged && (fillKind == .none)
        return img
    }
}
