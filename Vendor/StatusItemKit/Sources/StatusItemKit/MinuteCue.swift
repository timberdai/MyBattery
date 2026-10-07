// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Once a minute, each animated mascot does its thing — and when several are
/// running they take turns, a second apart, rather than all moving at once.
///
/// Every app wakes on the wall-clock minute and counts how many of the
/// animated apps ahead of it in `order` are running; that count is how many
/// seconds it waits. With Archimedes and Carol running, Archimedes goes at
/// :00 and Carol at :01; add Menu Pimp and he takes :01, Carol moving to :02.
/// No coordination beyond the list: every app reads the same running set at
/// the same moment, so they agree without talking.
///
/// Skipped entirely under Reduce Motion. The timer is one-shot and re-aimed
/// each minute, and again after wake or a clock change, so it never drifts.
public final class MinuteCue {
    /// The animated apps, in the order they take their turn.
    public static let order = [
        "com.nicholaspsmith.ClaudeUsage",     // Archimedes blinks
        "com.nicholaspsmith.MacDaddy",        // Menu Pimp flashes his teeth
        "com.nicholaspsmith.SoundChain",      // Carol runs
        "com.nicholaspsmith.VPNDNSMenuBar",   // Caveepyan licks
        "com.nicholaspsmith.MonitorLizard",   // Armonitor laps his monitor
    ]

    /// Seconds after the minute `bundleID` should start: one per animated app
    /// ahead of it that is running. An app missing from `order` goes after
    /// every one that is in it.
    public static func slot(of bundleID: String, running: Set<String>, order: [String] = order) -> Int {
        let ahead = order.firstIndex(of: bundleID).map { order[..<$0] } ?? order[...]
        return ahead.filter(running.contains).count
    }

    /// The next whole minute of the wall clock strictly after `date`.
    public static func nextMinute(after date: Date) -> Date {
        Date(timeIntervalSince1970: (floor(date.timeIntervalSince1970 / 60) + 1) * 60)
    }

    private let bundleID: String
    private let action: () -> Void
    private var minuteTimer: Timer?
    private var slotTimer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    public init(bundleID: String = Bundle.main.bundleIdentifier ?? "", action: @escaping () -> Void) {
        self.bundleID = bundleID
        self.action = action
    }

    deinit { stop() }

    public func start() {
        schedule()
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append((workspace, workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                           queue: .main) { [weak self] _ in self?.schedule() }))
        observers.append((.default, NotificationCenter.default.addObserver(forName: .NSSystemClockDidChange, object: nil,
                                                                           queue: .main) { [weak self] _ in self?.schedule() }))
    }

    public func stop() {
        minuteTimer?.invalidate(); minuteTimer = nil
        slotTimer?.invalidate(); slotTimer = nil
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
    }

    private func schedule() {
        minuteTimer?.invalidate()
        let timer = Timer(fire: Self.nextMinute(after: Date()), interval: 0, repeats: false) { [weak self] _ in
            self?.minute()
            self?.schedule()
        }
        // Common modes: the animation still plays while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
    }

    private func minute() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let wait = Self.slot(of: bundleID, running: running)
        guard wait > 0 else { action(); return }
        slotTimer?.invalidate()
        let timer = Timer(timeInterval: TimeInterval(wait), repeats: false) { [weak self] _ in self?.action() }
        RunLoop.main.add(timer, forMode: .common)
        slotTimer = timer
    }
}

/// Drives one run of an icon animation at the display's pace: `frame` gets the
/// seconds elapsed, from 0 up to `duration`, then `completion` runs once.
/// Starting it again while it runs does nothing.
public final class IconAnimation {
    public let duration: TimeInterval
    private let frame: (TimeInterval) -> Void
    private let completion: () -> Void
    private var timer: Timer?
    private var startedAt: Date?

    public init(duration: TimeInterval, frame: @escaping (TimeInterval) -> Void, completion: @escaping () -> Void = {}) {
        self.duration = duration
        self.frame = frame
        self.completion = completion
    }

    public var isRunning: Bool { timer != nil }

    public func start() {
        guard timer == nil else { return }
        startedAt = Date()
        frame(0)
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func cancel() {
        timer?.invalidate(); timer = nil; startedAt = nil
    }

    private func tick() {
        guard let start = startedAt else { return }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= duration {
            cancel()
            completion()
        } else {
            frame(elapsed)
        }
    }
}
