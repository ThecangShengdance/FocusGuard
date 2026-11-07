import Foundation
import SwiftUI

// MARK: - Phase

enum Phase: String, Codable, CaseIterable, Identifiable {
    case idle
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle: return "准备开始"
        case .focus: return "专注中"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    var menuTitle: String {
        switch self {
        case .idle: return "空闲"
        case .focus: return "专注"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    var menuLabel: String {
        switch self {
        case .idle, .focus: return "专注"
        case .shortBreak: return "休息"
        case .longBreak: return "长休"
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "🎯"
        case .focus: return "🎯"
        case .shortBreak: return "☕️"
        case .longBreak: return "🌿"
        }
    }

    var isFocus: Bool { self == .focus }
    var isBreak: Bool { self == .shortBreak || self == .longBreak }
    var isActive: Bool { self != .idle }

    var tint: Color {
        switch self {
        case .idle: return .secondary
        case .focus: return Color(red: 0.98, green: 0.42, blue: 0.28)
        case .shortBreak: return Color(red: 0.20, green: 0.68, blue: 0.66)
        case .longBreak: return Color(red: 0.28, green: 0.66, blue: 0.42)
        }
    }
}

// MARK: - Timer configuration

struct TimerConfig: Codable, Equatable {
    var focusMinutes: Int = 45
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var roundsBeforeLongBreak: Int = 4
    /// 0 表示不限轮次，手动停止才结束。
    var totalRounds: Int = 0
    var autoStartNextPhase: Bool = true

    static let `default` = TimerConfig()

    func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return TimeInterval(max(1, focusMinutes)) * 60
        case .shortBreak: return TimeInterval(max(1, shortBreakMinutes)) * 60
        case .longBreak: return TimeInterval(max(1, longBreakMinutes)) * 60
        case .idle: return 0
        }
    }

    mutating func normalize() {
        focusMinutes = min(max(focusMinutes, 1), 240)
        shortBreakMinutes = min(max(shortBreakMinutes, 1), 120)
        longBreakMinutes = min(max(longBreakMinutes, 1), 180)
        roundsBeforeLongBreak = min(max(roundsBeforeLongBreak, 1), 12)
        totalRounds = min(max(totalRounds, 0), 50)
    }
}

// MARK: - Schedule

enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case focus
    case rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "学习 / 工作"
        case .rest: return "休息"
        }
    }

    var shortTitle: String {
        switch self {
        case .focus: return "专注"
        case .rest: return "休息"
        }
    }

    var symbol: String {
        switch self {
        case .focus: return "brain.head.profile"
        case .rest: return "cup.and.saucer.fill"
        }
    }

    var tint: Color {
        switch self {
        case .focus: return Color(red: 0.98, green: 0.42, blue: 0.28)
        case .rest: return Color(red: 0.20, green: 0.68, blue: 0.66)
        }
    }
}

struct ScheduleBlock: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String = ""
    var kind: ScheduleKind = .focus
    /// Calendar weekday：1 = 周日，2 = 周一 … 7 = 周六。
    var weekdays: Set<Int> = Set(2...6)
    /// 从 0 点开始的分钟数，0...1439。
    var startMinute: Int = 9 * 60
    var endMinute: Int = 12 * 60
    var isEnabled: Bool = true

    var startText: String { Format.minuteOfDay(startMinute) }
    var endText: String { Format.minuteOfDay(endMinute) }
    var timeRangeText: String { "\(startText) – \(endText)" }

    var daysText: String {
        if weekdays.count == 7 { return "每天" }
        if weekdays == Set(2...6) { return "工作日" }
        if weekdays == Set([1, 7]) { return "周末" }
        let ordered = weekdays.sorted()
        return ordered.map { "周" + Format.weekdayName($0) }.joined(separator: " ")
    }

    var displayTitle: String {
        title.isEmpty ? kind.title : title
    }

    func occurs(onWeekday weekday: Int) -> Bool {
        isEnabled && weekdays.contains(weekday)
    }

    func contains(minute: Int) -> Bool {
        minute >= startMinute && minute < endMinute
    }

    func startDate(on day: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: startMinute, to: start)
    }

    func endDate(on day: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: endMinute, to: start)
    }

    static func newDefault() -> ScheduleBlock {
        ScheduleBlock(
            title: "",
            kind: .focus,
            weekdays: Set(2...6),
            startMinute: 9 * 60,
            endMinute: 12 * 60,
            isEnabled: true
        )
    }
}

struct MonitoredApp: Codable, Identifiable, Equatable {
    var bundleID: String
    var name: String

    var id: String { bundleID }
}

enum MenuBarStyle: String, Codable, CaseIterable, Identifiable {
    case iconAndTime
    case timeOnly
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconAndTime: return "图标 + 倒计时"
        case .timeOnly: return "仅倒计时"
        case .iconOnly: return "仅图标"
        }
    }
}

// MARK: - Settings

struct AppSettings: Codable, Equatable {
    var timer = TimerConfig()

