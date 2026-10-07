// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

// MARK: - Armonitor's lap of the screen

/// The loop Armonitor runs: out of his menu-bar slot, left along the menu
/// bar, down the left edge, along the bottom, up the right edge and back along
/// the bar to his slot — counterclockwise round the screen, with rounded
/// corners. Built as a dense polyline so a point at any distance along it is a
/// cheap lookup.
public struct LizardTrack {
    public let points: [NSPoint]
    /// Distance along the track to each point.
    public let distances: [CGFloat]
    public var length: CGFloat { distances.last ?? 0 }

    /// - Parameters:
    ///   - bounds: the area to run round (the overlay's bounds).
    ///   - start: where he leaves and comes home, on the top run.
    ///   - topY: the height of the top run (the middle of the menu bar).
    ///   - margin: how far the side and bottom runs keep from the edges.
    ///   - step: the spacing of the polyline's points.
    public init(bounds: NSRect, start: NSPoint, topY: CGFloat, margin: CGFloat = 16, corner: CGFloat = 36, step: CGFloat = 2) {
        let l = bounds.minX + margin, r = bounds.maxX - margin, b = bounds.minY + margin
        let r0 = min(corner, (topY - b) / 2, (r - l) / 2)
        var pts: [NSPoint] = [start]
        func line(to p: NSPoint) {
            let a = pts.last!, n = max(1, Int(hypot(p.x - a.x, p.y - a.y) / step))
            for k in 1...n { let f = CGFloat(k) / CGFloat(n); pts.append(NSPoint(x: a.x + (p.x - a.x) * f, y: a.y + (p.y - a.y) * f)) }
        }
        func arc(center c: NSPoint, from a0: CGFloat, to a1: CGFloat) {
            let n = max(4, Int(abs(a1 - a0) * r0 / step))
            for k in 1...n { let a = a0 + (a1 - a0) * CGFloat(k) / CGFloat(n); pts.append(NSPoint(x: c.x + r0 * cos(a), y: c.y + r0 * sin(a))) }
        }
        let sx = min(max(start.x, l + r0), r - r0)
        // Counterclockwise: left along the top, down, right along the bottom, up.
        line(to: NSPoint(x: l + r0, y: topY))
        arc(center: NSPoint(x: l + r0, y: topY - r0), from: .pi / 2, to: .pi)
        line(to: NSPoint(x: l, y: b + r0))
        arc(center: NSPoint(x: l + r0, y: b + r0), from: .pi, to: 1.5 * .pi)
        line(to: NSPoint(x: r - r0, y: b))
        arc(center: NSPoint(x: r - r0, y: b + r0), from: 1.5 * .pi, to: 2 * .pi)
        line(to: NSPoint(x: r, y: topY - r0))
        arc(center: NSPoint(x: r - r0, y: topY - r0), from: 0, to: .pi / 2)
        line(to: NSPoint(x: sx, y: topY))
        line(to: start)
        points = pts
        var d: [CGFloat] = [0]
        for k in 1..<pts.count { d.append(d[k - 1] + hypot(pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y)) }
        distances = d
    }

    /// The point `s` along the track and the unit direction of travel there.
    public func at(_ s: CGFloat) -> (point: NSPoint, direction: CGVector) {
        let s = max(0, min(length, s))
        var lo = 0, hi = distances.count - 1
        while hi - lo > 1 { let mid = (lo + hi) / 2; if distances[mid] <= s { lo = mid } else { hi = mid } }
        let a = points[lo], b = points[hi]
        let seg = max(0.0001, distances[hi] - distances[lo]), f = (s - distances[lo]) / seg
        let dx = b.x - a.x, dy = b.y - a.y, len = max(0.0001, hypot(dx, dy))
        return (NSPoint(x: a.x + dx * f, y: a.y + dy * f), CGVector(dx: dx / len, dy: dy / len))
    }
}

/// How Armonitor's body lies along the track: a serpentine wave fixed to the
/// ground, so every part of him passes through the same S-bends as his head
/// did — the way a snake or a legless lizard actually slithers — with the
/// wave dying away toward his snout so his head stays on course.
public enum LizardBody {
    /// Head to tail tip, in points.
    public static let length: CGFloat = 92
    static let wavelength: CGFloat = 46
    static let amplitude: CGFloat = 5.5
    /// Body width, by position from the head (0) to the tail tip (1).
    static func width(_ f: CGFloat) -> CGFloat {
        let stops: [(CGFloat, CGFloat)] = [(0, 8), (0.12, 9), (0.4, 7.5), (0.7, 4.5), (1, 1.4)]
        for i in 1..<stops.count where f <= stops[i].0 {
            let (f0, w0) = stops[i - 1], (f1, w1) = stops[i]
            return w0 + (w1 - w0) * (f - f0) / (f1 - f0)
        }
        return stops.last!.1
    }

