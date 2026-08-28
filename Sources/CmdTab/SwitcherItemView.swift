import AppKit

final class SwitcherItemView: NSView {

    private let iconView = NSImageView()
    private let badgeView = NSTextField(labelWithString: "")
    private let shadowLayer = CALayer()
    init(app: NSRunningApplication, number: Int, selected: Bool) {
        super.init(frame: .zero)
        wantsLayer = true

        iconView.image = app.icon ?? NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        badgeView.stringValue = "\(number)"
        badgeView.font = .systemFont(ofSize: 11, weight: .bold)
        badgeView.textColor = .white
        badgeView.alignment = .center
        badgeView.drawsBackground = true
        badgeView.backgroundColor = .black
        badgeView.wantsLayer = true
        badgeView.layer?.masksToBounds = true
        badgeView.isEditable = false
        badgeView.isSelectable = false
        addSubview(badgeView)

        // Solid rounded plate behind the icon — reads as a shadow, no blur.
        shadowLayer.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        shadowLayer.opacity = selected ? 1 : 0
        layer?.addSublayer(shadowLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    func setSelected(_ selected: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        shadowLayer.opacity = selected ? 0.7 : 0
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        let iconSize: CGFloat = 80
        iconView.frame = NSRect(
            x: (width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        let badgeSize: CGFloat = 18
        badgeView.frame = NSRect(
            x: iconView.frame.maxX - badgeSize + 3,
            y: iconView.frame.minY - 3,
            width: badgeSize,
            height: badgeSize
        )
        badgeView.layer?.cornerRadius = badgeSize / 2

        // Solid plate extends 8pt beyond the icon on every side, same rounded shape.
        let inset: CGFloat = -8
        shadowLayer.frame = iconView.frame.insetBy(dx: inset, dy: inset)
        shadowLayer.cornerRadius = 18 - inset
    }
}
