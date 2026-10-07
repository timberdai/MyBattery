// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

public func healthPercent(rawMax: Int?, design: Int?) -> Int? {
    guard let m = rawMax, let d = design, d > 0, m >= 0 else { return nil }
    if m >= d { return 100 }
    let product = m.multipliedReportingOverflow(by: 100)
    let val = product.overflow ? min(99, Int(Double(m) / Double(d) * 100)) : product.partialValue / d
    return max(0, min(100, val))
}

public func humanize(_ hmm: String, language: AppLanguage = .system) -> String {
    let parts = hmm.split(separator: ":")
    let h = parts.count > 0 ? Int(parts[0]) ?? 0 : 0
    let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    if h > 0 && m > 0 { return language.text("\(h) 小时 \(m) 分钟", "\(h) h \(m) min") }
    if h > 0 { return language.text("\(h) 小时", "\(h) h") }
    return language.text("\(m) 分钟", "\(m) min")
}

public func celsius(fromCentiC c: Int) -> Int { c / 100 }
public func fahrenheit(fromCentiC c: Int) -> Int { (c / 100) * 9 / 5 + 32 }

/// Signed mA, including UInt64 two's-complement discharge representations.
public func signedAmperage(_ raw: String) -> Int? {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let value = Int(s) { return value }
    guard let value = UInt64(s), value > UInt64(Int64.max) else { return nil }
    return Int(exactly: Int64(bitPattern: value))
}

public func dischargeMagnitude(instantAmperageRaw raw: String) -> Int? {
    guard let value = signedAmperage(raw), value != Int.min else { return nil }
    return abs(value)
}

/// Stop-gap ETA (minutes) right after unplug, before macOS has its own estimate:
/// measured-draw projection capped by a nominal ~12 W. nil if no estimate.
public func etaStopgapMinutes(rawCurrent: Int, voltageMV: Int?, instantAmperageRaw: String?) -> Int? {
    guard (1...100_000).contains(rawCurrent) else { return nil }
    let minutesCapacity = rawCurrent.multipliedReportingOverflow(by: 60)
    guard !minutesCapacity.overflow else { return nil }

    var nominal: Int? = nil
    if let v = voltageMV, (1...100_000).contains(v) {
        let denom = 12_000_000 / v
        if denom > 0 {
            nominal = max(1, minutesCapacity.partialValue / denom)
        }
    }

    var measured: Int? = nil
    if let raw = instantAmperageRaw, let mag = dischargeMagnitude(instantAmperageRaw: raw), mag > 0 {
        measured = max(1, minutesCapacity.partialValue / mag)
    }

    switch (measured, nominal) {
    case let (m?, n?): return min(m, n)
    case let (m?, nil): return m
    case let (nil, n?): return n
    default: return nil
    }
}
