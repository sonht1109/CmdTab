import AppKit

/// A small circular pill that draws a number perfectly centered inside it.
///
/// Drawn manually (instead of using an NSTextField) because NSTextField cells
/// lay text out on the font's line box, which makes digits sit noticeably high
/// inside a small circle. Measuring the string and drawing it at the exact
/// center of the bounds keeps the number optically centered.
final class NumberBadgeView: NSView {

    private let number: Int

    init(number: Int) {
        self.number = number
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        let radius = min(bounds.width, bounds.height) / 2

        // Pill background (same solid circle as before).
        NSColor.black.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        // Number, centered both ways using the string's measured size.
        let text = "\(number)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2
            ),
            withAttributes: attributes
        )
    }
}