    /// The point on his spine at track distance `s`, with his head at `head`.
    static func spine(_ track: LizardTrack, _ s: CGFloat, head: CGFloat) -> (NSPoint, CGVector) {
        let (p, dir) = track.at(s)
        let fromHead = (head - s) / length
        let swing = amplitude * min(1, fromHead * 4) * sin(2 * .pi * s / wavelength)
        let normal = CGVector(dx: -dir.dy, dy: dir.dx)
        return (NSPoint(x: p.x + normal.dx * swing, y: p.y + normal.dy * swing), dir)
    }

    /// Draws Armonitor with his head `head` along `track`. The parts of him
    /// before the start or past the end of the track are still in the icon,
    /// so they are not drawn: he pours out of the menu bar and back into it.
    public static func draw(on track: LizardTrack, head: CGFloat) {
        let G = MonitorLizardGlyph.self
        let first = max(0, head - length), last = min(track.length, head)
        guard last > first else { return }
        let steps = max(2, Int((last - first) / 1.5))
        var left: [NSPoint] = [], right: [NSPoint] = [], centre: [(NSPoint, CGFloat)] = []
        for k in 0...steps {
            let s = last - (last - first) * CGFloat(k) / CGFloat(steps)
            let (c, _) = spine(track, s, head: head)
            let (c2, _) = spine(track, s - 0.5, head: head)
            let tx = c.x - c2.x, ty = c.y - c2.y, tl = max(0.0001, hypot(tx, ty))
            let n = CGVector(dx: -ty / tl, dy: tx / tl), w = width((head - s) / length) / 2
            centre.append((c, s))
            left.append(NSPoint(x: c.x + n.dx * w, y: c.y + n.dy * w))
            right.append(NSPoint(x: c.x - n.dx * w, y: c.y - n.dy * w))
        }
        let body = NSBezierPath()
        body.move(to: left[0])
        for p in left.dropFirst() { body.line(to: p) }
        for p in right.reversed() { body.line(to: p) }
        body.close()
        body.lineJoinStyle = .round

        // Feet first, so the body covers their roots: two pairs, each foot
        // reaching forward then back as the body bends round it.
        for (at, phase) in [(CGFloat(0.2), CGFloat(0)), (0.55, .pi)] {
            let s = head - length * at
            guard s > first, s < last else { continue }
            let (c, dir) = spine(track, s, head: head)
            let n = CGVector(dx: -dir.dy, dy: dir.dx)
            let reach = sin(2 * .pi * s / LizardBody.wavelength + phase) * 2.5
            for side in [CGFloat(1), -1] {
                let w = width(at) / 2 + 1.0
                let f = NSPoint(x: c.x + n.dx * w * side + dir.dx * reach * side, y: c.y + n.dy * w * side + dir.dy * reach * side)
                let foot = NSBezierPath(ovalIn: NSRect(x: f.x - 1.9, y: f.y - 1.9, width: 3.8, height: 3.8))
                NSGradient(starting: G.skin.light, ending: G.skin.dark)?.draw(in: foot, angle: -70)
                G.ink.set(); foot.lineWidth = 0.8; foot.stroke()
            }
        }

        NSGradient(starting: G.skin.light, ending: G.skin.dark)?.draw(in: body, angle: -70)
        NSGraphicsContext.saveGraphicsState()
        body.addClip()
        G.spot.set()
        // Leopard spots, fixed to his skin rather than the ground: one every
        // 7pt of body, alternating sides.
        for (c, s) in centre {
            let along = head - s
            guard along > 8, along.truncatingRemainder(dividingBy: 7) < 1.5 else { continue }
            let d = max(1.4, width(along / length) * 0.4)
            let off: CGFloat = Int(along / 7).isMultiple(of: 2) ? 0.9 : -0.9
            NSBezierPath(ovalIn: NSRect(x: c.x - d / 2 + off, y: c.y - d / 2 - off, width: d, height: d)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        G.ink.set(); body.lineWidth = 1.0; body.stroke()

        // The head, on the front of the body and facing the way he is going.
        guard head <= track.length, head > 0 else { return }
        let (h, _) = spine(track, head, head: head)
        let (h2, _) = spine(track, head - 2, head: head)
        let angle = atan2(h.y - h2.y, h.x - h2.x)
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform(); t.translateX(by: h.x, yBy: h.y); t.rotate(byRadians: angle); t.concat()
        // Pointing along +x: a rounded wedge, broad at the cheeks.
        let skull = NSBezierPath()
        skull.move(to: NSPoint(x: -3, y: 4.6))
        skull.curve(to: NSPoint(x: 9.5, y: 0), controlPoint1: NSPoint(x: 4, y: 5.6), controlPoint2: NSPoint(x: 9.5, y: 3.2))
        skull.curve(to: NSPoint(x: -3, y: -4.6), controlPoint1: NSPoint(x: 9.5, y: -3.2), controlPoint2: NSPoint(x: 4, y: -5.6))
        skull.close()
        NSGradient(starting: G.skin.light, ending: G.skin.dark)?.draw(in: skull, angle: -70)
        G.ink.set(); skull.lineWidth = 1.0; skull.stroke()
        // Eyes on both sides, big and round like his portrait, glancing ahead.
        for side in [CGFloat(1), -1] {
            let e = NSPoint(x: 3.2, y: 2.9 * side)
            let white = NSBezierPath(ovalIn: NSRect(x: e.x - 1.9, y: e.y - 1.9, width: 3.8, height: 3.8))
            NSColor.white.set(); white.fill()
            G.ink.set(); white.lineWidth = 0.6; white.stroke()
            NSBezierPath(ovalIn: NSRect(x: e.x - 0.5, y: e.y - 1.1, width: 2.0, height: 2.2)).fill()
            NSColor.white.set(); NSBezierPath(ovalIn: NSRect(x: e.x + 0.4, y: e.y + 0.2, width: 0.7, height: 0.7)).fill()
        }
        // Nostrils.
        G.ink.set()
        for side in [CGFloat(1), -1] { NSBezierPath(ovalIn: NSRect(x: 8.0, y: 0.9 * side - 0.3, width: 0.6, height: 0.6)).fill() }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The area `draw` may paint, for redrawing only what changed.
    static func bounds(on track: LizardTrack, head: CGFloat) -> NSRect {
        let first = max(0, head - length), last = min(track.length, head)
        guard last > first else { return .zero }
        var r = NSRect.null
        var s = first
        while s <= last { let p = track.at(s).point; r = r.union(NSRect(x: p.x, y: p.y, width: 0, height: 0)); s += 6 }
        r = r.union(NSRect(origin: track.at(last).point, size: .zero))
        return r.insetBy(dx: -(amplitude + 18), dy: -(amplitude + 18))
    }
}

/// Runs Armonitor's lap: a click-through overlay over the whole screen, where
/// he leaves his slot in the menu bar, slithers counterclockwise round the
/// screen, and climbs back in. Show the icon without him (`lizard: false`)
/// while `isRunning`.
public final class MonitorLizardLap {
    public static let duration: TimeInterval = 3.4

    private var window: NSWindow?
    private var animation: IconAnimation?
    public var isRunning: Bool { animation?.isRunning ?? false }

    public init() {}

    /// - Parameters:
    ///   - slot: the status item's frame in screen coordinates; he leaves from
    ///     and returns to its left side.
    ///   - screen: the screen whose menu bar holds the slot.
    public func run(from slot: NSRect, on screen: NSScreen, completion: @escaping () -> Void) {
        guard !isRunning else { return }
        let frame = screen.frame
        let w = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.isOpaque = false
        w.hasShadow = false
        w.backgroundColor = .clear
        w.ignoresMouseEvents = true
        w.canHide = false
        w.hidesOnDeactivate = false
        w.animationBehavior = .none
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let topY = slot.midY - frame.minY
        let start = NSPoint(x: slot.minX + 6 - frame.minX, y: topY)
        let view = LapView(frame: NSRect(origin: .zero, size: frame.size),
                           track: LizardTrack(bounds: NSRect(origin: .zero, size: frame.size), start: start, topY: topY))
        w.contentView = view
        w.setFrame(frame, display: false)
        w.orderFrontRegardless()
        window = w

        let travel = view.track.length + LizardBody.length
        let anim = IconAnimation(duration: Self.duration, frame: { t in
            // Eased in and out, so he sets off and arrives rather than
            // starting and stopping dead.
            let x = t / Self.duration
            view.head = travel * CGFloat(0.5 - 0.5 * cos(.pi * x))
        }, completion: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
            self?.animation = nil
            completion()
        })
        animation = anim
        anim.start()
    }

    private final class LapView: NSView {
        let track: LizardTrack
        var head: CGFloat = 0 {
            didSet {
                let now = LizardBody.bounds(on: track, head: head)
                setNeedsDisplay(now.union(drawn))
                drawn = now
            }
        }
        private var drawn = NSRect.zero

        init(frame: NSRect, track: LizardTrack) {
            self.track = track
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override var isOpaque: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.clear.set(); dirtyRect.fill(using: .copy)
            NSGraphicsContext.current?.shouldAntialias = true
            LizardBody.draw(on: track, head: head)
        }
    }
}
