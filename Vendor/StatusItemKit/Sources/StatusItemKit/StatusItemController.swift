// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Owns an NSStatusItem, a polling timer, and lazy menu rebuilding. The host
/// supplies `onPoll` (gather state + call setTitle/setIcon) and `onBuildMenu`
/// (populate the menu when it opens). Rendering is funnelled through setTitle/
/// setIcon so the text and image paths stay mutually exclusive.
public final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let pollInterval: TimeInterval
    private let onPoll: () -> Void
    private let onBuildMenu: (NSMenu) -> Void
    private let onPrimaryClick: (() -> Void)?
    private let menu = NSMenu()
    private var timer: Timer?

    public var button: NSStatusBarButton? { statusItem.button }

    /// - Parameter autosaveName: names the slot macOS remembers the item's
    ///   position under (`NSStatusItem Preferred Position <name>` in the app's
    ///   defaults). Supply one when the position matters and you want it stable
    ///   and inspectable; leave nil for the system default, `Item-0`.
    /// - Parameter onPrimaryClick: when supplied, a left click runs this instead
    ///   of opening the menu, and the menu moves to right-click (and
    ///   control-click). Leave nil for the usual behaviour, where any click opens
    ///   the menu.
    public init(
        pollInterval: TimeInterval,
        onPoll: @escaping () -> Void,
        onBuildMenu: @escaping (NSMenu) -> Void,
        autosaveName: String? = nil,
        onPrimaryClick: (() -> Void)? = nil
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let autosaveName { statusItem.autosaveName = autosaveName }
        self.pollInterval = pollInterval
        self.onPoll = onPoll
        self.onBuildMenu = onBuildMenu
        self.onPrimaryClick = onPrimaryClick
        super.init()
        statusItem.button?.attributedTitle = NSAttributedString(string: "…")
        menu.delegate = self

        if onPrimaryClick == nil {
            statusItem.menu = menu
        } else {
            // Leaving `statusItem.menu` unset is what frees the left click: with
            // a menu attached, AppKit swallows the click to open it and the
            // button's action never runs.
            statusItem.button?.target = self
            statusItem.button?.action = #selector(handleClick)
            // Act on mouse *down*, like a native status menu: the menu that the
            // handler pops then owns the rest of the press, so holding the
            // button, sliding onto an item and releasing selects it — and a
            // menu opened on mouse-up cannot be dismissed by its own release.
            statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }
    }

    // MARK: Click handling

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseDown || event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            showMenu()
        } else {
            onPrimaryClick?()
        }
    }

    /// Attach the menu just long enough to pop it, then detach so the next left
    /// click still reaches the button's action.
    private func showMenu() {
        popUp(menu)
    }

    /// Drop an arbitrary menu under the item, anchored and highlighted the way a
    /// status menu should be. Useful when a left click should present something
    /// other than the item's own menu.
    public func popUp(_ menu: NSMenu, onClose: (() -> Void)? = nil) {
        // Run the menu directly under the button. NSMenu.popUp tracks the
        // press that is already in progress (the action fires on mouse down),
        // so hold-slide-release selects an item, and nothing else can pull
        // the menu out from under itself. The earlier performClick route
        // fought the button's own tracking and flashed shut.
        guard let button = statusItem.button else { return }
        button.highlight(true)
        let origin = NSPoint(x: 0, y: button.bounds.maxY + 5)
        menu.popUp(positioning: nil, at: origin, in: button)
        button.highlight(false)
        onClose?()
    }

    public func start() {
        onPoll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.onPoll()
        }
    }

    // MARK: Render funnel

    /// Text render path: clears any image, monospaced-digit font, red on warn.
    public func setTitle(_ text: String, warn: Bool) {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.contentTintColor = nil
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: warn ? NSColor.systemRed : NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            ]
        )
    }

    /// Icon render path: clears title + tint (icons are full-color non-template).
    public func setIcon(_ image: NSImage) {
        guard let button = statusItem.button else { return }
        // Touch only what changes: resetting the title or image position on a
        // status button forces the bar to re-lay out, which cancels a menu
        // that is tracking on the same item.
        if button.attributedTitle.length != 0 { button.attributedTitle = NSAttributedString(string: "") }
        if button.imagePosition != .imageOnly { button.imagePosition = .imageOnly }
        if button.contentTintColor != nil { button.contentTintColor = nil }
        button.image = image
    }

    /// Give up this item's width, or take it back. Used by `YieldClient` so a
    /// menu-bar manager can borrow the slot during a peek without moving
    /// anything.
    ///
    /// Deliberately *not* `isVisible = false`. Hiding an item makes macOS discard
    /// its remembered position outright — measured: four apps lost their
    /// `Preferred Position` keys across a single peek and came back at x≈-1200,
    /// inside the very block that was supposed to be hidden. Writing the saved
    /// value back before un-hiding does not help; it is cleared again. Shrinking
    /// to zero width frees essentially the same space while the item stays
    /// present, so its placement survives untouched.
    public func setVisible(_ visible: Bool) {
        statusItem.length = visible ? NSStatusItem.variableLength : 0
    }

    /// Take the item off the bar because the app has nothing to show — no
    /// device to control, no backlight to set — and put it back when it does.
    /// Separate from `setVisible`, so a manager's yield ending cannot bring
    /// back an item the app has withdrawn.
    ///
    /// This one *is* `isVisible`: on macOS 27 a zero-width item still keeps a
    /// slot, and the bar shows a ~16pt gap where it was (measured 2026-09-28).
    /// The cost is the one `setVisible` avoids — the item may come back at the
    /// left end of the status items rather than where it was.
    public var isSuppressed: Bool {
        get { !statusItem.isVisible }
        set { if statusItem.isVisible == newValue { statusItem.isVisible = !newValue } }
    }

    /// The item's width. A status item grows leftward — its right edge stays put
    /// — which is what lets a wide item push its left-hand neighbours off the
    /// display without disturbing anything to its right.
    public var length: CGFloat {
        get { statusItem.length }
        set { if statusItem.length != newValue { statusItem.length = newValue } }
    }

    // MARK: Lazy menu rebuild

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        onBuildMenu(menu)
    }

    /// Fired around the item's own attached menu, so an app can react to it
    /// opening and closing (Barn opens its doors while its menu is up).
    public var onMenuWillOpen: (() -> Void)?
    public var onMenuDidClose: (() -> Void)?

    public func menuWillOpen(_ menu: NSMenu) { onMenuWillOpen?() }
    public func menuDidClose(_ menu: NSMenu) { onMenuDidClose?() }

    /// True while the click that is opening the menu is a right click or a
    /// control-click. Read it from `onBuildMenu` to build a different menu
    /// for the secondary button while keeping AppKit's native tracking for
    /// both — a quick click leaves the menu open, a held click selects on
    /// release — which a hand-popped menu cannot fully reproduce.
    public static var isSecondaryClick: Bool {
        guard let event = NSApp.currentEvent else { return false }
        return event.type == .rightMouseDown || event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)
    }
}
