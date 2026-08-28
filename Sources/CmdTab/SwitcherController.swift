import AppKit
import CoreGraphics

final class SwitcherController {

    private var history: [NSRunningApplication] = []
    private var apps: [NSRunningApplication] = []
    private var selectedIndex = 0
    private var panel: NSPanel?
    private let switcherView = SwitcherView()
    private let maxItems = 9

    var panelFrame: NSRect? {
        panel?.frame
    }

    func recordActivation(_ app: NSRunningApplication) {
        history.removeAll { $0.processIdentifier == app.processIdentifier }
        history.append(app)
        if history.count > 30 {
            history.removeFirst(history.count - 30)
        }
        DebugLog.log("recordActivation \(app.localizedName ?? "?") -> history=\(history.compactMap { $0.localizedName }.joined(separator: ", "))")
    }

    func present() {
        buildAppList()
        DebugLog.log("present order: \(apps.compactMap { $0.localizedName }.joined(separator: " | "))")
        guard !apps.isEmpty else { return }
        selectedIndex = 0
        let panel = ensurePanel()
        switcherView.setApps(apps, selection: 0)
        panel.setContentSize(switcherView.contentSize(forAppCount: apps.count))
        positionPanel(panel)
        panel.orderFrontRegardless()
    }

    func cycle(forward: Bool) {
        guard !apps.isEmpty else { return }
        let count = apps.count
        if forward {
            selectedIndex = (selectedIndex + 1) % count
        } else {
            selectedIndex = (selectedIndex - 1 + count) % count
        }
        DebugLog.log("cycle \(forward ? "forward" : "backward") -> selection #\(selectedIndex + 1)")
        switcherView.setSelection(selectedIndex)
    }

    func select(number: Int) {
        let index = number - 1
        guard index >= 0 && index < apps.count else { return }
        selectedIndex = index
        DebugLog.log("select #\(number)")
        switcherView.setSelection(index)
        activate(at: index)
        panel?.orderFrontRegardless()
    }

    func finishSelection(activate: Bool) {
        if activate {
            self.activate(at: selectedIndex)
        }
        hide()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Private

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .utilityWindow
        panel.contentView = switcherView
        self.panel = panel
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    private func buildAppList() {
        let running = NSWorkspace.shared.runningApplications
        let regular = running.filter { $0.activationPolicy == .regular }
        var ordered: [NSRunningApplication] = []
        var seen = Set<pid_t>()
        for app in history.reversed() {
            if seen.contains(app.processIdentifier) { continue }
            if regular.contains(where: { $0.processIdentifier == app.processIdentifier }) {
                ordered.append(app)
                seen.insert(app.processIdentifier)
            }
        }
        for app in regular {
            if seen.insert(app.processIdentifier).inserted {
                ordered.append(app)
            }
        }

        let pids = pidsWithWindows()
        if !pids.isEmpty {
            ordered = ordered.filter { pids.contains($0.processIdentifier) }
        }
        if ordered.isEmpty {
            ordered = regular
        }

        apps = Array(ordered.prefix(maxItems))
    }

    private func pidsWithWindows() -> Set<pid_t> {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var result = Set<pid_t>()
        for window in info {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            if let pid = window[kCGWindowOwnerPID as String] as? pid_t {
                result.insert(pid)
            }
        }
        return result
    }

    private func activate(at index: Int) {
        guard apps.indices.contains(index) else { return }
        let target = apps[index]
        DebugLog.log("activating #\(index + 1): \(target.localizedName ?? "?")")
        _ = target.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        // Update MRU immediately so the next Cmd+Tab shows the switched-to app
        // as #1 and the app we left as #2 (native-like toggle).
        recordActivation(target)
    }
}
