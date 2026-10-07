// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// The user's icon choices — shape and colour — persisted in the app's own
/// defaults domain.
///
/// Plain keys are safe without namespacing: `UserDefaults.standard` is already
/// per-app, so two apps in the suite cannot collide.
public final class MeterAppearance {
    public static let styleKey = "MeterStyle"
    public static let colorKey = "MeterColorHex"

    private let defaults: UserDefaults
    private let defaultStyle: MeterStyle
    private let defaultColor: NSColor

    /// - Parameter defaultColor: defaults to the Green *preset*, not
    ///   `NSColor.systemGreen`. The system colour is dynamic and resolves to a
    ///   different hex in dark mode, so it would never match a preset and a
    ///   fresh install would show "Custom Colour…" ticked with nothing having
    ///   been customised.
    public init(defaults: UserDefaults = .standard,
                defaultStyle: MeterStyle = .arc,
                defaultColor: NSColor = MeterColor.presets[0].color) {
        self.defaults = defaults
        self.defaultStyle = defaultStyle
        self.defaultColor = defaultColor
    }

    public var style: MeterStyle {
        get { MeterStyle.from(defaults.string(forKey: Self.styleKey), default: defaultStyle) }
        set { defaults.set(newValue.rawValue, forKey: Self.styleKey) }
    }

    /// The resting colour. Apps that escalate on severity should treat this as
    /// the calm end of the ramp and keep their warning colours: a meter that
    /// looks identical at 5% and 95% has stopped saying the thing it exists to
    /// say.
    public var color: NSColor {
        get {
            guard let hex = defaults.string(forKey: Self.colorKey),
                  let parsed = MeterColor.color(fromHex: hex) else { return defaultColor }
            return parsed
        }
        set { defaults.set(MeterColor.hex(from: newValue), forKey: Self.colorKey) }
    }

    public var colorHex: String { MeterColor.hex(from: color) }

    public func image(fraction: CGFloat) -> NSImage {
        MeterIcon.image(style: style, fraction: fraction, color: color)
    }
}
