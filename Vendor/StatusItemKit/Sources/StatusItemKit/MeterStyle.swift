// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Which shape draws a status-item meter.
///
/// `dot` is included because some apps show state rather than proportion (a
/// VPN's connected/blocked/off), but it ignores the fraction entirely. Apps
/// offering a user-facing picker for a *percentage* should pass
/// `MeterStyle.proportional`, which excludes it — a meter that cannot show a
/// proportion cannot do a percentage icon's job.
public enum MeterStyle: String, CaseIterable, Equatable, Sendable {
    case arc
    case gauge
    case pie
    case wedge
    case dot
    /// The app's own mascot pictogram (see `CharacterIcon`). The app draws it;
    /// `MeterIcon.image` falls back to an arc for callers that do not.
    case character

    /// Every style that actually varies with the fraction.
    public static let proportional: [MeterStyle] = [.arc, .gauge, .pie, .wedge]

    public var title: String {
        switch self {
        case .arc: return "Arc"
        case .gauge: return "Gauge"
        case .pie: return "Pie"
        case .wedge: return "Wedge"
        case .dot: return "Dot"
        case .character: return "Character"
        }
    }

    /// Unknown values fall back rather than trapping: a persisted preference
    /// outlives the build that wrote it, and a style removed in a later version
    /// must not leave an app unable to draw an icon at all.
    public static func from(_ raw: String?, default fallback: MeterStyle = .arc) -> MeterStyle {
        guard let raw, let style = MeterStyle(rawValue: raw) else { return fallback }
        return style
    }
}

public extension MeterIcon {
    /// Draw whichever style is chosen. Saves every caller the same switch.
    static func image(style: MeterStyle, fraction: CGFloat, color: NSColor) -> NSImage {
        switch style {
        case .arc:   return arc(fraction: fraction, color: color)
        case .gauge: return gauge(fraction: fraction, color: color)
        case .pie:   return pie(fraction: fraction, color: color)
        case .wedge: return wedge(fraction: fraction, color: color)
        case .dot:   return dot(color: color)
        case .character: return arc(fraction: fraction, color: color)
        }
    }
}
