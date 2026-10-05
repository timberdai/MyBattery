// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith & contributors

import AppKit

/// CodexBar 风格的微型电量卡片与进度条视图，专为嵌入 NSMenuItem 设计。
/// 具备 100% 系统毛玻璃穿透 (allowsVibrancy)、动态深浅自适应、Retina 像素级清晰。
final class BatteryMenuCardView: NSView {

    struct Props {
        let percent: Int
        let plugged: Bool
        let isCharging: Bool
        let isBypass: Bool
        let statusBadgeText: String
        let subtitleText: String
    }

    private let props: Props

    init(props: Props) {
        self.props = props
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 68))
        self.autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var allowsVibrancy: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 68)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds
        let sidePadding: CGFloat = 16.0
        let contentWidth = bounds.width - (sidePadding * 2)

        // 1. 顶部行：大号电量百分比 + 右侧胶囊状态徽章
        // macOS NSView 坐标系原点在左下角 (y 从下往上增)
        let topRowY: CGFloat = bounds.height - 28.0

        // 1.1 大号电量百分比
        let pctStr = "\(props.percent)%"
        let pctColor: NSColor = props.plugged
            ? .systemGreen
            : (props.percent <= 20 ? .systemRed : .labelColor)

        let pctFont = NSFont.systemFont(ofSize: 20, weight: .bold)
        let pctAttrs: [NSAttributedString.Key: Any] = [
            .font: pctFont,
            .foregroundColor: pctColor
        ]
        let pctSize = (pctStr as NSString).size(withAttributes: pctAttrs)
        (pctStr as NSString).draw(
            at: NSPoint(x: sidePadding, y: topRowY),
            withAttributes: pctAttrs
        )

        // 1.2 右侧药丸胶囊徽章 (Capsule Badge)
        let badgeText = props.statusBadgeText
        let badgeFont = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        let badgeTextColor: NSColor = props.isCharging
            ? .systemGreen
            : (props.isBypass ? .systemGreen : .secondaryLabelColor)

        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: badgeFont,
            .foregroundColor: badgeTextColor
        ]
        let badgeTextSize = (badgeText as NSString).size(withAttributes: badgeAttrs)

        let badgePaddingH: CGFloat = 7.0
        let badgePaddingV: CGFloat = 2.5
        let badgeWidth = badgeTextSize.width + (badgePaddingH * 2)
        let badgeHeight = badgeTextSize.height + (badgePaddingV * 2)
        let badgeX = bounds.width - sidePadding - badgeWidth
        let badgeY = topRowY + (pctSize.height - badgeHeight) / 2.0 + 1.0

        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2.0, yRadius: badgeHeight / 2.0)

        // 徽章背景色：深浅自适应微透明底色
        let badgeBgColor: NSColor = props.isCharging
            ? NSColor.systemGreen.withAlphaComponent(0.15)
            : (props.isBypass ? NSColor.systemGreen.withAlphaComponent(0.12) : NSColor.labelColor.withAlphaComponent(0.08))
        badgeBgColor.setFill()
        badgePath.fill()

        (badgeText as NSString).draw(
            at: NSPoint(x: badgeX + badgePaddingH, y: badgeY + badgePaddingV),
            withAttributes: badgeAttrs
        )

        // 2. 中间行：微型电量胶囊进度条 (Progress Rail)
        let railY: CGFloat = topRowY - 12.0
        let railHeight: CGFloat = 5.5
        let railRadius: CGFloat = railHeight / 2.0
        let railRect = NSRect(x: sidePadding, y: railY, width: contentWidth, height: railHeight)

        // 2.1 轨道底色 (Track)
        let trackPath = NSBezierPath(roundedRect: railRect, xRadius: railRadius, yRadius: railRadius)
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        trackPath.fill()

        // 2.2 填充部分 (Fill)
        let clampedPct = max(0, min(100, props.percent))
        let fillWidth = max(railHeight, contentWidth * CGFloat(clampedPct) / 100.0)
        let fillRect = NSRect(x: sidePadding, y: railY, width: fillWidth, height: railHeight)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: railRadius, yRadius: railRadius)

        let fillColor: NSColor = props.plugged
            ? .systemGreen
            : (props.percent <= 20 ? .systemRed : .systemBlue)
        fillColor.setFill()
        fillPath.fill()

        // 2.3 80% 充电保护刻度线 (CodexBar 式 Marker)
        let mark80X = sidePadding + (contentWidth * 0.8)
        let markerWidth: CGFloat = 1.5
        let markerRect = NSRect(x: mark80X - (markerWidth / 2.0), y: railY - 0.5, width: markerWidth, height: railHeight + 1.0)

        ctx.saveGState()
        // 刻度线使用白色/对比色，强化 80% 阈值提示
        NSColor.white.withAlphaComponent(0.85).setFill()
        ctx.fill(markerRect)
        ctx.restoreGState()

        // 3. 底部行：次级副标摘要文字 (Subtitle)
        let subY: CGFloat = railY - 16.0
        let subFont = NSFont.systemFont(ofSize: 11.0, weight: .regular)
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: subFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        (props.subtitleText as NSString).draw(
            at: NSPoint(x: sidePadding, y: subY),
            withAttributes: subAttrs
        )
    }
}
