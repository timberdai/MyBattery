// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import ServiceManagement

/// Start-at-Login via SMAppService.mainApp (registration is bundle-ID based and
/// requires the app to live in /Applications or ~/Applications).
public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister, surfacing failure to the caller. Alert-free, so
    /// it is also usable from a headless one-shot invocation.
    ///
    /// Setting the state it is already in is a no-op rather than an error.
    public static func setEnabled(_ enabled: Bool) throws {
        let svc = SMAppService.mainApp
        guard (svc.status == .enabled) != enabled else { return }
        if enabled {
            try svc.register()
        } else {
            try svc.unregister()
        }
    }

    /// Toggle registration. On failure (most often: app not in /Applications),
    /// shows a warning alert.
    public static func toggle() {
        do {
            try setEnabled(!isEnabled)
        } catch {
            let alert = NSAlert()
            alert.messageText = StatusItemLanguage.text("无法切换开机自启动设置", "Could not change Launch at Login")
            alert.informativeText = error.localizedDescription + "\n\n" + StatusItemLanguage.text(
                "macOS 要求应用程序必须位于 /Applications 或 ~/Applications 目录下才能正常工作。请将应用移至上述目录后再试。",
                "Move the app to /Applications or ~/Applications, then try again.")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
