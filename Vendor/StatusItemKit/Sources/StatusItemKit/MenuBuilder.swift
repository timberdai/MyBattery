// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Nicholas Smith

import AppKit

/// Helpers for menu items that must escape NSMenu's standard layout (which
/// reserves trailing space for the keyboard-shortcut column on every row).
public enum MenuBuilder {
    /// Width a label needs in a menu-item view. Uses NSString.size (not
    /// NSTextField.intrinsicContentSize, which rounds down sub-pixel and clips
    /// the trailing glyph), ceils, and adds a small safety buffer.
    public static func labelWidth(_ text: String, font: NSFont, buffer: CGFloat = 4) -> CGFloat {
        let measured = (text as NSString).size(withAttributes: [.font: font])
        return ceil(measured.width) + buffer
    }

    /// An NSView (for NSMenuItem.view) wrapping a left-padded label. Uses
    /// explicit frames: NSMenu reads the frame at insertion time, before any
    /// auto-layout pass, so a constraint-only view would be zero-sized.
    public static func textView(
        _ text: String,
        font: NSFont,
        color: NSColor = .secondaryLabelColor,
        leftPad: CGFloat = 20,
        rightPad: CGFloat = 6,
        vPad: CGFloat = 3
    ) -> NSView {
        let w = labelWidth(text, font: font)
        let h = ceil((text as NSString).size(withAttributes: [.font: font]).height)

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.frame = NSRect(x: leftPad, y: vPad, width: w, height: h)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w + leftPad + rightPad, height: h + vPad * 2))
        container.addSubview(label)
        return container
    }
}
