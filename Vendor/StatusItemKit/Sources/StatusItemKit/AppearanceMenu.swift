// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Builds the shared "Icon" submenu: shape, colour presets, and the system
/// colour picker.
///
/// Retained by the app (it is the menu items' target, which NSMenuItem does not
/// retain) and handed a callback to redraw when a choice changes.
public final class AppearanceMenu: NSObject, NSWindowDelegate {
    private let appearance: MeterAppearance
    private let styles: [MeterStyle]
    private let characterTitle: String?
    private let colorItems: ((NSMenu) -> Void)?
    private let offersColour: Bool
    private let onChange: () -> Void

    /// - Parameter styles: which shapes to offer. Defaults to the proportional
    ///   ones; pass `MeterStyle.allCases` for an app whose icon shows state
    ///   rather than a fraction.
    /// - Parameter characterTitle: what to call `.character` in the menu when
    ///   it is offered — "Owl", "Octopus" — since "Character" says nothing.
    /// - Parameter colorItems: builds the colour block in place of the shared
    ///   presets and the colour panel, for an app whose colour is not one
    ///   number — a pair, a palette. It is handed the submenu after the shapes
    ///   and their separator, and owns persistence and redraw for its items.
    /// - Parameter offersColour: `false` for an app whose colours are all
    ///   decided by its data — the submenu is then shapes only, with no
    ///   separator, no presets and no panel. Ignored when `colorItems` is set.
    public init(appearance: MeterAppearance,
                styles: [MeterStyle] = MeterStyle.proportional,
                characterTitle: String? = nil,
                colorItems: ((NSMenu) -> Void)? = nil,
                offersColour: Bool = true,
                onChange: @escaping () -> Void) {
        self.appearance = appearance
        self.styles = styles
        self.characterTitle = characterTitle
        self.colorItems = colorItems
        self.offersColour = offersColour
        self.onChange = onChange
        super.init()
    }

    /// An "Icon" item with the whole picker underneath it.
    public func menuItem(title: String = "Icon") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for style in styles {
            let title = style == .character ? (characterTitle ?? style.title) : style.title
            let choice = NSMenuItem(title: title, action: #selector(pickStyle(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = style.rawValue
            choice.state = style == appearance.style ? .on : .off
            submenu.addItem(choice)
        }

        if let colorItems {
            submenu.addItem(.separator())
            colorItems(submenu)
            item.submenu = submenu
            return item
        }
        guard offersColour else {
            item.submenu = submenu
            return item
        }
        submenu.addItem(.separator())

        let currentHex = appearance.colorHex.uppercased()
        var matchedPreset = false
        for preset in MeterColor.presets {
            let choice = NSMenuItem(title: preset.name, action: #selector(pickColor(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = preset.hex
            choice.image = MeterColor.swatch(preset.color)
            let isCurrent = preset.hex.uppercased() == currentHex
            if isCurrent { matchedPreset = true }
            choice.state = isCurrent ? .on : .off
            submenu.addItem(choice)
        }

        let custom = NSMenuItem(title: "Custom Colour…", action: #selector(pickCustomColor), keyEquivalent: "")
        custom.target = self
        custom.image = MeterColor.swatch(appearance.color)
        // Ticked when the stored colour is not one of the presets, so a custom
        // choice does not look like nothing is selected.
        custom.state = matchedPreset ? .off : .on
        submenu.addItem(custom)

        item.submenu = submenu
        return item
    }

    // MARK: - Actions

    @objc private func pickStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        appearance.style = MeterStyle.from(raw, default: appearance.style)
        onChange()
    }

    @objc private func pickColor(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String,
              let color = MeterColor.color(fromHex: hex) else { return }
        appearance.color = color
        onChange()
    }

    @objc private func pickCustomColor() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = appearance.color
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        panel.delegate = self
        // An .accessory app has no windows and cannot bring a panel forward
        // without activating first — without this the picker opens behind
        // whatever the user was looking at, or not visibly at all.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        appearance.color = sender.color
        onChange()
    }

    /// Stop driving the appearance once the panel is dismissed. Leaving the
    /// target attached means the next app to open the shared panel would write
    /// its colours into this app's preference.
    public func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSColorPanel) === NSColorPanel.shared else { return }
        NSColorPanel.shared.setTarget(nil)
        NSColorPanel.shared.setAction(nil)
        NSColorPanel.shared.delegate = nil
    }
}
