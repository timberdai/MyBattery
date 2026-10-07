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
    var fans: [FanReading]?
    var usage: Usage24h?
}

// MARK: - App

final class App: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController!
    private var yieldClient: YieldClient!
    private var watcher: PowerSourceWatcher!
    private var latest: Snapshot?
    private var unavailableMessage = localized("正在读取数据…", "Reading…")

    // 24h cache: recomputed off the poll thread, at most every 10 min.
    private var usage24h: Usage24h?
    private var lastUsageComputed: Date?
    private let usageQueue = DispatchQueue(label: "com.timberdai.MyBattery.usage")
    private var usageComputing = false

    private let pollQueue = DispatchQueue(label: "com.timberdai.MyBattery.poll")
    private var pollState = BatteryPollState()

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
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.poll() }
            return
        }
        guard pollState.begin() else { return }
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            let battRaw = Shell.run(kPmset, ["-g", "batt"]) ?? ""
            let ioregRaw = Shell.run(kIoreg, ["-rn", "AppleSmartBattery"]) ?? ""
            let pmRaw = Shell.run(kPmset, ["-g"]) ?? ""

            guard let reading = validPmsetBatt(battRaw) else {
                DispatchQueue.main.async {
                    if self.latest == nil {
                        self.unavailableMessage = battRaw.contains("Now drawing from") && !battRaw.contains("InternalBattery")
                            ? localized("未检测到电池", "No battery") : localized("暂时无法读取", "Read failed")
                    }
                    let completion = self.pollState.finish(nil)
                    if completion.repoll { self.poll() }
                }
                return
            }

            var ioreg = parseIORegBattery(ioregRaw)
            if ioreg.temperatureCentiC == nil {
                ioreg.temperatureCentiC = SMCFansReader.shared.readBatteryTemperature()
            }
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

            let human: String? = time.isEmpty ? nil : compactMenuTime(time)

            var mbTime = reading.plugged ? time : (time.isEmpty ? "--:--" : time)
            if mbTime.hasSuffix(":00") {
                mbTime = String(mbTime.dropLast(3)) + "h"
            }

            let statusText = statusLabel(reading)

            var snap = Snapshot(reading: reading, ioreg: ioreg, powermode: powermode,
                                mbTime: mbTime, human: human, statusText: statusText,
                                fans: SMCFansReader.shared.readFans(), usage: nil)
            DispatchQueue.main.async {
                let completion = self.pollState.finish(snap.reading)
                snap.usage = self.usage24h
                self.latest = snap

                if completion.celebrate { PlugInGlowController.shared.celebrate() }

                self.render(snap)
                self.maybeRecomputeUsage()
                if completion.repoll { self.poll() }
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
            let item = NSMenuItem()
            item.view = ReadOnlyRowView(key: localized("状态", "Status"), val: unavailableMessage, valColor: .secondaryLabelColor, isBold: false)
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
            addAppActions(menu)
            return
        }
        let plugged = snap.reading.plugged
        let io = snap.ioreg
        let pct = snap.reading.percent
        let isChg = snap.reading.state == .charging

        // --- 1. 核心电量与供电状态 (单列拆行，纯展示不可点击) ---
        let pctValStr = pct.map { "\($0)%" } ?? localized("不可用", "No data")
        let pctColor: NSColor = plugged ? .systemGreen : (pct ?? 100 <= 20 ? .systemRed : .labelColor)
        addKeyValueItem(menu, key: localized("电池电量", "Charge"), value: pctValStr, valueColor: pctColor, isBold: true)

        let modeVal = batterySupplyLabel(snap.reading, io: io)
        addKeyValueItem(menu, key: localized("供电状态", "Power"), value: modeVal, valueColor: isChg ? .systemGreen : .labelColor, isBold: true)

        let pInfo = activePowerInfo(snap)
        addKeyValueItem(
            menu,
            key: pInfo.label,
            value: pInfo.value,
            valueColor: pInfo.isGreen ? .systemGreen : .labelColor,
            isBold: true
        )

        let timeRemainingVal: String = {
            if plugged {
                if isChg {
                    return snap.human ?? localized("计算中…", "Estimating…")
                } else {
                    return localized("未在充电", "Not charging")
                }
            } else {
                return snap.human ?? localized("计算中…", "Estimating…")
            }
        }()
        addKeyValueItem(menu, key: isChg ? localized("充满时间", "Time to full") : (plugged ? localized("充电状态", "Charge state") : localized("续航时间", "Time left")), value: timeRemainingVal, valueColor: .labelColor, isBold: false)

        // --- 2. 电池健康与硬件容量 (纯展示不可点击) ---
        menu.addItem(.separator())

        if let h = io.officialMaxCapacity ?? healthPercent(rawMax: io.rawMaxCapacity, design: io.designCapacity) {
            addKeyValueItem(menu, key: localized("电池健康", "Health"), value: "\(h)%", valueColor: .systemGreen, isBold: true)
        }
        if let cyc = io.cycleCount {
            addKeyValueItem(menu, key: localized("循环次数", "Cycles"), value: cycleMenuValue(cyc), valueColor: .labelColor, isBold: false)
        }
        if let cur = io.rawCurrentCapacity {
            addKeyValueItem(menu, key: localized("当前容量", "Current"), value: capacityMenuValue(cur), valueColor: .labelColor, isBold: false)
        }
        if let mx = io.rawMaxCapacity {
            addKeyValueItem(menu, key: localized("全充容量", "Full"), value: capacityMenuValue(mx), valueColor: .labelColor, isBold: false)
        }
        if let des = io.designCapacity {
            addKeyValueItem(menu, key: localized("设计容量", "Design"), value: capacityMenuValue(des), valueColor: .labelColor, isBold: false)
        }
        if let temp = io.temperatureCentiC {
            let tempC = Double(temp) / 100.0
            let tStr = DisplayPrefs.tempUnit == "F" ? String(format: "%.1f °F", tempC * 9 / 5 + 32) : String(format: "%.1f °C", tempC)
            addKeyValueItem(menu, key: localized("电池温度", "Battery temp"), value: tStr, valueColor: .labelColor, isBold: false)
        }
        if let fans = snap.fans, !fans.isEmpty {
            let maxRpm = fans.map(\.rpm).max() ?? 0
            let fanStr = maxRpm < 50 ? localized("停转 (静音)", "Stopped") : String(format: "%.0f RPM", maxRpm)
            addKeyValueItem(menu, key: localized("散热风扇", "Fan"), value: fanStr, valueColor: .labelColor, isBold: false)
        }

        // --- 3. 电源适配器详情 (纯展示不可点击) ---
        if plugged {
            menu.addItem(.separator())
            let adapterStr = formattedAdapterLine(io)
            addKeyValueItem(menu, key: localized("电源适配器", "Adapter"), value: adapterStr, valueColor: .labelColor, isBold: false)
            if let profile = adapterPowerProfile(io) {
                addKeyValueItem(menu, key: localized("握手档位", "PD profile"), value: profile)
            }
        }

        // --- 4. 24 小时使用统计 (纯展示不可点击) ---
        if let usage = snap.usage, let lines = usageLines(usage) {
            menu.addItem(.separator())
            addHeaderItem(menu, title: localized("24小时使用统计", "Last 24 hours"))

            func stripPrefix(_ str: String) -> String {
                if let colon = str.firstIndex(of: ":") {
                    return String(str[str.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                }
                return str
            }

            addKeyValueItem(menu, key: localized("电池", "Battery"), value: stripPrefix(lines.0), valueColor: .labelColor, isBold: false)
            addKeyValueItem(menu, key: localized("供电", "AC"), value: stripPrefix(lines.1), valueColor: .labelColor, isBold: false)
        }

        // --- 5. 菜单栏显示与设置 ---
        menu.addItem(.separator())
        addHeaderItem(menu, title: localized("状态栏显示", "Menu bar display"))

        let controlItem = NSMenuItem()
        let controlView = MenuBarDisplayControlView()
        controlItem.view = controlView
        controlItem.isEnabled = true
        menu.addItem(controlItem)

        let glowItem = NSMenuItem(title: localized("插电特效", "Plug-in Glow"), action: #selector(toggleGlow(_:)), keyEquivalent: "")
        glowItem.target = self
        glowItem.state = PlugInGlowController.shared.isEnabled ? .on : .off
        menu.addItem(glowItem)

        addAppActions(menu)
    }

    // Keep settings and quit available even before the first valid sample.
    private func addAppActions(_ menu: NSMenu) {
        let login = NSMenuItem(title: localized("登录时启动", "Launch at Login"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let settings = NSMenuItem(title: localized("打开“电池”设置…", "Battery Settings…"), action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        // --- 6. 版本与退出 ---
        menu.addItem(.separator())
        addKeyValueItem(menu, key: "MyBattery", value: AppVersion.shortString)
        menu.items.last?.toolTip = AppVersion.string
        let quitItem = NSMenuItem(title: localized("退出", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private func addHeaderItem(_ menu: NSMenu, title: String) {
        let item = NSMenuItem()
        item.view = ReadOnlyHeaderView(title: title)
        item.isEnabled = false
        menu.addItem(item)
    }

    /// 纯展示只读行：鼠标 hover 绝不高亮选中变蓝，文字保持高对比度
    private func addKeyValueItem(
        _ menu: NSMenu,
        key: String,
        value: String,
        valueColor: NSColor = .labelColor,
        isBold: Bool = false
    ) {
        let item = NSMenuItem()
        item.view = ReadOnlyRowView(key: key, val: value, valColor: valueColor, isBold: isBold)
        item.isEnabled = false
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

    @objc private func toggleGlow(_ sender: NSMenuItem) {
        let glow = PlugInGlowController.shared
        glow.isEnabled.toggle()
        sender.state = glow.isEnabled ? .on : .off
        if glow.isEnabled { glow.celebrate() }
    }

    @objc private func openSettings() {
        _ = Shell.run(kOpen, [kSettingsURL])
    }

    @objc private func showTips(_ sender: NSMenuItem) {
        guard let tips = sender.representedObject as? [String] else { return }
        let alert = NSAlert()
        alert.messageText = localized("电池养护提示", "Battery care tips")
        alert.informativeText = tips.map { "💡 \($0)" }.joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func activePowerInfo(_ snap: Snapshot) -> (label: String, value: String, isGreen: Bool) {
        BatteryTimeCore.activePowerInfo(reading: snap.reading, io: snap.ioreg)
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
        if let cur = io.rawCurrentCapacity, let mx = io.rawMaxCapacity {
            parts.append("\(cur) / \(mx) mAh")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 && m > 0 { return localized("\(h)小时\(m)分", "\(h)h\(m)m") }
        if h > 0 { return localized("\(h)小时", "\(h)h") }
        return localized("\(m)分钟", "\(m)m")
    }

    private func usageLines(_ u: Usage24h) -> (String, String)? {
        let total = u.batterySeconds + u.acSeconds
        guard total > 0 else { return nil }
        let pb = (u.batterySeconds * 100 + total / 2) / total
        let pa = 100 - pb
        let bTime = compactDuration(u.batterySeconds)
        let aTime = compactDuration(u.acSeconds)
        let battLine = "\(localized("电池", "Battery")): \(bTime) (\(pb)%)"
        let acLine = "\(localized("供电", "AC")): \(aTime) (\(pa)%)"
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
        case .notCharging: return localized("已连接电源（未充电）", "Connected (not charging)")
        case .charging: return localized("充电中", "Charging")
        case .charged: return localized("已充满", "Fully charged")
        default: return localized("已连接电源", "Connected")
        }
    }
    return localized("使用电池", "On battery")
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

// MARK: - Read-Only Views (No hover highlight, compact width)

final class ReadOnlyHeaderView: NSView {
    private let title: String

    init(title: String) {
        self.title = title
        super.init(frame: NSRect(x: 0, y: 0, width: 176, height: 17))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 176, height: 17)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let font = NSFont.systemFont(ofSize: 11.0, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        (title as NSString).draw(at: NSPoint(x: 10, y: 2), withAttributes: attrs)
    }
}

// MARK: - Menu Bar Display Segmented Control (Compact Width)

final class MenuBarDisplayControlView: NSView {
    private let segmented: NSSegmentedControl

    override init(frame frameRect: NSRect) {
        self.segmented = NSSegmentedControl(labels: [localized("图标", "Icon"), localized("电量", "Charge"), localized("时间", "Time")], trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: NSRect(x: 0, y: 0, width: 176, height: 25))

        segmented.frame = NSRect(x: 8, y: 2, width: 160, height: 21)
        segmented.controlSize = .small
        segmented.segmentStyle = .texturedRounded
        segmented.target = self
        segmented.action = #selector(segmentChanged(_:))
        updateSelection()
        addSubview(segmented)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 176, height: 25)
    }

    func updateSelection() {
        if DisplayPrefs.showTime {
            segmented.selectedSegment = 2
        } else if DisplayPrefs.showPct {
            segmented.selectedSegment = 1
        } else {
            segmented.selectedSegment = 0
        }
    }

    @objc private func segmentChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            DisplayPrefs.showIcon = true
            DisplayPrefs.showPct = false
            DisplayPrefs.showTime = false
        case 1:
            DisplayPrefs.showIcon = true
            DisplayPrefs.showPct = true
            DisplayPrefs.showTime = false
        case 2:
            DisplayPrefs.showIcon = true
            DisplayPrefs.showPct = false
            DisplayPrefs.showTime = true
        default:
            break
        }
        (NSApp.delegate as? App)?.refreshNow()
    }
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
