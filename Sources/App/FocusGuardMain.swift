import AppKit
import Combine
import SwiftUI
import UserNotifications

@main
struct FocusGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, UNUserNotificationCenterDelegate {
    private let model = AppModel.shared
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var settingsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.refreshStatus()

        configureStatusItem()
        configurePopover()

        model.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItem()
                }
            }
            .store(in: &cancellables)

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .focusGuardOpenSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openSettings()
        }

        updateStatusItem()

        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openSettings()
            }
        } else if CommandLine.arguments.contains("--show-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.togglePopover()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let settingsWindow, settingsWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
        } else {
            togglePopover()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    // MARK: - Status item

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.imagePosition = .noImage
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "FocusGuard · 专注卫士"
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: model.menuBarColor
        ]
        button.attributedTitle = NSAttributedString(string: model.menuBarText, attributes: attributes)
        button.toolTip = model.menuBarTooltip
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isRightClick {
            popover.performClose(nil)
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    // MARK: - Popover

    private func configurePopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 336, height: 580)

        let root = PopoverView().environmentObject(model)
        popover.contentViewController = NSHostingController(rootView: root)
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        requestNotificationPermissionIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: - Context menu

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = buildContextMenu()
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let toggle = NSMenuItem(title: model.primaryActionTitle, action: #selector(menuToggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let skip = NSMenuItem(title: "跳过当前阶段", action: #selector(menuSkip), keyEquivalent: "")
        skip.target = self
        skip.isEnabled = model.phase != .idle
        menu.addItem(skip)

        let stop = NSMenuItem(title: "终止整个循环", action: #selector(menuStop), keyEquivalent: "")
        stop.target = self
        stop.isEnabled = model.phase != .idle
        menu.addItem(stop)

        menu.addItem(.separator())

        let today = NSMenuItem(
            title: "今日专注 \(Format.hoursMinutes(model.todayFocusSeconds)) · \(model.todayRounds) 轮",
            action: nil,
            keyEquivalent: ""
        )
        today.isEnabled = false
        menu.addItem(today)

        if model.todayDistractions > 0 {
            let distractions = NSMenuItem(
                title: "今日分心 \(model.todayDistractions) 次",
                action: nil,
                keyEquivalent: ""
            )
            distractions.isEnabled = false
            menu.addItem(distractions)
        }

        menu.addItem(.separator())

        let open = NSMenuItem(title: "打开控制面板", action: #selector(menuOpen), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let settings = NSMenuItem(title: "设置…", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 FocusGuard", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func menuToggle() {
        model.toggleTimer()
    }

    @objc private func menuSkip() {
        model.skipPhase()
    }

    @objc private func menuStop() {
        model.stopCycle()
    }

    @objc private func menuOpen() {
        togglePopover()
    }

    @objc private func menuSettings() {
        openSettings()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    // MARK: - Settings window

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            NotificationService.shared.requestAuthorization()
        }
    }

    private static var initialSettingsPage: SettingsPage {
        guard let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--settings-page=") }),
              let raw = argument.split(separator: "=", maxSplits: 1).last,
              let page = SettingsPage(rawValue: String(raw)) else {
            return .timer
        }
        return page
    }

    private func openSettings() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        requestNotificationPermissionIfNeeded()

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "专注卫士设置"
            window.titlebarAppearsTransparent = false
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: SettingsView(initialPage: Self.initialSettingsPage).environmentObject(model)
            )
            window.setContentSize(NSSize(width: 900, height: 760))
            window.minSize = NSSize(width: 780, height: 580)
            window.setFrameAutosaveName("FocusGuardSettings")
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    // MARK: - Notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
