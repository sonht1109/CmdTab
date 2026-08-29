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

    func present(backward: Bool = false) {
        buildAppList()
        DebugLog.log("present order: \(apps.compactMap { $0.localizedName }.joined(separator: " | "))")
        guard !apps.isEmpty else { return }
        // Native behavior: the first Cmd+Tab press focuses the previous app
        // (#2), not the current one (#1). With Shift held, focus the last app.
        if backward {
            selectedIndex = apps.count - 1
        } else {
            selectedIndex = apps.count > 1 ? 1 : 0
        }
        let panel = ensurePanel()
        switcherView.setApps(apps, selection: selectedIndex)
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
        let screen = panelScreen()
        let size = panel.frame.size
        let origin = NSPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    /// Screen for the panel: the current app's screen (#1 in the list) first,
    /// then the mouse screen, then the main screen. The panel opens on that
    /// screen and stays there for the whole gesture — it does not follow the
    /// selection while cycling.
    private func panelScreen() -> NSScreen {
        if let current = apps.first,
           let screen = screen(for: current) {
            DebugLog.log("panel screen: \(screen.localizedName) (current app)")
            return screen
        }
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            DebugLog.log("panel screen: \(screen.localizedName) (mouse)")
            return screen
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        DebugLog.log("panel screen: \(screen.localizedName) (main)")
        return screen
    }

    /// On-screen window frames (in CG display coordinates) owned by `pid`.
    private func onScreenWindowFrames(for pid: pid_t) -> [CGRect] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var frames: [CGRect] = []
        for window in info {
            guard let owner = window[kCGWindowOwnerPID as String] as? pid_t, owner == pid else { continue }
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            frames.append(frame)
        }
        return frames
    }

    /// The screen containing the app's largest on-screen window.
    private func screen(for app: NSRunningApplication) -> NSScreen? {
        let frames = onScreenWindowFrames(for: app.processIdentifier)
        guard let largest = frames.max(by: { ($0.width * $0.height) < ($1.width * $1.height) }) else {
            return nil
        }
        let center = CGPoint(x: largest.midX, y: largest.midY)
        // CGWindow bounds live in "global display space": origin at the top-left
        // of the primary display, y growing downward. NSScreen frames use AppKit
        // coordinates (origin bottom-left of primary, y growing upward). Rather
        // than flipping the window point by hand (which breaks when a display is
        // stacked above the primary — the anchor is the PRIMARY's height, not the
        // tallest frame), convert each screen's frame into CG display space and
        // test the window center there directly.
        let primaryHeight = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height
            ?? (NSScreen.screens.map { $0.frame.maxY }.max() ?? 0)
        return NSScreen.screens.first { screen in
            let cgFrame = CGRect(
                x: screen.frame.origin.x,
                y: primaryHeight - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return cgFrame.insetBy(dx: -2, dy: -2).contains(center)
        }
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