    var scheduleEnabled = false
    var blocks: [ScheduleBlock] = []

    var soundEnabled = true
    var voiceEnabled = false
    var notificationsEnabled = true

    var distractionMonitorEnabled = true
    var monitoredApps: [MonitoredApp] = AppSettings.defaultMonitoredApps
    var distractionGraceSeconds: Int = 20

    var idleAutoPauseEnabled = true
    var idleThresholdSeconds: Int = 180

    var menuBarStyle: MenuBarStyle = .iconAndTime
    var showSecondsInMenuBar = true

    var launchAtLogin = false
    var hotkeysEnabled = true
    var dailyGoalMinutes = 120
    var autoStartFromSchedule = false
    var currentGoal = ""

    static let defaultMonitoredApps: [MonitoredApp] = [
        MonitoredApp(bundleID: "com.tencent.xinWeChat", name: "微信"),
        MonitoredApp(bundleID: "com.tencent.qq", name: "QQ"),
        MonitoredApp(bundleID: "com.bytedance.douyin", name: "抖音")
    ]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case timer, scheduleEnabled, blocks
        case soundEnabled, voiceEnabled, notificationsEnabled
        case distractionMonitorEnabled, monitoredApps, distractionGraceSeconds
        case idleAutoPauseEnabled, idleThresholdSeconds
        case menuBarStyle, showSecondsInMenuBar
        case launchAtLogin, hotkeysEnabled, dailyGoalMinutes, autoStartFromSchedule, currentGoal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timer = c.valueOr(.timer, TimerConfig())
        scheduleEnabled = c.valueOr(.scheduleEnabled, false)
        blocks = c.valueOr(.blocks, [])
        soundEnabled = c.valueOr(.soundEnabled, true)
        voiceEnabled = c.valueOr(.voiceEnabled, false)
        notificationsEnabled = c.valueOr(.notificationsEnabled, true)
        distractionMonitorEnabled = c.valueOr(.distractionMonitorEnabled, true)
        monitoredApps = c.valueOr(.monitoredApps, AppSettings.defaultMonitoredApps)
        distractionGraceSeconds = c.valueOr(.distractionGraceSeconds, 20)
        idleAutoPauseEnabled = c.valueOr(.idleAutoPauseEnabled, true)
        idleThresholdSeconds = c.valueOr(.idleThresholdSeconds, 180)
        menuBarStyle = c.valueOr(.menuBarStyle, .iconAndTime)
        showSecondsInMenuBar = c.valueOr(.showSecondsInMenuBar, true)
        launchAtLogin = c.valueOr(.launchAtLogin, false)
        hotkeysEnabled = c.valueOr(.hotkeysEnabled, true)
        dailyGoalMinutes = c.valueOr(.dailyGoalMinutes, 120)
        autoStartFromSchedule = c.valueOr(.autoStartFromSchedule, false)
        currentGoal = c.valueOr(.currentGoal, "")
    }

    mutating func normalize() {
        timer.normalize()
        monitoredApps = monitoredApps.filter { !$0.bundleID.isEmpty }
        distractionGraceSeconds = min(max(distractionGraceSeconds, 3), 120)
        idleThresholdSeconds = min(max(idleThresholdSeconds, 30), 1800)
        dailyGoalMinutes = min(max(dailyGoalMinutes, 15), 960)
        for index in blocks.indices {
            blocks[index].startMinute = min(max(blocks[index].startMinute, 0), 1439)
            blocks[index].endMinute = min(max(blocks[index].endMinute, 1), 1440)
        }
    }
}

private extension KeyedDecodingContainer {
    func valueOr<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        guard let decoded = try? decodeIfPresent(T.self, forKey: key) else { return fallback }
        return decoded
    }
}

// MARK: - Settings persistence

enum SettingsStore {
    static let key = "FocusGuard.settings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key) else { return AppSettings() }
        var settings = (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
        settings.normalize()
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Formatting

enum Format {
    static let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

    static func weekdayName(_ weekday: Int) -> String {
        let index = weekday - 1
        guard weekdayNames.indices.contains(index) else { return "?" }
        return weekdayNames[index]
    }

    static func minuteOfDay(_ minute: Int) -> String {
        let clamped = min(max(minute, 0), 1440)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    /// 倒计时字符串。默认向上取整，避免显示 00:00 却还没结束。
    static func clock(_ seconds: TimeInterval, showSeconds: Bool = true) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        if !showSeconds {
            let minutes = Int((Double(total) / 60).rounded(.up))
            if minutes >= 60 {
                return "\(minutes / 60) 小时 \(minutes % 60 > 0 ? "\(minutes % 60) 分" : "")".trimmingCharacters(in: .whitespaces)
            }
            return "\(minutes) 分钟"
        }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func hoursMinutes(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
        }
        return "\(minutes) 分钟"
    }

    static func decimalHours(_ seconds: TimeInterval) -> String {
        String(format: "%.1f", max(0, seconds) / 3600)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    static func timeOfDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        return shortDate(date)
    }
}
