import AppKit

final class SwitcherView: NSView {

    static let itemSize = NSSize(width: 96, height: 96)
    static let itemSpacing: CGFloat = 0.5
    static let padding: CGFloat = 16

    private let effectView = NSVisualEffectView()
    private var itemViews: [SwitcherItemView] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 14 + Self.padding
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 26
        addSubview(effectView)
    }

    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    func setApps(_ apps: [NSRunningApplication], selection: Int) {
        for view in itemViews { view.removeFromSuperview() }
        itemViews.removeAll()
        for (index, app) in apps.enumerated() {
            let item = SwitcherItemView(app: app, number: index + 1, selected: index == selection)
            effectView.addSubview(item)
            itemViews.append(item)
        }
        layoutItems()
    }

    func setSelection(_ index: Int) {
        for (i, item) in itemViews.enumerated() {
            item.setSelected(i == index)
        }
    }

    func contentSize(forAppCount count: Int) -> NSSize {
        let n = CGFloat(count)
        let width = n * Self.itemSize.width + max(0, n - 1) * Self.itemSpacing + Self.padding * 2
        let height = Self.itemSize.height + Self.padding * 2
        return NSSize(width: width, height: height)
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        layoutItems()
    }

    private func layoutItems() {
        guard !itemViews.isEmpty else { return }
        let count = CGFloat(itemViews.count)
        let totalWidth = count * Self.itemSize.width + (count - 1) * Self.itemSpacing
        let startX = (bounds.width - totalWidth) / 2
        let y = (bounds.height - Self.itemSize.height) / 2
        for (index, item) in itemViews.enumerated() {
            item.frame = NSRect(
                x: startX + CGFloat(index) * (Self.itemSize.width + Self.itemSpacing),
                y: y,
                width: Self.itemSize.width,
                height: Self.itemSize.height
            )
        }
    }
}
