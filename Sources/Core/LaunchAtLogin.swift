import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "已开启"
        case .notRegistered: return "未开启"
        case .requiresApproval: return "等待系统批准"
        case .notFound: return "未找到登录项"
        @unknown default: return "未知状态"
        }
    }

    /// 返回 nil 表示成功，否则返回错误描述。
    @discardableResult
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
