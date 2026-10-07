import Foundation

public func activePowerInfo(reading: BatteryReading, io: IORegBattery, language: AppLanguage = .system) -> (label: String, value: String, isGreen: Bool) {
    func watts(_ value: Double, label: String, green: Bool = false) -> (String, String, Bool)? {
        guard value.isFinite, (0...1000).contains(value) else { return nil }
        return (label, String(format: "%.1f W", value), green)
    }
    if let voltage = io.voltageMV, (1...100_000).contains(voltage),
       let raw = io.instantAmperageRaw, let current = signedAmperage(raw),
       current != Int.min, abs(current) <= 100_000 {
        let charging = reading.plugged && reading.state == .charging && io.isCharging != false && current > 0
        let discharging = !reading.plugged && reading.state == .discharging && io.isCharging != true && current < 0
        if charging || discharging,
           let result = watts(Double(voltage) * Double(abs(current)) / 1_000_000,
                              label: charging ? language.text("充电功率", "Charging") : language.text("放电功率", "Discharge"), green: charging) { return result }
    }
    if reading.plugged, let input = io.systemPowerInMW, input >= 0,
       let result = watts(Double(input) / 1000, label: language.text("输入功率", "Input")) { return result }
    if let load = io.systemLoadMW, load >= 0,
       let result = watts(Double(load) / 1000, label: language.text("负载功率", "Load")) { return result }
    return (reading.plugged ? language.text("输入功率", "Input") : language.text("放电功率", "Discharge"), language.text("暂无数据", "No data"), false)
}

public func adapterProtocolLabel(_ io: IORegBattery, language: AppLanguage = .system) -> String? {
    let description = (io.adapterProtocol ?? "").lowercased()
    let words = description.split { !$0.isLetter && !$0.isNumber }
    if words.contains("pd") { return "PD" }
    if description.contains("magsafe") { return language.text("磁吸", "MagSafe") }
    if words.contains("usb") { return "USB" }
    return nil
}

public func formattedAdapterLine(_ io: IORegBattery, language: AppLanguage = .system) -> String {
    let proto = adapterProtocolLabel(io, language: language)
    if let watts = io.adapterWatts, (1...1000).contains(watts) {
        return proto.map { "\($0) \(watts) W" } ?? "\(watts) W"
    }
    if let proto = proto { return language == .chinese ? "\(proto) 已连接" : proto }
    return language.text("已连接", "Connected")
}

/// The adapter's reported operating voltage/current describes a power profile,
/// not a measurement of instantaneous battery charging power.
public func adapterPowerProfile(_ io: IORegBattery) -> String? {
    guard adapterProtocolLabel(io) == "PD",
          let voltage = io.adapterVoltageMV, (1...50_000).contains(voltage),
          let current = io.adapterCurrentMA, (1...10_000).contains(current) else { return nil }
    let watts = Double(voltage) * Double(current) / 1_000_000
    guard (1...1000).contains(watts) else { return nil }
    return String(format: "%.0f W", watts)
}

public func batterySupplyLabel(_ reading: BatteryReading, io: IORegBattery, language: AppLanguage = .system) -> String {
    if !reading.plugged { return language.text("电池供电", "Battery") }
    if reading.state == .charging { return language.text("正在充电", "Charging") }
    if reading.state == .discharging { return language.text("外接电源 · 放电", "AC · Discharging") }
    if reading.percent == 100 || reading.state == .charged { return language.text("已充满 (供电)", "Full (AC)") }
    if io.notChargingReason == 16777216 || reading.percent == 80 { return language.text("外接供电 (旁路)", "AC (bypass)") }
    return language.text("外接供电", "AC power")
}

public func compactMenuTime(_ hmm: String, language: AppLanguage = .system) -> String {
    let parts = hmm.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
          h >= 0, (0...59).contains(m) else { return language.text("暂无数据", "No data") }
    if h > 99 { return language.text("超过99小时", "Over 99 h") }
    if h > 0 && m > 0 { return language.text("\(h)小时\(m)分", "\(h)h\(m)m") }
    return h > 0 ? language.text("\(h)小时", "\(h)h") : language.text("\(m)分钟", "\(m)m")
}

public func capacityMenuValue(_ value: Int, language: AppLanguage = .system) -> String {
    (0...99_999).contains(value) ? "\(value) mAh" : language.text("数据异常", "Invalid data")
}

public func cycleMenuValue(_ value: Int, language: AppLanguage = .system) -> String {
    (0...99_999).contains(value) ? language.text("\(value) 次", "\(value)") : language.text("数据异常", "Invalid data")
}
