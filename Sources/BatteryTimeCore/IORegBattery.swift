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
    public let temperatureCentiC: Int?
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
        systemLoadMW: Int? = nil
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
    }
}

public func parseIORegBattery(_ raw: String) -> IORegBattery {
    func intVal(_ key: String) -> Int? {
        // matches:  "Key" = 123   or   "Key" = -123
        firstMatch(in: raw, pattern: "\"\(key)\"\\s*=\\s*(-?[0-9]+)").flatMap { Int($0) }
    }
    let name = firstMatch(in: raw, pattern: "\"AdapterDetails\"[\\s\\S]*?\"Name\"\\s*=\\s*\"([^\"]*)\"")
        ?? firstMatch(in: raw, pattern: "\"Name\"\\s*=\\s*\"([^\"]*)\"")
    let watts = (firstMatch(in: raw, pattern: "\"Watts\"\\s*=\\s*([0-9]+)")).flatMap { Int($0) }
    let adapterVoltage = firstMatch(in: raw, pattern: "\"AdapterVoltage\"\\s*=\\s*([0-9]+)").flatMap { Int($0) }
    let adapterCurrent = firstMatch(in: raw, pattern: "\"AdapterDetails\"[\\s\\S]*?\"Current\"\\s*=\\s*([0-9]+)").flatMap { Int($0) }
    let desc = firstMatch(in: raw, pattern: "\"AdapterDetails\"[\\s\\S]*?\"Description\"\\s*=\\s*\"([^\"]*)\"")
    let proto: String? = {
        if let d = desc {
            if d.lowercased().contains("pd") { return "USB-PD" }
            return d
        }
        return nil
    }()
    let notChargingReason = firstMatch(in: raw, pattern: "\"NotChargingReason\"\\s*=\\s*([0-9]+)").flatMap { Int($0) }
    let isChg = firstMatch(in: raw, pattern: "\"IsCharging\"\\s*=\\s*(Yes|No)").map { $0 == "Yes" }
    let sysPower = firstMatch(in: raw, pattern: "\"SystemPowerIn\"\\s*=\\s*([0-9]+)").flatMap { Int($0) }
    let sysLoad = firstMatch(in: raw, pattern: "\"SystemLoad\"\\s*=\\s*([0-9]+)").flatMap { Int($0) }

    let maxCap = intVal("AppleRawMaxCapacity") ?? intVal("FullChargeCapacity")
    let curCap = intVal("AppleRawCurrentCapacity") ?? intVal("RemainingCapacity")

    return IORegBattery(
        cycleCount: intVal("CycleCount"),
        designCapacity: intVal("DesignCapacity"),
        rawMaxCapacity: maxCap,
        rawCurrentCapacity: curCap,
        voltageMV: intVal("Voltage"),
        temperatureCentiC: intVal("Temperature"),
        instantAmperageRaw: firstMatch(in: raw, pattern: "\"InstantAmperage\"\\s*=\\s*(-?[0-9]+)"),
        adapterName: name,
        adapterWatts: watts,
        adapterVoltageMV: adapterVoltage,
        adapterCurrentMA: adapterCurrent,
        adapterProtocol: proto,
        notChargingReason: notChargingReason,
        isCharging: isChg,
        systemPowerInMW: sysPower,
        systemLoadMW: sysLoad
    )
}
