import AppKit
import UserNotifications

/// 统一负责“提醒”的投递：
/// - 系统通知已授权时走 UNUserNotificationCenter；
/// - 未授权、被关闭或投递失败时，退化为屏幕右上角的应用内提醒，
///   保证即使 App 是 ad-hoc 签名、系统拒绝通知权限，阶段切换也不会没有提醒。
final class NotificationService {
    static let shared = NotificationService()

    private(set) var isAuthorized = false
    private var requested = false

    func refreshStatus(completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let statusOK = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                let alertsOn = settings.alertSetting == .enabled
                    || settings.notificationCenterSetting == .enabled
                self.isAuthorized = statusOK && alertsOn
                completion?()
            }
        }
    }

    func requestAuthorization(completion: (() -> Void)? = nil) {
        guard !requested else {
            refreshStatus(completion: completion)
            return
        }
        requested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("FocusGuard 通知授权失败：\(error.localizedDescription)，将使用应用内提醒。")
            } else if !granted {
                NSLog("FocusGuard 通知未授权，将使用应用内提醒。")
            }
            DispatchQueue.main.async {
                self.refreshStatus(completion: completion)
            }
        }
    }

    /// 发送提醒；系统通知不可用时自动回退到应用内横幅。
    func deliver(title: String, body: String, playSound: Bool = false, accent: NSColor = .systemOrange) {
        if isAuthorized {
            send(title: title, body: body, playSound: playSound, accent: accent)
        } else {
            ReminderPresenter.shared.show(title: title, body: body, accent: accent)
        }
    }

    func send(title: String, body: String, playSound: Bool = false, accent: NSColor = .systemOrange) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if playSound {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            guard let error else { return }
            NSLog("FocusGuard 通知发送失败：\(error.localizedDescription)，改用应用内提醒。")
            DispatchQueue.main.async {
                self.isAuthorized = false
                ReminderPresenter.shared.show(title: title, body: body, accent: accent)
            }
        }
    }
}
