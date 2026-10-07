// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation
import UserNotifications

/// Thin wrapper over UNUserNotificationCenter. Requires the host to be a signed
/// bundle with a bundle identifier, or requests are silently dropped.
public final class Notifier {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "statusitemkit.\(title).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }
}
