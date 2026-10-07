// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// The protocol a menu-bar manager uses to ask cooperating apps to step aside
/// for a moment.
///
/// On a notched Mac the bar runs out of room long before the icons run out, so
/// revealing a hidden block needs slots that do not exist. Rather than move
/// anyone's item — the operation that strands icons — the manager asks apps it
/// does not own nothing at all, and asks apps that opt in to hide themselves
/// briefly. `NSStatusItem.isVisible` is instant, public, and reversible.
public enum MenuBarYield {
    public static let notificationName = Notification.Name("com.nicholaspsmith.menubar.yield")

    public enum State: String, Sendable {
        case yield
        case restore
    }

    /// Distributed notification `userInfo` must be property-list compatible, so
    /// everything crosses the wire as a `String`.
    public struct Payload: Equatable, Sendable {
        public let state: State
        public let token: String
        public let ttl: TimeInterval

        public init(state: State, token: String, ttl: TimeInterval) {
            self.state = state
            self.token = token
            self.ttl = ttl
        }

        public var userInfo: [String: String] {
            ["state": state.rawValue, "token": token, "ttl": String(ttl)]
        }

        /// Returns nil for anything malformed. This arrives from another
        /// process, and the failure mode of trusting it is a permanently hidden
        /// icon, so the bar for acceptance is "every field present and valid".
        public init?(userInfo: [AnyHashable: Any]?) {
            guard let raw = userInfo?["state"] as? String,
                  let state = State(rawValue: raw),
                  let token = userInfo?["token"] as? String,
                  let ttlText = userInfo?["ttl"] as? String,
                  let ttl = TimeInterval(ttlText)
            else { return nil }
            self.state = state
            self.token = token
            self.ttl = ttl
        }
    }

    public static func post(_ payload: Payload) {
        DistributedNotificationCenter.default().postNotificationName(
            notificationName,
            object: nil,
            userInfo: payload.userInfo,
            deliverImmediately: true
        )
    }
}

/// Hides its host's status item while a peek is in progress.
///
/// Opt in with one line in `applicationDidFinishLaunching`:
///
///     yieldClient = YieldClient(item: status)
///     yieldClient.start()
///
/// The local restore timer is the safety property: it fires from the TTL in the
/// message, so a crashed or force-quit manager cannot leave this app's icon
/// hidden. A restore never has to arrive.
public final class YieldClient {
    private weak var controller: StatusItemController?
    private var observer: NSObjectProtocol?
    private var restoreTimer: Timer?

    public init(item: StatusItemController) {
        controller = item
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        restoreTimer?.invalidate()
    }

    public func start() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: MenuBarYield.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let payload = MenuBarYield.Payload(userInfo: note.userInfo) else { return }
            self?.handle(payload)
        }
    }

    private func handle(_ payload: MenuBarYield.Payload) {
        restoreTimer?.invalidate()
        restoreTimer = nil

        switch payload.state {
        case .yield:
            controller?.setVisible(false)
            // Restore ourselves when the TTL runs out, whatever the manager does.
            let ttl = max(payload.ttl, 1)
            restoreTimer = Timer.scheduledTimer(withTimeInterval: ttl, repeats: false) { [weak self] _ in
                self?.controller?.setVisible(true)
                self?.restoreTimer = nil
            }
        case .restore:
            controller?.setVisible(true)
        }
    }
}
