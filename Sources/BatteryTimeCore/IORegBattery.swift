// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import Foundation

public struct IORegBattery: Equatable {
    public let cycleCount: Int?
    public let designCapacity: Int?
    public let rawMaxCapacity: Int?
    public let rawCurrentCapacity: Int?
    public let voltageMV: Int?
    public var temperatureCentiC: Int?
    public let instantAmperageRaw: String?   // raw digits; overflows Int on discharge
    public let adapterName: String?
    public let adapterWatts: Int?
    public let adapterVoltageMV: Int?
    public let adapterCurrentMA: Int?
    public let adapterProtocol: String?
    public let notChargingReason: Int?
    public let isCharging: Bool?
    public let systemPowerInMW: Int?
    public let systemLoadMW: Int?
    public let officialMaxCapacity: Int?

    public init(
        cycleCount: Int? = nil,
        designCapacity: Int? = nil,
        rawMaxCapacity: Int? = nil,
        rawCurrentCapacity: Int? = nil,
        voltageMV: Int? = nil,
        temperatureCentiC: Int? = nil,
        instantAmperageRaw: String? = nil,
        adapterName: String? = nil,
        adapterWatts: Int? = nil,
        adapterVoltageMV: Int? = nil,
        adapterCurrentMA: Int? = nil,
        adapterProtocol: String? = nil,
        notChargingReason: Int? = nil,
        isCharging: Bool? = nil,
        systemPowerInMW: Int? = nil,
        systemLoadMW: Int? = nil,
        officialMaxCapacity: Int? = nil
    ) {
        self.cycleCount = cycleCount
        self.designCapacity = designCapacity
        self.rawMaxCapacity = rawMaxCapacity
        self.rawCurrentCapacity = rawCurrentCapacity
        self.voltageMV = voltageMV
        self.temperatureCentiC = temperatureCentiC
        self.instantAmperageRaw = instantAmperageRaw
        self.adapterName = adapterName
        self.adapterWatts = adapterWatts
        self.adapterVoltageMV = adapterVoltageMV
        self.adapterCurrentMA = adapterCurrentMA
        self.adapterProtocol = adapterProtocol
        self.notChargingReason = notChargingReason
        self.isCharging = isCharging
        self.systemPowerInMW = systemPowerInMW
        self.systemLoadMW = systemLoadMW
        self.officialMaxCapacity = officialMaxCapacity
    }
}

// ioreg's text format is not a plist. Read balanced dictionaries rather than
// searching past a closing brace into another object's fields.
private struct IORegFields {
    var values: [String: String] = [:]
    var children: [String: IORegFields] = [:]

    static func parse(_ raw: String) -> IORegFields {
        let pattern = #""(?:\\.|[^"\\])*"|[{}=()]|<[^>]*>|[^\s,|{}=()]+"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return IORegFields() }
        let tokens = re.matches(in: raw, range: NSRange(raw.startIndex..., in: raw)).compactMap {
            Range($0.range, in: raw).map { String(raw[$0]) }
        }
        var index = 0
        var valid = true
        var hasOuterBrace = false
        // A full ioreg object has an outer brace; field-only fixtures do not.
        if let first = tokens.firstIndex(of: "{"), !tokens.prefix(first).contains("=") {
            index = first + 1
            hasOuterBrace = true
        }
        func dictionary(_ depth: Int) -> IORegFields {
            guard depth < 32 else {
                valid = false
                index = tokens.count
                return IORegFields()
            }
            var result = IORegFields()
            while index < tokens.count {
                let key = tokens[index]
                if key == "}" { index += 1; return result }
                guard key.hasPrefix("\""), index + 2 < tokens.count, tokens[index + 1] == "=" else {
                    index += 1; continue
                }
                index += 2
                let name = String(key.dropFirst().dropLast())
                if tokens[index] == "{" {
                    index += 1
                    result.children[name] = dictionary(depth + 1)
                } else if tokens[index] == "(" {
                    // Arrays are opaque: same-name fields within them cannot leak.
                    var nesting = 1
                    index += 1
                    while index < tokens.count && nesting > 0 {
                        if tokens[index] == "(" { nesting += 1 }
                        if tokens[index] == ")" { nesting -= 1 }
                        index += 1
                    }
                    if nesting != 0 { valid = false }
                } else {
                    let value = tokens[index]
                    result.values[name] = value.hasPrefix("\"") ? String(value.dropFirst().dropLast()) : value
                    index += 1
                }
            }
            if depth > 0 || hasOuterBrace { valid = false }
            return result
        }
        let result = dictionary(0)
        return valid ? result : IORegFields()
    }

    func int(_ key: String, range: ClosedRange<Int>? = nil) -> Int? {
        guard let raw = values[key], let number = Int(raw) else { return nil }
        if let range = range, !range.contains(number) { return nil }
        return number
    }
}

public func parseIORegBattery(_ raw: String) -> IORegBattery {
    let root = IORegFields.parse(raw)
    let battery = root.children["BatteryData"] ?? IORegFields()
    let charger = root.children["ChargerData"] ?? IORegFields()
    let adapter = root.children["AdapterDetails"] ?? IORegFields()
    let telemetry = root.children["PowerTelemetryData"] ?? IORegFields()
    // Temperature prefers valid BatteryData, health prefers valid top-level BMS.
    // Other root fields never fall through to unrelated dictionaries.
    return IORegBattery(
        cycleCount: root.int("CycleCount", range: 0...99_999) ?? battery.int("CycleCount", range: 0...99_999),
        designCapacity: root.int("DesignCapacity", range: 1...100_000) ?? battery.int("DesignCapacity", range: 1...100_000),
        rawMaxCapacity: root.int("AppleRawMaxCapacity", range: 0...100_000) ?? root.int("FullChargeCapacity", range: 0...100_000) ?? battery.int("FullChargeCapacity", range: 0...100_000),
        rawCurrentCapacity: root.int("AppleRawCurrentCapacity", range: 0...100_000) ?? root.int("RemainingCapacity", range: 0...100_000) ?? battery.int("RemainingCapacity", range: 0...100_000),
        voltageMV: root.int("Voltage", range: 1...100_000),
        temperatureCentiC: battery.int("Temperature", range: -5000...15000) ?? root.int("Temperature", range: -5000...15000),
        instantAmperageRaw: root.values["InstantAmperage"],
        adapterName: adapter.values["Name"],
        adapterWatts: adapter.int("Watts", range: 1...1000),
        adapterVoltageMV: adapter.int("AdapterVoltage", range: 1...100_000) ?? root.int("AdapterVoltage", range: 1...100_000),
        adapterCurrentMA: adapter.int("Current", range: 0...100_000),
        adapterProtocol: adapter.values["Description"],
        notChargingReason: root.int("NotChargingReason") ?? charger.int("NotChargingReason"),
        isCharging: [root.values["IsCharging"], charger.values["IsCharging"]].compactMap { value -> Bool? in
            switch value { case "Yes", "1": return true; case "No", "0": return false; default: return nil }
        }.first,
        systemPowerInMW: telemetry.int("SystemPowerIn", range: 0...1_000_000) ?? root.int("SystemPowerIn", range: 0...1_000_000),
        systemLoadMW: telemetry.int("SystemLoad", range: 0...1_000_000) ?? root.int("SystemLoad", range: 0...1_000_000),
        officialMaxCapacity: root.int("MaxCapacity", range: 1...100) ?? battery.int("MaxCapacity", range: 1...100)
    )
}
