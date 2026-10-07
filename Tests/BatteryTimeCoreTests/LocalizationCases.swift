import Foundation
#if !DIRECT_REGRESSION
@testable import BatteryTimeCore
#endif

func runLocalizationCases(_ check: (Bool, String) -> Void) {
    for code in ["zh", "zh-Hans", "zh-Hant", "zh-CN", "zh-TW", "zh-HK", "ZH_hANT"] {
        check(AppLanguage(preferredLanguages: [code]) == .chinese, "Language Chinese \(code)")
    }
    for languages in [["en"], ["en-GB"], ["fr", "zh-Hans"], ["ja", "zh"], ["de"], ["es"], ["zho"], [""], []] {
        check(AppLanguage(preferredLanguages: languages) == .english, "Language English fallback \(languages)")
    }
    check(AppLanguage(preferredLanguages: ["zh-Hant", "en"]) == .chinese, "Language first preference wins")
    check(AppLanguage.english.text("状态", "Status") == "Status", "Language English static text")
    check(AppLanguage.chinese.text("状态", "Status") == "状态", "Language Chinese static text")
    for (time, expected) in [("1:20", "1h20m"), ("99:59", "99h59m"), ("0:59", "59m"), ("99:00", "99h"), ("100:00", "Over 99 h"), ("1:60", "No data")] {
        check(compactMenuTime(time, language: .english) == expected, "Language English time \(time)")
    }
    check(cycleMenuValue(99, language: .english) == "99", "Language English cycle count")
    check(capacityMenuValue(-1, language: .english) == "Invalid data", "Language English invalid capacity")
    check(formattedAdapterLine(IORegBattery(adapterProtocol: "magsafe"), language: .english) == "MagSafe", "Language English adapter")
    check(formattedAdapterLine(IORegBattery(adapterWatts: 140, adapterProtocol: "usb-pd"), language: .english) == "PD 140 W", "Language English PD")
    let reading = BatteryReading(percent: 80, plugged: true, state: .notCharging, rawTime: nil)
    check(batterySupplyLabel(reading, io: IORegBattery(), language: .english) == "AC (bypass)", "Language English held charge")
    let power = activePowerInfo(reading: reading, io: IORegBattery(systemPowerInMW: 12000), language: .english)
    check(power.label == "Input" && power.value == "12.0 W", "Language English input power")
    let missing = activePowerInfo(reading: reading, io: IORegBattery(), language: .english)
    check(missing.value == "No data", "Language English missing power")
    let tips = batteryTips(usage: Usage24h(batterySeconds: 0, acSeconds: 0, minCharge: 12, highACSeconds: 28800, lowEpisodes: 2), temperatureCentiC: 3500, cycleCount: 850, language: .english)
    check(tips.count == 4 && tips.allSatisfy { !$0.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }, "Language English tips")
}
