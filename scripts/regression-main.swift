import AppKit

@main
struct RegressionMain {
    static func main() {
        var assertions = 0, failures = 0
        func check(_ passed: Bool, _ name: String) {
            assertions += 1
            if !passed { failures += 1 }
            print("\(passed ? "PASS" : "FAIL") \(name)")
        }
        if CommandLine.arguments.contains("--language-probe") {
            print("LANGUAGE_PREFERENCES=\(Locale.preferredLanguages)")
            print("LANGUAGE_RESOLVED=\(AppLanguage.system)")
            print("LANGUAGE_TEXT=\(localized("状态", "Status"))")
            print("LANGUAGE_TIME=\(compactMenuTime("1:20"))")
            return
        }
        if CommandLine.arguments.contains("--glow") {
            runGlowRound2(check)
        } else {
            runCoreRound2(check)
            runLocalizationCases(check)
            runSMCRound2(check)
            _ = NSApplication.shared
            let version = (try? String(contentsOfFile: "VERSION"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
            var rows: [(String, String, Bool)] = []
            for proto in ["USB-PD", "usb", "MagSafe", String(repeating: "long", count: 100)] {
                for watts in [nil, 140, 240, 1000, Int.max] as [Int?] {
                    rows.append(("电源适配器", formattedAdapterLine(IORegBattery(adapterName: "96W USB-C Power Adapter", adapterWatts: watts, adapterProtocol: proto), language: .chinese), false))
                }
            }
            for time in ["1:20", "99:59", "0:59", "99:00", String(Int.max) + ":59"] {
                for key in ["充满时间", "续航时间"] { rows.append((key, compactMenuTime(time, language: .chinese), false)) }
            }
            for n in [0, 99999, 100000, Int.max, -1] {
                for key in ["当前容量", "全充容量", "设计容量"] { rows.append((key, capacityMenuValue(n, language: .chinese), false)) }
                rows.append(("循环次数", cycleMenuValue(n, language: .chinese), false))
            }
            for label in ["充电功率", "放电功率", "输入功率", "负载功率"] {
                for value in ["1000.0 W", "暂无数据"] { rows.append((label, value, true)) }
            }
            rows += [("握手档位", "1000 W", false), ("MyBattery", version, false), ("状态", "未检测到电池", false), ("状态", "暂时无法读取", false), ("供电状态", "外接电源 · 放电", true)]
            rows += [("电池温度", "150.0 °C", false), ("电池温度", "-50.0 °C", false), ("电池温度", "302.0 °F", false), ("散热风扇", "100000 RPM", false), ("散热风扇", "停转 (静音)", false), ("状态", "正在读取数据…", false), ("电池电量", "100%", true), ("电池健康", "100%", true), ("供电状态", "外接供电 (旁路)", true), ("供电状态", "已充满 (供电)", true), ("电池", "23小时59分 (100%)", false), ("供电", "24小时 (100%)", false)]
            // English uses the same production formatters and full-size fonts.
            var englishRows: [(String, String, Bool)] = []
            for proto in ["USB-PD", "usb", "MagSafe", String(repeating: "long", count: 100)] {
                for watts in [nil, 140, 240, 1000, Int.max] as [Int?] {
                    englishRows.append(("Adapter", formattedAdapterLine(IORegBattery(adapterWatts: watts, adapterProtocol: proto), language: .english), false))
                }
            }
            for time in ["1:20", "99:59", "0:59", "99:00", String(Int.max) + ":59"] {
                for key in ["Time to full", "Time left"] { englishRows.append((key, compactMenuTime(time, language: .english), false)) }
            }
            for n in [0, 99999, 100000, Int.max, -1] {
                for key in ["Current", "Full", "Design"] { englishRows.append((key, capacityMenuValue(n, language: .english), false)) }
                englishRows.append(("Cycles", cycleMenuValue(n, language: .english), false))
            }
            for label in ["Charging", "Discharge", "Input", "Load"] {
                for value in ["1000.0 W", "No data"] { englishRows.append((label, value, true)) }
            }
            for state in [PowerState.charging, .discharging, .charged, .notCharging] {
                let reading = BatteryReading(percent: state == .charged ? 100 : 80, plugged: true, state: state, rawTime: nil)
                englishRows.append(("Power", batterySupplyLabel(reading, io: IORegBattery(), language: .english), true))
            }
            englishRows += [("PD profile", "1000 W", false), ("MyBattery", version, false), ("Status", "No battery", false), ("Status", "Read failed", false), ("Status", "Reading…", false), ("Charge", "100%", true), ("Health", "100%", true), ("Charge state", "Not charging", false), ("Time to full", "Estimating…", false), ("Battery temp", "150.0 °C", false), ("Battery temp", "-50.0 °C", false), ("Battery temp", "302.0 °F", false), ("Fan", "100000 RPM", false), ("Fan", "Stopped", false), ("Battery", "23h59m (100%)", false), ("AC", "24h (100%)", false)]
            rows += englishRows
            print("ENGLISH_WIDTH_ROWS=\(englishRows.count)")
            for (key, value, bold) in rows {
                let width = ReadOnlyRowView.requiredWidth(key: key, val: value, isBold: bold)
                check(width <= 176, "R04 width \(key): \(value) = \(width) pt")
            }
            print("WIDTH_ROWS=\(rows.count)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
            process.arguments = ["-rn", "AppleSmartBattery"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try! process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let liveIO = parseIORegBattery(String(data: data, encoding: .utf8) ?? "")
            print("LIVE_ADAPTER=description:\(String(describing: liveIO.adapterProtocol)) display:\(formattedAdapterLine(liveIO)) profile:\(String(describing: adapterPowerProfile(liveIO))) held:\(String(describing: liveIO.notChargingReason))")
            print("LIVE_BATTERY_TEMPERATURE=\(String(describing: SMCFansReader.shared.readBatteryTemperature()))")
            print("LIVE_IOREG=design:\(String(describing: liveIO.designCapacity)) current:\(String(describing: liveIO.rawCurrentCapacity)) health:\(String(describing: liveIO.officialMaxCapacity)) temperature:\(String(describing: liveIO.temperatureCentiC)) inputMW:\(String(describing: liveIO.systemPowerInMW))")
            check(process.terminationStatus == 0 && liveIO.designCapacity != nil && liveIO.rawCurrentCapacity != nil, "R05 real ioreg parsed")
            if let index = CommandLine.arguments.firstIndex(of: "--render"), index + 1 < CommandLine.arguments.count {
                let columns = 4, rowCount = (rows.count + 3) / 4
                let size = NSSize(width: columns * 190, height: rowCount * 23 + 16)
                let sheet = NSImage(size: size)
                sheet.lockFocus()
                NSColor.windowBackgroundColor.setFill()
                NSRect(origin: .zero, size: size).fill()
                for (index, row) in rows.enumerated() {
                    let view = ReadOnlyRowView(key: row.0, val: row.1, isBold: row.2)
                    if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        let image = NSImage(size: view.bounds.size)
                        image.addRepresentation(bitmap)
                        image.draw(in: NSRect(x: (index / rowCount) * 190 + 7,
                            y: Int(size.height) - (index % rowCount + 1) * 23 - 5, width: 176, height: 19))
                    }
                }
                sheet.unlockFocus()
                let bitmap = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
                try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                print("OFFSCREEN_RENDER=\(CommandLine.arguments[index + 1])")
            }
            let fans = SMCFansReader.shared.readFans()
            print("LIVE_READ_ONLY_FANS=\(String(describing: fans))")
            // This probes real production hardware reads without a fan-control write.
            check(fans != nil, "R01 local hardware FNum/RPM readable")
        }
        print("ASSERTIONS=\(assertions) FAILURES=\(failures)")
        exit(failures == 0 ? 0 : 1)
    }
}
