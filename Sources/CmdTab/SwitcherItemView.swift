import AppKit

final class SwitcherItemView: NSView {

    private let iconView = NSImageView()
    private let badgeView = NSTextField(labelWithString: "")
    private let ringLayer = CALayer()

    init(app: NSRunningApplication, number: Int, selected: Bool) {
        super.init(frame: .zero)
        wantsLayer = true

        iconView.image = app.icon ?? NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        badgeView.stringValue = "\(number)"
        badgeView.font = .systemFont(ofSize: 10, weight: .bold)
        badgeView.textColor = .white
        badgeView.alignment = .center
        badgeView.drawsBackground = true
        badgeView.backgroundColor = .black
        badgeView.wantsLayer = true
        badgeView.layer?.cornerRadius = 8
        badgeView.isEditable = false
        badgeView.isSelectable = false
        addSubview(badgeView)

        ringLayer.borderWidth = 2
        ringLayer.borderColor = NSColor.controlAccentColor.cgColor
        ringLayer.cornerRadius = 10
        ringLayer.isHidden = !selected
        layer?.addSublayer(ringLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    func setSelected(_ selected: Bool) {
        ringLayer.isHidden = !selected
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        let iconSize: CGFloat = 40
        iconView.frame = NSRect(
            x: (width - iconSize) / 2,
            y: 22,
            width: iconSize,
            height: iconSize
        )
        let badgeSize = NSSize(width: 22, height: 16)
        badgeView.frame = NSRect(
            x: iconView.frame.maxX - badgeSize.width + 3,
            y: iconView.frame.minY - 3,
            width: badgeSize.width,
            height: badgeSize.height
        )
        ringLayer.frame = iconView.frame.insetBy(dx: -5, dy: -5)
    }
}
