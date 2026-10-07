// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

public enum PowerState: Equatable { case discharging, charging, charged, notCharging, pluggedOther }

public struct BatteryReading: Equatable {
    public let percent: Int?
    public let plugged: Bool
    public let state: PowerState
    public let rawTime: String?
}

public func parsePmsetBatt(_ raw: String) -> BatteryReading {
    let plugged = raw.contains("'AC Power'")
    let line = raw.split(separator: "\n").first(where: { $0.contains("InternalBattery") }).map(String.init) ?? ""

    let percent = firstMatch(in: line, pattern: "([0-9]+)%").flatMap { Int($0) }.flatMap { (0...100).contains($0) ? $0 : nil }

    let state: PowerState
    if line.contains("discharging") { state = .discharging }
    else if line.contains("not charging") { state = .notCharging }
    else if line.contains("charging") { state = .charging }
    else if line.contains("charged") { state = .charged }
    else { state = .pluggedOther }

    var rawTime: String? = nil
    if state == .discharging || state == .charging {
        rawTime = firstMatch(in: line, pattern: "([0-9]{1,2}:[0-9]{2})")
    }
    return BatteryReading(percent: percent, plugged: plugged, state: state, rawTime: rawTime)
}

/// First capture group of `pattern` in `s`, or nil.
func firstMatch(in s: String, pattern: String) -> String? {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(s.startIndex..., in: s)
    guard let m = re.firstMatch(in: s, range: range), m.numberOfRanges > 1,
          let r = Range(m.range(at: 1), in: s) else { return nil }
    return String(s[r])
}

/// Only recognizable, coherent battery samples may update the UI or edge state.
public func validPmsetBatt(_ raw: String) -> BatteryReading? {
    let ac = raw.contains("Now drawing from 'AC Power'")
    let battery = raw.contains("Now drawing from 'Battery Power'")
    guard ac != battery else { return nil }
    let reading = parsePmsetBatt(raw)
    guard reading.percent != nil, reading.state != .pluggedOther,
          raw.contains("present: true") else { return nil }
    if battery && reading.state != .discharging { return nil }
    return reading
}

/// Owned by the main thread in App. Invalid reads release the gate without
/// replacing the last valid power-source state; multiple requests coalesce.
public struct BatteryPollState {
    public private(set) var inFlight = false
    public private(set) var pending = false
    public private(set) var previousPlugged: Bool?
    public init() {}
    public mutating func begin() -> Bool {
        if inFlight { pending = true; return false }
        inFlight = true
        return true
    }
    public mutating func finish(_ reading: BatteryReading?) -> (celebrate: Bool, repoll: Bool) {
        let celebrate = reading.map { previousPlugged == false && $0.plugged } ?? false
        if let reading = reading { previousPlugged = reading.plugged }
        inFlight = false
        let repoll = pending
        pending = false
        return (celebrate, repoll)
    }
}
