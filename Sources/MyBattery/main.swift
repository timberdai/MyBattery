// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit
import BatteryTimeCore
import StatusItemKit

// MARK: - Tool paths

private let kPmset = "/usr/bin/pmset"
private let kIoreg = "/usr/sbin/ioreg"
private let kOpen = "/usr/bin/open"
private let kSettingsURL = "x-apple.systempreferences:com.apple.Battery-Settings.extension"

// MARK: - Polled snapshot of everything the title + menu need

struct Snapshot {
    var reading: BatteryReading
    var ioreg: IORegBattery
    var powermode: Int?          // 0 Automatic, 1 Low, 2 High
    var mbTime: String           // menu-bar time string ("1:46", "19h", "--:--", or "")
    var human: String?           // humanized time for the dropdown detail line
    var statusText: String       // "On battery", "Charging", ...
    var usage: Usage24h?
}

// MARK: - App

final class App: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController!
    private var yieldClient: YieldClient!
    private var watcher: PowerSourceWatcher!
    private var latest: Snapshot?

    // 24h cache: recomputed off the poll thread, at most every 10 min.
    private var usage24h: Usage24h?
    private var lastUsageComputed: Date?
    private let usageQueue = DispatchQueue(label: "com.timberdai.MyBattery.usage")
    private var usageComputing = false

    private let pollQueue = DispatchQueue(label: "com.timberdai.MyBattery.poll")
    private var pollInFlight = false
    private var pollPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController(
            pollInterval: 5,
            onPoll: { [weak self] in self?.poll() },
            onBuildMenu: { [weak self] menu in self?.buildMenu(menu) }
        )
        controller.start()
        yieldClient = YieldClient(item: controller)
        yieldClient.start()

        watcher = PowerSourceWatcher(onChange: { [weak self] in self?.refreshNow() })
        watcher.start()
    }

    // MARK: Poll

    func refreshNow() { poll() }

    private func poll() {
        if pollInFlight { pollPending = true; return }
        pollInFlight = true
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            let battRaw = Shell.run(kPmset, ["-g", "batt"]) ?? ""
            let ioregRaw = Shell.run(kIoreg, ["-rn", "AppleSmartBattery"]) ?? ""
            let pmRaw = Shell.run(kPmset, ["-g"]) ?? ""

            let reading = parsePmsetBatt(battRaw)
            let ioreg = parseIORegBattery(ioregRaw)
            let powermode = parsePowermode(pmRaw)

            var time = ""
            switch reading.state {
            case .discharging:
                if let raw = reading.rawTime {
                    let mins = (hhmmToMinutes(raw) * 95) / 100
                    time = minutesToHHMM(mins)
                }
            case .charging:
                if let raw = reading.rawTime { time = raw }
            default:
                break
            }
            if !reading.plugged, time.isEmpty, let rawCur = ioreg.rawCurrentCapacity {
                if let emins = etaStopgapMinutes(rawCurrent: rawCur, voltageMV: ioreg.voltageMV,
                                                 instantAmperageRaw: ioreg.instantAmperageRaw) {
                    time = minutesToHHMM(emins)
                }
            }

            let human: String? = time.isEmpty ? nil : humanize(time)

            var mbTime = reading.plugged ? time : (time.isEmpty ? "--:--" : time)
            if mbTime.hasSuffix(":00") {
                mbTime = String(mbTime.dropLast(3)) + "h"
            }

            let statusText = statusLabel(reading)

            var snap = Snapshot(reading: reading, ioreg: ioreg, powermode: powermode,
                                mbTime: mbTime, human: human, statusText: statusText,
                                usage: nil)
            DispatchQueue.main.async {
                self.pollInFlight = false
                snap.usage = self.usage24h
                self.latest = snap
                self.render(snap)
                self.maybeRecomputeUsage()
                if self.pollPending { self.pollPending = false; self.poll() }
            }
        }
    }

    // MARK: Render the status item

    private func render(_ snap: Snapshot) {
        let pct = snap.reading.percent
        let isCharging = snap.reading.state == .charging

        let fill: BatteryFill
        if snap.powermode == 2 { fill = .blue }
        else if snap.powermode == 1 { fill = .yellow }
        else if !isCharging, !snap.reading.plugged, let p = pct, p <= 20 { fill = .red }
        else { fill = .none }

        let showIcon = DisplayPrefs.showIcon
        let showPct = DisplayPrefs.showPct
        let showTime = DisplayPrefs.showTime

        var trailingParts: [String] = []
        if showPct, let p = pct {
            trailingParts.append("\(p)%")
        }
        if showTime, !snap.mbTime.isEmpty {
            trailingParts.append(snap.mbTime)
        }
        let trailingTxt = trailingParts.joined(separator: " ")

        let glyph = showIcon && pct != nil

        if glyph {
            let ink = NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .white : .black
            }
            let image = BatteryGlyph.image(
                pct: pct!,
                charging: isCharging,
                plugged: snap.reading.plugged,
                lead: "",
                trailing: trailingTxt,
                ink: ink,
                fill: fill
            )
            controller.setIcon(image)
        } else {
            var parts: [String] = []
            if let p = pct, showPct || showIcon { parts.append("\(p)%") }
            if showTime, !snap.mbTime.isEmpty { parts.append(snap.mbTime) }
            let text = parts.isEmpty ? "--:--" : parts.joined(separator: " ")
            controller.setTitle(text, warn: false)
        }
    }

    // MARK: Build the dropdown

    private func buildMenu(_ menu: NSMenu) {
        menu.autoenablesItems = false
        guard let snap = latest else {
            let item = NSMenuItem(title: "…", action: nil, keyEquivalent: "")
            item.isEnabled = true
            menu.addItem(item)
            return
        }
        let plugged = snap.reading.plugged
        let io = snap.ioreg
        let pct = snap.reading.percent
        let isChg = snap.reading.state == .charging

        // --- 0. CodexBar 风格电量卡片与微型进度条 ---
        if let p = pct {
            let isBypass = plugged && (!isChg && (io.notChargingReason == 16777216 || p == 80))
            let badgeText: String = {
                if plugged {
                    if isChg { return "⚡️ 充电中" }
                    else if isBypass { return "外接供电 · 旁路保护" }
                    else { return "外接电源" }
                } else {
                    return "🔋 电池供电"
                }
            }()
            let pInfo = activePowerInfo(snap)
            let subText: String = {
                if plugged {
                    let adp = io.adapterWatts.map { "适配器 \($0)W" } ?? "外接电源"
                    return "\(pInfo.label): \(pInfo.value) · \(adp)"
                } else {
                    let eta = snap.human.map { "约剩余 \($0)" } ?? "放电中"
                    return "\(pInfo.label): \(pInfo.value) · \(eta)"
                }
            }()
            let cardProps = BatteryMenuCardView.Props(
                percent: p,
                plugged: plugged,
                isCharging: isChg,
                isBypass: isBypass,
                statusBadgeText: badgeText,
                subtitleText: subText
            )
            let cardView = BatteryMenuCardView(props: cardProps)
            let cardItem = MenuCardMenuItem()
            cardItem.view = cardView
            cardItem.isEnabled = true
            menu.addItem(cardItem)
            menu.addItem(.separator())
        }

        // --- 1. 核心供电与功率指标 ---
        let modeVal: String = {
            if plugged {
                if isChg {
                    let eta = snap.human.map { " (还有 \($0)充满)" } ?? ""
                    return "充电中\(eta)"
                } else {
                    let reason = (io.notChargingReason == 16777216 || pct == 80) ? " (80%上限保护)" : ""
                    return "外接电源 · 旁路供电\(reason)"
                }
            } else {
                let eta = snap.human.map { " (约剩余 \($0))" } ?? ""
                return "电池供电\(eta)"
            }
        }()
        addKeyValueItem(menu, key: "供电状态", value: modeVal, valueColor: isChg ? .systemGreen : .labelColor, isBold: true)

        let pInfo = activePowerInfo(snap)
        addKeyValueItem(
            menu,
            key: pInfo.label,
            value: pInfo.value,
            valueSuffix: pInfo.subtext.isEmpty ? "" : " \(pInfo.subtext)",
            valueColor: pInfo.isGreen ? .systemGreen : .labelColor,
            isBold: true
        )

        let timeRemainingVal: String = {
            if plugged {
                if isChg {
                    return snap.human.map { "预计 \($0)" } ?? "正在计算..."
                } else {
                    return "未在充电"
                }
            } else {
                return snap.human.map { "预计可用 \($0)" } ?? "正在计算..."
            }
        }()
        addKeyValueItem(menu, key: isChg ? "充满时间" : "续航时间", value: timeRemainingVal, valueColor: .labelColor, isBold: false)

        // --- 2. 电池健康与硬件容量 ---
        menu.addItem(.separator())

        if let h = healthPercent(rawMax: io.rawMaxCapacity, design: io.designCapacity) {
            addKeyValueItem(menu, key: "电池健康", value: "\(h)%", valueColor: .systemGreen, isBold: true)
        }
        if let cyc = io.cycleCount {
            addKeyValueItem(menu, key: "循环次数", value: "\(cyc) 次", valueColor: .labelColor, isBold: true)
        }
        if let cur = io.rawCurrentCapacity {
            addKeyValueItem(menu, key: "当前容量", value: "\(cur) mAh", valueColor: .labelColor, isBold: false)
        }
        if let mx = io.rawMaxCapacity {
            let desStr = io.designCapacity.map { " (设计 \($0) mAh)" } ?? ""
            addKeyValueItem(menu, key: "全负荷容量", value: "\(mx) mAh\(desStr)", valueColor: .labelColor, isBold: false)
        }

        // --- 3. 电源适配器详情 (插电时显示) ---
        if plugged {
            menu.addItem(.separator())
            let adapterStr = formattedAdapterLine(io)
            addKeyValueItem(menu, key: "电源适配器", value: adapterStr, valueColor: .labelColor, isBold: false)
        }

        // --- 4. 24 小时用电统计 (精炼单行) ---
        if let usage = snap.usage, let lines = usageLines(usage) {
            menu.addItem(.separator())
            let uItem = NSMenuItem(title: "24小时用电: \(lines.0) · \(lines.1)", action: nil, keyEquivalent: "")
            uItem.attributedTitle = NSAttributedString(
                string: "24小时用电: \(lines.0) · \(lines.1)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11.5),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            uItem.isEnabled = true
            menu.addItem(uItem)
        }

        // --- 5. 菜单栏显示与设置 ---
        menu.addItem(.separator())
        let sHeader = NSMenuItem(title: "设置", action: nil, keyEquivalent: "")
        sHeader.attributedTitle = NSAttributedString(
            string: "设置",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        sHeader.isEnabled = false
        menu.addItem(sHeader)

        addToggle(menu, title: "电池图标", on: DisplayPrefs.showIcon, action: #selector(toggleIcon))
        addToggle(menu, title: "电量百分比", on: DisplayPrefs.showPct, action: #selector(togglePct))
        addToggle(menu, title: "剩余时间", on: DisplayPrefs.showTime, action: #selector(toggleTime))

        let login = NSMenuItem(title: "登录时启动", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let settings = NSMenuItem(title: "打开“电池”设置…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        // --- 6. 版本与退出 ---
        menu.addItem(.separator())
        let verItem = NSMenuItem(title: "MyBattery v0.1.0", action: nil, keyEquivalent: "")
        verItem.isEnabled = false
        verItem.attributedTitle = NSAttributedString(
            string: "MyBattery v0.1.0",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
        )
        menu.addItem(verItem)
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
    }

    /// 高对比度富文本菜单项：左侧次级灰色优雅标签，右侧清晰主色数值
    private func addKeyValueItem(
        _ menu: NSMenu,
        key: String,
        value: String,
        valueSuffix: String = "",
        valueColor: NSColor = .labelColor,
        isBold: Bool = false
    ) {
        let item = NSMenuItem(title: "\(key): \(value)\(valueSuffix)", action: nil, keyEquivalent: "")
        item.isEnabled = true
        let attr = NSMutableAttributedString()
        let keyFont = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        let valFont = isBold ? NSFont.systemFont(ofSize: 13, weight: .semibold) : NSFont.systemFont(ofSize: 13, weight: .regular)

        attr.append(NSAttributedString(
            string: key + ":  ",
            attributes: [
                .font: keyFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        attr.append(NSAttributedString(
            string: value,
            attributes: [
                .font: valFont,
                .foregroundColor: valueColor
            ]
        ))
        if !valueSuffix.isEmpty {
            attr.append(NSAttributedString(
                string: valueSuffix,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            ))
        }
        item.attributedTitle = attr
        menu.addItem(item)
    }

    private func addToggle(_ menu: NSMenu, title: String, on: Bool, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        menu.addItem(item)
    }

    // MARK: Menu actions

    @objc private func toggleTempUnit() {
        DisplayPrefs.tempUnit = DisplayPrefs.tempUnit == "C" ? "F" : "C"
        poll()
    }

    @objc private func toggleIcon() { DisplayPrefs.showIcon.toggle(); rerender() }
    @objc private func togglePct() { DisplayPrefs.showPct.toggle(); rerender() }
    @objc private func toggleTime() { DisplayPrefs.showTime.toggle(); rerender() }

    private func rerender() { if let s = latest { render(s) } }

    @objc private func toggleLogin() { LoginItem.toggle() }

    @objc private func openSettings() {
        _ = Shell.run(kOpen, [kSettingsURL])
    }

    @objc private func showTips(_ sender: NSMenuItem) {
        guard let tips = sender.representedObject as? [String] else { return }
        let alert = NSAlert()
        alert.messageText = "电池养护提示"
        alert.informativeText = tips.map { "💡 \($0)" }.joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func activePowerInfo(_ snap: Snapshot) -> (label: String, value: String, subtext: String, isGreen: Bool) {
        let io = snap.ioreg
        let plugged = snap.reading.plugged
        let isChg = snap.reading.state == .charging

        if plugged {
            // 插电模式：输入功率 (适配器供入整机的真实功率)
            if let sysMW = io.systemPowerInMW, sysMW > 0 {
                let watts = Double(sysMW) / 1000.0
                let wStr = String(format: "%.1f W", watts)
                if isChg {
                    return ("输入功率", wStr, "(快速充电中)", true)
                } else {
                    return ("输入功率", wStr, "(电源直接供电，电池闲置)", false)
                }
            } else if let sysLoad = io.systemLoadMW, sysLoad > 0 {
                let watts = Double(sysLoad) / 1000.0
                let wStr = String(format: "%.1f W", watts)
                return ("输入功率", wStr, "(整机运行供电)", false)
            } else if isChg, let v = io.voltageMV, let amp = io.instantAmperageRaw,
                      let mag = dischargeMagnitude(instantAmperageRaw: amp), amp.count < 11 {
                let watts = Double(v) * Double(mag) / 1_000_000.0
                return ("输入功率", String(format: "%.1f W", watts), "(充入电池功率)", true)
            } else {
                return ("输入功率", "供电中", "(电池闲置保护)", false)
            }
        } else {
            // 放电模式：当前功耗 (电池放电给整机的实时功耗)
            if let v = io.voltageMV, let amp = io.instantAmperageRaw,
               let mag = dischargeMagnitude(instantAmperageRaw: amp) {
                let watts = Double(v) * Double(mag) / 1_000_000.0
                let wStr = String(format: "%.1f W", watts)
                return ("当前功耗", wStr, "(整机电池放电)", false)
            } else if let sysLoad = io.systemLoadMW, sysLoad > 0 {
                let watts = Double(sysLoad) / 1000.0
                let wStr = String(format: "%.1f W", watts)
                return ("当前功耗", wStr, "(整机运行功耗)", false)
            } else {
                return ("当前功耗", "计算中…", "", false)
            }
        }
    }

    private func formattedAdapterLine(_ io: IORegBattery) -> String {
        var parts: [String] = []
        if let p = io.adapterProtocol { parts.append(p) }
        if let w = io.adapterWatts { parts.append("\(w) W") }
        else if let name = io.adapterName { parts.append(name) }

        var specParts: [String] = []
        if let v = io.adapterVoltageMV {
            specParts.append(String(format: "%.1f V", Double(v) / 1000.0))
        }
        if let cur = io.adapterCurrentMA {
            specParts.append(String(format: "%.1f A", Double(cur) / 1000.0))
        }
        if !specParts.isEmpty {
            parts.append("(\(specParts.joined(separator: " / ")))")
        }
        return parts.isEmpty ? "已连接" : parts.joined(separator: " ")
    }

    private func extrasLine(_ snap: Snapshot) -> String? {
        let io = snap.ioreg
        var parts: [String] = []
        if let t = io.temperatureCentiC {
            if DisplayPrefs.tempUnit == "F" {
                parts.append("\(fahrenheit(fromCentiC: t))°F")
            } else {
                parts.append("\(celsius(fromCentiC: t))°C")
            }
        }
        if let v = io.voltageMV {
            parts.append(String(format: "%.1f V", Double(v) / 1000.0))
        }
        if let cur = io.rawCurrentCapacity, let mx = io.rawMaxCapacity {
            parts.append("\(cur) / \(mx) mAh")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 && m > 0 { return "\(h)小时\(m)分" }
        if h > 0 { return "\(h)小时" }
        return "\(m)分钟"
    }

    private func usageLines(_ u: Usage24h) -> (String, String)? {
        let total = u.batterySeconds + u.acSeconds
        guard total > 0 else { return nil }
        let pb = (u.batterySeconds * 100 + total / 2) / total
        let pa = 100 - pb
        let bTime = compactDuration(u.batterySeconds)
        let aTime = compactDuration(u.acSeconds)
        let battLine = "电池: \(bTime) (\(pb)%)"
        let acLine = "供电: \(aTime) (\(pa)%)"
        return (battLine, acLine)
    }

    // MARK: 24h usage recompute (off the poll thread, <= every 10 min)

    private func maybeRecomputeUsage() {
        let stale: Bool
        if let last = lastUsageComputed {
            stale = Date().timeIntervalSince(last) > 600
        } else {
            stale = true
        }
        guard stale, !usageComputing else { return }
        usageComputing = true
        usageQueue.async { [weak self] in
            let log = Shell.run(kPmset, ["-g", "log"]) ?? ""
            let usage = parsePmsetLog(log, now: Date())
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.usage24h = usage
                self.lastUsageComputed = Date()
                self.usageComputing = false
                if var snap = self.latest {
                    snap.usage = usage
                    self.latest = snap
                }
            }
        }
    }
}

// MARK: - Free helpers

private func statusLabel(_ r: BatteryReading) -> String {
    if r.plugged {
        switch r.state {
        case .notCharging: return "已连接电源（未充电）"
        case .charging: return "充电中"
        case .charged: return "已充满"
        default: return "已连接电源"
        }
    }
    return "使用电池"
}

private func parsePowermode(_ raw: String) -> Int? {
    for line in raw.split(separator: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("powermode") {
            let comps = t.split(separator: " ", omittingEmptySubsequences: true)
            if comps.count >= 2 { return Int(comps[1]) }
        }
    }
    return nil
}

private func hhmmToMinutes(_ hmm: String) -> Int {
    let parts = hmm.split(separator: ":")
    let h = parts.count > 0 ? Int(parts[0]) ?? 0 : 0
    let m = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    return h * 60 + m
}

private func minutesToHHMM(_ mins: Int) -> String {
    String(format: "%d:%02d", mins / 60, mins % 60)
}

// MARK: - Menu card wrapper item

/// Card rows draw their own appearance; suppress AppKit default highlight
final class MenuCardMenuItem: NSMenuItem {
    override var isHighlighted: Bool {
        get { false }
        set { }
    }
}

// MARK: - Entry point

LoginCLI.runIfRequested()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
