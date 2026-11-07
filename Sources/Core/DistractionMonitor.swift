import AppKit

/// 监听前台 App 切换：专注期间切到被监控的娱乐 App 并停留超过宽限时间，就记录并提醒。
final class DistractionMonitor {
    var isEnabled = false
    var monitoredApps: [MonitoredApp] = []
    var graceSeconds: TimeInterval = 20
    var isFocusActive: (() -> Bool)?
    var onDistraction: ((MonitoredApp, TimeInterval) -> Void)?

    private var observer: NSObjectProtocol?
    private var pending: DispatchWorkItem?
    private var pendingApp: MonitoredApp?

    func start() {
        stop()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleActivation(notification)
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        cancelPending()
    }

    func focusStateChanged() {
        if isFocusActive?() != true {
            cancelPending()
        }
    }

    private func handleActivation(_ notification: Notification) {
        guard isEnabled, isFocusActive?() == true else {
            cancelPending()
            return
        }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier,
              let monitored = monitoredApps.first(where: { $0.bundleID == bundleID }) else {
            cancelPending()
            return
        }

        if pending != nil, pendingApp?.bundleID == bundleID {
            return
        }

        cancelPending()
        pendingApp = monitored

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pending = nil
            guard self.isEnabled, self.isFocusActive?() == true else { return }
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == monitored.bundleID else { return }
            self.onDistraction?(monitored, self.graceSeconds)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(1, graceSeconds), execute: work)
    }

    private func cancelPending() {
        pending?.cancel()
        pending = nil
        pendingApp = nil
    }
}
