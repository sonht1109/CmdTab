import AppKit
import ApplicationServices
import CoreGraphics

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var statusItem: NSStatusItem?
    private var appearanceObserver: NSKeyValueObservation?
    private var debugLogMenuItem: NSMenuItem?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var mouseMonitor: Any?
    private var retryTimer: Timer?
    private let switcher = SwitcherController()

    private var cmdDown = false
    private var overlayVisible = false

    private let keyTab = 48
    private let keyEscape = 53
    // Number-row keycodes are not contiguous.
    private let digitKeycodes: [Int: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLog.log("didFinishLaunching ax=\(AXIsProcessTrusted()) listen=\(CGPreflightListenEventAccess())")
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        observeAppActivations()
        observeBecameActive()
        setupEventTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopTapRetry()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes)
        }
        stopMouseMonitor()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            // The menu bar inverts per appearance: dark-gray icon on the light
            // bar, white icon on the dark bar. Swap automatically when the
            // appearance changes (effectiveAppearance is KVO-observable).
            appearanceObserver = button.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] button, _ in
                self?.updateMenuBarIcon(for: button)
            }
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Permissions…", action: #selector(openPermissions), keyEquivalent: ""))
        menu.addItem(.separator())
        let debugItem = NSMenuItem(title: "Debug Logging", action: #selector(toggleDebugLogging), keyEquivalent: "")
        debugItem.state = DebugLog.isEnabled ? .on : .off
        menu.addItem(debugItem)
        debugLogMenuItem = debugItem
        menu.addItem(NSMenuItem(title: "Open Log…", action: #selector(openLogFile), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit CmdTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    /// Picks the menu bar icon matching the current appearance: the dark-gray
    /// icon for the light menu bar, the white icon for the dark one.
    private func updateMenuBarIcon(for button: NSStatusBarButton) {
        let isDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let name = isDark ? "MenuBarIcon-White" : "MenuBarIcon-Dark"
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            DebugLog.log("menu bar icon \(name) not found in bundle")
            return
        }
        let height: CGFloat = 18
        image.size = NSSize(width: height * image.size.width / image.size.height, height: height)
        button.image = image
    }

    @objc private func toggleDebugLogging() {
        DebugLog.toggle()
        debugLogMenuItem?.state = DebugLog.isEnabled ? .on : .off
    }

    @objc private func openLogFile() {
        DebugLog.revealLogFile()
    }

    @objc private func openPermissions() {
        requestPermissionsIfNeeded()
    }

    private enum MissingPermission {
        case accessibility
        case inputMonitoring

        var name: String {
            switch self {
            case .accessibility: return "Accessibility"
            case .inputMonitoring: return "Input Monitoring"
            }
        }

        var settingsURL: String {
            switch self {
            case .accessibility: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .inputMonitoring: return "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
            }
        }
    }

    private func missingPermissions() -> [MissingPermission] {
        var missing: [MissingPermission] = []
        if !AXIsProcessTrusted() { missing.append(.accessibility) }
        if !CGPreflightListenEventAccess() { missing.append(.inputMonitoring) }
        return missing
    }

    private func hasPermission() -> Bool {
        missingPermissions().isEmpty
    }

    private func openPermissionsSettings(_ missing: [MissingPermission]) {
        for (index, permission) in missing.enumerated() {
            guard let url = URL(string: permission.settingsURL) else { continue }
            if index == 0 {
                NSWorkspace.shared.open(url)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    /// Asks for whatever is missing using the system's native permission
    /// dialogs (these always appear, even for background menu-bar apps),
    /// then shows a fallback alert with a shortcut into System Settings.
    private func requestPermissionsIfNeeded() {
        let missing = missingPermissions()
        guard !missing.isEmpty else {
            // Nothing missing — make sure the tap is actually running.
            if tap == nil { startEventTap() }
            return
        }
        for permission in missing {
            switch permission {
            case .accessibility:
                let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(options)
            case .inputMonitoring:
                CGRequestListenEventAccess()
            }
        }
        showPermissionAlert(missing)
    }

    private func showPermissionAlert(_ missing: [MissingPermission]) {
        let names = missing.map(\.name).joined(separator: " and ")
        let alert = NSAlert()
        alert.messageText = "CmdTab needs permission"
        alert.informativeText = "To replace Cmd+Tab, CmdTab must read keyboard events and control other apps. Enable CmdTab in System Settings → Privacy & Security → \(names). You don't need to quit and reopen — CmdTab will start working as soon as you grant access."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openPermissionsSettings(missing)
        }
    }

    // MARK: - Event tap

    private func setupEventTap() {
        DebugLog.log("setupEventTap hasPermission=\(hasPermission())")
        if !hasPermission() {
            DebugLog.log("permission missing: \(missingPermissions().map(\.name))")
            scheduleTapRetry()
            requestPermissionsIfNeeded()
            return
        }
        startEventTap()
    }

    /// Keeps checking in the background and starts the tap the moment the
    /// user grants the missing permissions — no restart required.
    private func scheduleTapRetry() {
        guard retryTimer == nil else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, self.tap == nil, self.hasPermission() else { return }
            self.startEventTap()
        }
        RunLoop.main.add(timer, forMode: .common)
        retryTimer = timer
    }

    private func stopTapRetry() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func startEventTap() {
        let mask = CGEventMask(
            (1 << CGEventType.flagsChanged.rawValue)
                | (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue)
        )
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let app = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                return app.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            DebugLog.log("tapCreate FAILED (access missing?)")
            // tapCreate can fail when access is missing; retry until granted.
            scheduleTapRetry()
            requestPermissionsIfNeeded()
            return
        }
        stopTapRetry()
        tap = newTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        tapSource = source
        CGEvent.tapEnable(tap: newTap, enable: true)
        DebugLog.log("event tap created and enabled")
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DebugLog.log("tap disabled by \(type), re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let typeName: String
        switch type {
        case .flagsChanged: typeName = "flagsChanged"
        case .keyDown: typeName = "keyDown"
        case .keyUp: typeName = "keyUp"
        default: typeName = "type\(type.rawValue)"
        }
        DebugLog.log("tap \(typeName) keycode=\(Int(event.getIntegerValueField(.keyboardEventKeycode))) flags=\(event.flags.rawValue)")

        switch type {
        case .flagsChanged:
            let cmd = event.flags.contains(.maskCommand)
            let wasDown = cmdDown
            cmdDown = cmd
            if wasDown && !cmd && overlayVisible {
                dismissOverlay(switching: true)
            }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            let flags = event.flags
            let cmd = flags.contains(.maskCommand)
            cmdDown = cmd
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))

            if cmd && code == keyTab && !overlayVisible {
                presentOverlay(backward: flags.contains(.maskShift))
                return nil
            }

            if overlayVisible {
                if cmd && code == keyTab {
                    let forward = !flags.contains(.maskShift)
                    switcher.cycle(forward: forward)
                    return nil
                }
                if cmd, let number = digitKeycodes[code] {
                    switcher.select(number: number)
                    return nil
                }
                if code == keyEscape {
                    cancelOverlay()
                    return nil
                }
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Overlay

    private func presentOverlay(backward: Bool = false) {
        DebugLog.log("presentOverlay backward=\(backward)")
        overlayVisible = true
        startMouseMonitor()
        switcher.present(backward: backward)
    }

    private func dismissOverlay(switching: Bool) {
        DebugLog.log("dismissOverlay switching=\(switching)")
        overlayVisible = false
        stopMouseMonitor()
        switcher.finishSelection(activate: switching)
    }

    private func cancelOverlay() {
        DebugLog.log("cancelOverlay")
        overlayVisible = false
        stopMouseMonitor()
        switcher.hide()
    }

    private func startMouseMonitor() {
        stopMouseMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.handleClickOutside()
        }
    }

    private func stopMouseMonitor() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    private func handleClickOutside() {
        guard overlayVisible, let frame = switcher.panelFrame else { return }
        let location = NSEvent.mouseLocation
        if !frame.contains(location) {
            cancelOverlay()
        }
    }

    // MARK: - Observers

    private func observeAppActivations() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.switcher.recordActivation(app)
        }
    }

    private func observeBecameActive() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if tap == nil {
                if hasPermission() {
                    startEventTap()
                } else {
                    scheduleTapRetry()
                }
            }
        }
    }
}
