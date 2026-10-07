// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Status-item glyphs made from illustrated raster art instead of paths.
///
/// A mascot drawn as a path has to become a pictogram at 22pt; a real
/// illustration shrunk to 22/44 pixels keeps its character (VidSnatch's logo is
/// the proof). The live part — a mood colour, a level — is then painted on top:
/// a masked region recoloured with its shading kept, the whole image greyed by
/// a fraction, and code overlays drawn in the same canvas.
///
/// StatusItemKit carries no art. Apps ship their PNGs (1x and @2x, canvas-sized)
/// in `Resources/bundle/`, load them with `IllustratedIcon.load(named:)` and pass
/// them in. Masks are greyscale PNGs of the same canvas: white = recolour.
public enum IllustratedIcon {
    /// Recolour the pixels under `mask` to `color`, keeping their light and shade.
    public struct Recolor {
        public let mask: NSImage
        public let color: NSColor
        /// 0…1: how far towards `color` the masked pixels go.
        public let strength: CGFloat
        public init(mask: NSImage, color: NSColor, strength: CGFloat = 1) {
            self.mask = mask; self.color = color; self.strength = strength
        }
    }

    /// The pixel densities every composed image carries.
    public static let scales: [CGFloat] = [1, 2]

    /// Compose a non-template image of `size` points with a 1x and a 2x
    /// representation. In order: `base` fills the canvas; the whole image is
    /// greyed by `desaturate` (0…1); each `recolor` is applied; the result is
    /// faded to `alpha`; then `overlay` draws on top in points (y up), told the
    /// pixel scale so it can skip detail that would smear at 1x.
    public static func compose(size: NSSize, base: NSImage, desaturate: CGFloat = 0,
                               recolor: [Recolor] = [], alpha: CGFloat = 1,
                               overlay: ((NSGraphicsContext, CGFloat) -> Void)? = nil) -> NSImage {
        let image = NSImage(size: size)
        for scale in scales {
            if let rep = render(size: size, scale: scale, base: base, desaturate: desaturate,
                                recolor: recolor, alpha: alpha, overlay: overlay) {
                image.addRepresentation(rep)
            }
        }
        image.isTemplate = false
        return image
    }

    /// Load `name.png` (+ `name@2x.png`) from a bundle as one multi-rep image.
    public static func load(named name: String, in bundle: Bundle = .main) -> NSImage? {
        guard let one = bundle.url(forResource: name, withExtension: "png") else { return nil }
        return load(oneX: one, twoX: bundle.url(forResource: name + "@2x", withExtension: "png"))
    }

    /// Load a 1x PNG and an optional 2x PNG as one image sized by the 1x file.
    public static func load(oneX: URL, twoX: URL?) -> NSImage? {
        guard let r1 = NSImageRep(contentsOf: oneX) else { return nil }
        let size = NSSize(width: r1.pixelsWide, height: r1.pixelsHigh)
        r1.size = size
        let image = NSImage(size: size)
        image.addRepresentation(r1)
        if let twoX, let r2 = NSImageRep(contentsOf: twoX) { r2.size = size; image.addRepresentation(r2) }
        return image
    }

    // MARK: Rendering

    /// The representation of `image` best suited to `pixels` wide: the smallest
    /// at least that wide, else the largest.
    static func cgImage(_ image: NSImage, pixelsWide pixels: Int) -> CGImage? {
        let reps = image.representations.sorted { $0.pixelsWide < $1.pixelsWide }
        let rep = reps.first { $0.pixelsWide >= pixels } ?? reps.last
        if let bitmap = rep as? NSBitmapImageRep, let cg = bitmap.cgImage { return cg }
        var rect = NSRect(origin: .zero, size: image.size)
        return rep?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            ?? image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private static func render(size: NSSize, scale: CGFloat, base: NSImage, desaturate: CGFloat,
                               recolor: [Recolor], alpha: CGFloat,
                               overlay: ((NSGraphicsContext, CGFloat) -> Void)?) -> NSBitmapImageRep? {
        let w = Int((size.width * scale).rounded()), h = Int((size.height * scale).rounded())
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.interpolationQuality = .high
        if let cg = cgImage(base, pixelsWide: w) { ctx.draw(cg, in: full) }

        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let d = max(0, min(1, desaturate))
        if d > 0 {
            for i in stride(from: 0, to: w * h * 4, by: 4) {
                let r = Double(px[i]), g = Double(px[i + 1]), b = Double(px[i + 2])
                let l = 0.299 * r + 0.587 * g + 0.114 * b
                px[i] = UInt8((r + (l - r) * d).rounded())
                px[i + 1] = UInt8((g + (l - g) * d).rounded())
                px[i + 2] = UInt8((b + (l - b) * d).rounded())
            }
        }
        for rc in recolor { apply(rc, to: px, w: w, h: h) }

        let a = max(0, min(1, alpha))
        if a < 1 {
            for i in 0..<(w * h * 4) { px[i] = UInt8((Double(px[i]) * a).rounded()) }
        }

        if let overlay {
            NSGraphicsContext.saveGraphicsState()
            let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = ns
            ctx.scaleBy(x: scale, y: scale)
            ns.shouldAntialias = true
            overlay(ns, scale)
            NSGraphicsContext.restoreGraphicsState()
        }

        guard let out = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: out)
        rep.size = size
        return rep
    }

    /// Hue-replace under the mask: each pixel becomes the target colour scaled by
    /// its own brightness relative to the masked region's average, so shading,
    /// highlights and the outline's anti-aliasing all carry over.
    private static func apply(_ rc: Recolor, to px: UnsafeMutablePointer<UInt8>, w: Int, h: Int) {
        guard let maskCG = cgImage(rc.mask, pixelsWide: w),
              let mctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                   space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let mdata = mctx.data else { return }
        mctx.setFillColor(gray: 0, alpha: 1); mctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        mctx.interpolationQuality = .high
        mctx.draw(maskCG, in: CGRect(x: 0, y: 0, width: w, height: h))
        let m = mdata.bindMemory(to: UInt8.self, capacity: w * h)
        // Both buffers are top-down rows of the same size, so index i matches.

        func lum(_ i: Int) -> Double { 0.299 * Double(px[i]) + 0.587 * Double(px[i + 1]) + 0.114 * Double(px[i + 2]) }
        var sum = 0.0, weight = 0.0
        for p in 0..<(w * h) where m[p] > 128 && px[p * 4 + 3] > 128 {
            sum += lum(p * 4) / Double(px[p * 4 + 3]); weight += 1
        }
        guard weight > 0 else { return }
        let ref = max(0.05, sum / weight)
        let c = rc.color.usingColorSpace(.sRGB) ?? rc.color
        let target = [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)]
        let strength = Double(max(0, min(1, rc.strength)))
        for p in 0..<(w * h) where m[p] > 0 {
            let i = p * 4
            let alpha = Double(px[i + 3])
            guard alpha > 0 else { continue }
            let k = Double(m[p]) / 255 * strength
            let ratio = min(1.6, (lum(i) / alpha) / ref)
            for ch in 0..<3 {
                // Past full brightness the channel spills towards white, like a highlight.
                let v = target[ch] * ratio
                let lifted = v > 1 ? 1 : v + max(0, ratio - 1) * (1 - v) * 0.5
                let tinted = min(1, lifted) * alpha
                px[i + ch] = UInt8(max(0, min(255, (Double(px[i + ch]) * (1 - k) + tinted * k).rounded())))
            }
        }
    }
}
