// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// The version `scripts/make-app.sh` stamped into the bundle from the nearest
/// `vX.Y.Z` tag, so two builds can always be told apart from the menu.
public enum AppVersion {
    /// Info.plist key holding the full semver string.
    public static let infoKey = "StatusItemKitVersion"

    /// "1.2.0" for a clean build of a tagged commit; "1.2.0+3.gabc1234" for a
    /// build three commits past it, with ".dirty" appended when the checkout
    /// had uncommitted changes. Falls back to CFBundleShortVersionString for a
    /// bundle assembled some other way.
    public static var string: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return info[infoKey] as? String
            ?? info["CFBundleShortVersionString"] as? String
            ?? StatusItemLanguage.text("未知版本", "Unknown version")
    }

    /// Short version for clean display (e.g. "1.1.1").
    public static var shortString: String {
        let full = string
        if let base = full.split(separator: "+").first, !base.isEmpty {
            return String(base)
        }
        return full
    }

    /// A disabled "Version …" row, for the foot of an app's menu.
    public static func menuItem() -> NSMenuItem {
        let item = NSMenuItem(title: StatusItemLanguage.text("版本 \(shortString)", "Version \(shortString)"), action: nil, keyEquivalent: "")
        item.toolTip = string
        item.isEnabled = false
        return item
    }
}
