import Foundation
#if !DIRECT_REGRESSION
@testable import BatteryTimeCore
#endif

func runCoreRound2(_ check: (Bool, String) -> Void) {
    check(dischargeMagnitude(instantAmperageRaw: String(Int.min)) == nil, "R02 Int.min magnitude")
    check(healthPercent(rawMax: Int.max, design: 6249) == 100, "R02 Int.max health capped")
    check(healthPercent(rawMax: Int.max - 1, design: Int.max) == 99, "R02 large ratio below full")
    check(etaStopgapMinutes(rawCurrent: Int.max, voltageMV: 12000, instantAmperageRaw: "1000") == nil, "R02 Int.max ETA rejected")
    for raw in [String(Int.min), "9223372036854775808"] {
        check(dischargeMagnitude(instantAmperageRaw: raw) == nil, "R02 magnitude boundary \(raw)")
    }
    check(signedAmperage("18446744073709551615") == -1, "R02 UInt64.max direction")
    check(signedAmperage("18446744073709551616") == nil, "R02 unsigned overflow")
    check(signedAmperage("10000000000") == 10_000_000_000, "R02 long positive not complement")
    check(dischargeMagnitude(instantAmperageRaw: "-1250") == 1250, "R02 normal signed magnitude")
    check(dischargeMagnitude(instantAmperageRaw: "18446744073709550116") == 1500, "R02 normal unsigned magnitude")
    check(healthPercent(rawMax: -1, design: 6249) == nil, "R02 negative health")
    check(healthPercent(rawMax: 0, design: 6249) == 0, "R02 zero health")
    check(healthPercent(rawMax: 4100, design: 4382) == 93, "R02 ordinary health")
    for cur in [0, -1, Int.min] {
        check(etaStopgapMinutes(rawCurrent: cur, voltageMV: 12000, instantAmperageRaw: "1000") == nil, "R02 invalid capacity \(cur)")
    }
    check(etaStopgapMinutes(rawCurrent: 4000, voltageMV: Int.max, instantAmperageRaw: nil) == nil, "R02 extreme voltage")
    check(etaStopgapMinutes(rawCurrent: 4000, voltageMV: 12000, instantAmperageRaw: "18446744073709551516") == 240, "R02 normal ETA cap")
    check(humanize("1:20", language: .chinese) == "1 小时 20 分钟", "R04 humanize production output")
    check(compactMenuTime("1:20", language: .chinese) == "1小时20分", "R04 compact menu output")
    check(compactMenuTime("99:59", language: .chinese) == "99小时59分", "R04 longest precise time")
    check(compactMenuTime(String(Int.max) + ":59", language: .chinese) == "超过99小时", "R04 extreme time")
    check(compactMenuTime("1:60", language: .chinese) == "暂无数据", "R04 invalid minute")
    check(capacityMenuValue(Int.max, language: .chinese) == "数据异常", "R04 invalid capacity display")
    check(cycleMenuValue(-1, language: .chinese) == "数据异常", "R04 invalid cycle display")

    func reading(_ plugged: Bool, _ state: PowerState) -> BatteryReading {
        BatteryReading(percent: 80, plugged: plugged, state: state, rawTime: nil)
    }
    let charging = reading(true, .charging), idle = reading(true, .notCharging), discharging = reading(false, .discharging)
    func power(_ r: BatteryReading, _ io: IORegBattery, _ label: String, _ value: String, _ green: Bool = false) {
        let actual = activePowerInfo(reading: r, io: io, language: .chinese)
        check(actual.label == label && actual.value == value && actual.isGreen == green, "R03 \(label) \(value) / \(actual)")
    }
    power(charging, IORegBattery(voltageMV: 12000, instantAmperageRaw: "1000"), "充电功率", "12.0 W", true)
    power(charging, IORegBattery(systemPowerInMW: 45000), "输入功率", "45.0 W")
    power(charging, IORegBattery(voltageMV: 12000, instantAmperageRaw: "-1000"), "输入功率", "暂无数据")
    power(charging, IORegBattery(voltageMV: 12000, instantAmperageRaw: "18446744073709550616", systemPowerInMW: 45000), "输入功率", "45.0 W")
    power(charging, IORegBattery(voltageMV: 12000, instantAmperageRaw: "1000", isCharging: false, systemPowerInMW: 45000), "输入功率", "45.0 W")
    power(idle, IORegBattery(systemPowerInMW: 45000, systemLoadMW: 12000), "输入功率", "45.0 W")
    power(idle, IORegBattery(systemLoadMW: 12000), "负载功率", "12.0 W")
    power(idle, IORegBattery(systemPowerInMW: 0), "输入功率", "0.0 W")
    power(discharging, IORegBattery(voltageMV: 12000, instantAmperageRaw: "-1000"), "放电功率", "12.0 W")
    power(discharging, IORegBattery(voltageMV: 12000, instantAmperageRaw: "18446744073709550616"), "放电功率", "12.0 W")
    power(discharging, IORegBattery(voltageMV: 12000, instantAmperageRaw: "1000", systemLoadMW: 9000), "负载功率", "9.0 W")
    for raw in ["bad", "0", String(Int.min)] {
        power(charging, IORegBattery(voltageMV: 12000, instantAmperageRaw: raw), "输入功率", "暂无数据")
    }
    power(charging, IORegBattery(voltageMV: Int.max, instantAmperageRaw: "1000", systemPowerInMW: -1), "输入功率", "暂无数据")
    for description in ["pd charger", "PD Charger", "USB-PD", "USB PD 3.1"] {
        check(adapterProtocolLabel(IORegBattery(adapterProtocol: description), language: .chinese) == "PD", "V1 PD description \(description)")
    }
    check(adapterProtocolLabel(IORegBattery(adapterProtocol: "updated adapter"), language: .chinese) == nil, "V1 unknown protocol not substring guessed")
    check(adapterPowerProfile(IORegBattery(adapterVoltageMV: 20000, adapterCurrentMA: 5000, adapterProtocol: "pd charger")) == "100 W", "V1 reported PD profile")
    check(adapterPowerProfile(IORegBattery(adapterWatts: 140, adapterProtocol: "pd charger")) == nil, "V1 rating is not PD profile")
    check(adapterPowerProfile(IORegBattery(adapterVoltageMV: Int.max, adapterCurrentMA: 5000, adapterProtocol: "pd charger")) == nil, "V1 invalid PD voltage")
    check(batterySupplyLabel(reading(true, .discharging), io: IORegBattery(), language: .chinese) == "外接电源 · 放电", "V1 plugged but discharging")
    check(batterySupplyLabel(BatteryReading(percent: 100, plugged: true, state: .charged, rawTime: nil), io: IORegBattery(notChargingReason: 16777216), language: .chinese) == "已充满 (供电)", "V1 full precedence over held charge")
    let held = parseIORegBattery(#""ChargerData"={"NotChargingReason"=16777216,"IsCharging"=0} "Unrelated"={"NotChargingReason"=1}"#)
    check(held.notChargingReason == 16777216 && held.isCharging == false, "V1 known charger dictionary")
    check(formattedAdapterLine(IORegBattery(adapterWatts: 240, adapterProtocol: "USB-PD"), language: .chinese) == "PD 240 W", "R04 PD normalized")
    check(formattedAdapterLine(IORegBattery(adapterName: "96W USB-C Power Adapter", adapterProtocol: "usb"), language: .chinese) == "USB 已连接", "R04 no name rating inference")
    check(formattedAdapterLine(IORegBattery(adapterName: String(repeating: "x", count: 500), adapterProtocol: String(repeating: "x", count: 500)), language: .chinese) == "已连接", "R04 unknown long name")

    let unrelated = #""BatteryData"={"Foo"=1} "Unrelated"={"Temperature"=5000,"MaxCapacity"=4,"Name"="wrong","Watts"=999,"SystemPowerIn"=999} "Temperature"=3200 "MaxCapacity"=97 "AdapterDetails"={"Name"="correct","Watts"=140} "PowerTelemetryData"={"SystemLoad"=12000}"#
    let b = parseIORegBattery(unrelated)
    check(b.temperatureCentiC == 3200 && b.officialMaxCapacity == 97, "R05 dictionary boundaries")
    check(b.adapterName == "correct" && b.adapterWatts == 140 && b.systemPowerInMW == nil && b.systemLoadMW == 12000, "R05 adapter telemetry boundaries")
    for fields in [#""Temperature"=3200 "BatteryData"={"Temperature"=3500} "MaxCapacity"=97"#,
                   #""MaxCapacity"=97 "BatteryData"={"Temperature"=3500} "Temperature"=3200"#] {
        check(parseIORegBattery(fields).temperatureCentiC == 3500, "R05 temperature nested priority")
    }
    check(parseIORegBattery(#""MaxCapacity"=6000 "BatteryData"={"MaxCapacity"=94}"#).officialMaxCapacity == 94, "R05 valid nested health fallback")
    check(parseIORegBattery(#""MaxCapacity"=0 "Unrelated"={"MaxCapacity"=100}"#).officialMaxCapacity == nil, "R05 invalid health no unrelated fallback")
    check(parseIORegBattery(#""BatteryData"={"Temperature"=16000} "Temperature"=-5000"#).temperatureCentiC == -5000, "R05 invalid nested temp fallback")
    check(parseIORegBattery(#""Temperature"=-5001"#).temperatureCentiC == nil, "R05 invalid temperature")
    check(parseIORegBattery(#""AdapterDetails"={"Other"={"Name"="nested"}} "Unrelated"={"Name"="wrong","Current"=2,"Description"="usb"}"#).adapterName == nil, "R05 nested same field excluded")
    check(parseIORegBattery(#""Array"=({"Temperature"=9000}) "Temperature"=3100"#).temperatureCentiC == 3100, "R05 array ignored")
    check(parseIORegBattery(#"| { "CycleCount"=142 "DesignCapacity"=4382 "AppleRawMaxCapacity"=4100 "Voltage"=12600 "InstantAmperage"=18446744073709550000 "Temperature"=3012 "AdapterDetails"={"Watts"=96,"Name"="96W USB-C Power Adapter"} | }"#).adapterWatts == 96, "R05 full ioreg fixture")
    let nestedCapacity = parseIORegBattery(#""BatteryData"={"DesignCapacity"=6249,"RemainingCapacity"=4963,"FullChargeCapacity"=6271,"CycleCount"=6} "Unrelated"={"RemainingCapacity"=123}"#)
    check(nestedCapacity.designCapacity == 6249 && nestedCapacity.rawCurrentCapacity == 4963 && nestedCapacity.rawMaxCapacity == 6271 && nestedCapacity.cycleCount == 6, "R05 explicit BatteryData capacity fallback")
    check(parseIORegBattery(#""AppleRawCurrentCapacity"=4000 "BatteryData"={"RemainingCapacity"=4963}"#).rawCurrentCapacity == 4000, "R05 root raw capacity priority")
    check(parseIORegBattery("-") == IORegBattery(), "R05 empty input")
    check(parseIORegBattery(#""BatteryData"={"Temperature"=3400"#) == IORegBattery(), "R05 truncated dictionary rejected")
    check(parseIORegBattery(String(repeating: #""Nested"={"#, count: 40) + #""Temperature"=4000"# + String(repeating: "}", count: 40) + #" "Temperature"=3200"#) == IORegBattery(), "R05 depth limit does not leak")

    func sample(_ ac: Bool) -> String {
        "Now drawing from '\(ac ? "AC Power" : "Battery Power")'\n -InternalBattery-0 80%; \(ac ? "charging" : "discharging"); 1:20 remaining present: true"
    }
    let ac = validPmsetBatt(sample(true)), batt = validPmsetBatt(sample(false))
    check(ac?.state == .charging && ac?.rawTime == "1:20", "R06 valid AC")
    check(batt?.state == .discharging && batt?.rawTime == "1:20", "R06 valid battery")
    let invalid = ["", "warning: sample unavailable", "Now drawing from 'AC Power'", sample(true).replacingOccurrences(of: "80%", with: "101%"), sample(true).replacingOccurrences(of: "present: true", with: "present: false"), sample(false).replacingOccurrences(of: "discharging", with: "charging")]
    var gate = BatteryPollState()
    check(gate.begin(), "R06 initial begin")
    check(!gate.finish(ac).celebrate, "R06 initial AC no glow")
    for raw in invalid {
        check(validPmsetBatt(raw) == nil, "R06 invalid sample rejected: \(raw)")
        check(gate.begin(), "R06 failure begin")
        check(!gate.begin() && !gate.begin(), "R06 pending coalesced")
        let failure = gate.finish(validPmsetBatt(raw))
        check(!failure.celebrate && failure.repoll && !gate.inFlight && !gate.pending && gate.previousPlugged == true, "R06 failure preserves source and releases gate")
        check(gate.begin(), "R06 recovery begin")
        check(!gate.finish(ac).celebrate, "R06 recovery AC no false glow")
    }
    check(gate.begin(), "R06 unplug begin")
    check(!gate.finish(batt).celebrate, "R06 unplug no glow")
    check(gate.begin(), "R06 real plug begin")
    check(gate.finish(ac).celebrate, "R06 real Battery to AC glow")
    check(gate.begin(), "R06 repeated AC begin")
    check(!gate.finish(ac).celebrate, "R06 repeated AC single glow")
    let charged = sample(true).replacingOccurrences(of: "charging", with: "charged")
    check(validPmsetBatt(charged)?.rawTime == nil, "pmset charged no ETA")
    check(validPmsetBatt(sample(true).replacingOccurrences(of: "charging", with: "not charging"))?.state == .notCharging, "pmset not charging")

    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"; fmt.locale = Locale(identifier: "en_US_POSIX")
    let now = fmt.date(from: "2026-06-22 12:00:00")!
    let u = parsePmsetLog("2026-06-22 10:00:00 Using Batt (Charge: 80)\n2026-06-22 11:00:00 Using AC (Charge: 60)", now: now)
    check(u.batterySeconds == 3600 && u.acSeconds == 3600 && u.minCharge == 60, "Usage24h interval baseline")
    let reversed = parsePmsetLog("2026-06-22 11:00:00 Using AC (Charge: 60)\n2026-06-22 10:00:00 Using Batt (Charge: 80)\n2026-06-22 13:00:00 Using Batt (Charge: 1)", now: now)
    check(reversed == u, "V1 unsorted and future usage events")
    check(parsePmsetLog("2026-06-22 11:00:00 Using AC (Charge: 500)", now: now).minCharge == nil, "V1 invalid usage percentage")
    check(parsePmsetLog("", now: now).minCharge == nil, "Usage24h empty")
    let tips = batteryTips(usage: Usage24h(batterySeconds: 0, acSeconds: 0, minCharge: 12, highACSeconds: 28800, lowEpisodes: 2), temperatureCentiC: 3500, cycleCount: 850, language: .chinese)
    check(tips.count == 4 && tips.contains(where: { $0.contains("12%") }), "Usage24h tips baseline")
}
