import AppKit
import Foundation

/// Debug logging for CmdTab.
///
/// Disabled by default. Enable it from the menu bar icon → **Debug Logging**,
/// or before launching with:
///
///     defaults write com.local.CmdTab CmdTabDebugLog -bool YES
///
/// When enabled, log lines are appended to `~/tmp/cmd-tab`
/// (menu bar icon → **Open Log…** reveals the file in Finder).
enum DebugLog {

    static let enabledKey = "CmdTabDebugLog"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Toggles the flag and returns the new value.
    @discardableResult
    static func toggle() -> Bool {
        let on = !isEnabled
        isEnabled = on
        if on {
            log("=== debug logging enabled ===")
        }
        return on
    }

    /// Appends a line to the log file when logging is enabled.
    /// The message is only evaluated when logging is on.
    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let line = message()
        queue.async {
            write(line)
        }
    }

    /// Ensures the log file exists and reveals it in Finder.
    static func revealLogFile() {
        queue.sync {
            ensureLogDirectory()
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
        }
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }

    static var logFileURL: URL { logURL }

    // MARK: - Private

    private static let queue = DispatchQueue(label: "CmdTab.debuglog")
    private static let logURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("tmp/cmd-tab")

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// Cap the log at 2 MB so it can't grow without bound.
    private static let maxLogBytes: UInt64 = 2 * 1024 * 1024

    /// Ensures the parent directory of the log file exists.
    private static func ensureLogDirectory() {
        let dir = logURL.deletingLastPathComponent().path
        if !FileManager.default.fileExists(atPath: dir) {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
    }

    private static func write(_ line: String) {
        ensureLogDirectory()
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        if size > maxLogBytes {
            handle.truncateFile(atOffset: 0)
        }
        handle.seekToEndOfFile()
        let stamp = formatter.string(from: Date())
        let data = ("\(stamp) \(line)\n").data(using: .utf8) ?? Data()
        handle.write(data)
    }
}
