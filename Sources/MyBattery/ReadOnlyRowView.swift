import AppKit

final class ReadOnlyRowView: NSView {
    private let key: String
    private let val: String
    private let valColor: NSColor
    private let isBold: Bool

    init(key: String, val: String, valColor: NSColor = .labelColor, isBold: Bool = false) {
        self.key = key
        self.val = val
        self.valColor = valColor
        self.isBold = isBold
        super.init(frame: NSRect(x: 0, y: 0, width: 176, height: 19))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 176, height: 19)
    }

    private static func fonts(_ isBold: Bool) -> (NSFont, NSFont) {
        (NSFont.systemFont(ofSize: 12, weight: .regular),
         NSFont.monospacedDigitSystemFont(ofSize: 12, weight: isBold ? .semibold : .regular))
    }

    static func requiredWidth(key: String, val: String, isBold: Bool = false) -> CGFloat {
        let (keyFont, valFont) = fonts(isBold)
        return 22 + ((key + ": ") as NSString).size(withAttributes: [.font: keyFont]).width
                  + (val as NSString).size(withAttributes: [.font: valFont]).width
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let (keyFont, valFont) = Self.fonts(isBold)

        let keyAttrs: [NSAttributedString.Key: Any] = [
            .font: keyFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: valFont,
            .foregroundColor: valColor
        ]

        let xPad: CGFloat = 10
        let y: CGFloat = 2

        let keyStr = key + ": "
        (keyStr as NSString).draw(at: NSPoint(x: xPad, y: y), withAttributes: keyAttrs)
        let keyW = (keyStr as NSString).size(withAttributes: keyAttrs).width
        (val as NSString).draw(at: NSPoint(x: xPad + keyW + 2, y: y), withAttributes: valAttrs)
    }
}
