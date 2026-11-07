import Foundation

struct FocusSession: Codable, Identifiable {
    var id = UUID()
    var start: Date
    var end: Date
    var plannedSeconds: Double
    var actualSeconds: Double
    var completed: Bool
    var goal: String
}

struct DistractionEvent: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var appName: String
    var bundleID: String
}

struct StatsData: Codable {
    var sessions: [FocusSession] = []
    var distractions: [DistractionEvent] = []
}

struct DayStat: Identifiable {
    let date: Date
    let seconds: TimeInterval
    var id: String { Format.dayKey(for: date) }
    var minutes: Int { Int(seconds / 60) }
}

final class StatsStore {
    private(set) var data = StatsData()
    private let fileURL: URL
    private let calendar = Calendar.current

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? StatsStore.defaultURL()
        load()
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("FocusGuard", isDirectory: true)
            .appendingPathComponent("stats.json")
    }

    // MARK: - Recording

    func recordFocus(start: Date, end: Date, planned: TimeInterval, actual: TimeInterval, completed: Bool, goal: String) {
        let session = FocusSession(
            start: start,
            end: end,
            plannedSeconds: max(0, planned),
            actualSeconds: max(0, actual),
            completed: completed,
            goal: goal
        )
        data.sessions.append(session)
        prune()
        save()
    }

    func recordDistraction(app: MonitoredApp, at date: Date = Date()) {
        data.distractions.append(DistractionEvent(date: date, appName: app.name, bundleID: app.bundleID))
        prune()
        save()
    }

    func clearAll() {
        data = StatsData()
        save()
    }

    // MARK: - Queries

    func sessions(on day: Date) -> [FocusSession] {
        let key = Format.dayKey(for: day)
        return data.sessions.filter { Format.dayKey(for: $0.start) == key }
    }

    func focusSeconds(on day: Date) -> TimeInterval {
        sessions(on: day).reduce(0) { $0 + $1.actualSeconds }
    }

    func completedRounds(on day: Date) -> Int {
        sessions(on: day).filter(\.completed).count
    }

    func distractionCount(on day: Date) -> Int {
        let key = Format.dayKey(for: day)
        return data.distractions.filter { Format.dayKey(for: $0.date) == key }.count
    }

    var todayFocusSeconds: TimeInterval { focusSeconds(on: Date()) }
    var todayCompletedRounds: Int { completedRounds(on: Date()) }
    var todayDistractions: Int { distractionCount(on: Date()) }

    func last7Days() -> [DayStat] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset -> DayStat? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayStat(date: day, seconds: focusSeconds(on: day))
        }
    }

    var streakDays: Int {
        guard !data.sessions.isEmpty else { return 0 }
        let active = Set(data.sessions.filter { $0.actualSeconds >= 60 }.map { Format.dayKey(for: $0.start) })
        guard !active.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !active.contains(Format.dayKey(for: day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var count = 0
        while active.contains(Format.dayKey(for: day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
            if count > 3650 { break }
        }
        return count
    }

    var totalFocusSeconds: TimeInterval {
        data.sessions.reduce(0) { $0 + $1.actualSeconds }
    }

    // MARK: - Export

    func exportCSV() -> String {
        var lines = ["日期,开始时间,结束时间,计划分钟,实际分钟,是否完成,目标"]
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm:ss"

        for session in data.sessions.sorted(by: { $0.start < $1.start }) {
            let fields = [
                dayFormatter.string(from: session.start),
                timeFormatter.string(from: session.start),
                timeFormatter.string(from: session.end),
                String(format: "%.1f", session.plannedSeconds / 60),
                String(format: "%.1f", session.actualSeconds / 60),
                session.completed ? "是" : "否",
                session.goal
            ]
            lines.append(fields.map(StatsStore.csvEscape).joined(separator: ","))
        }
        lines.append("")
        lines.append("分心记录")
        lines.append("日期,时间,应用,Bundle ID")
        for event in data.distractions.sorted(by: { $0.date < $1.date }) {
            let fields = [
                dayFormatter.string(from: event.date),
                timeFormatter.string(from: event.date),
                event.appName,
                event.bundleID
            ]
            lines.append(fields.map(StatsStore.csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - Persistence

    private func prune() {
        if data.sessions.count > 10000 {
            data.sessions = Array(data.sessions.suffix(10000))
        }
        if data.distractions.count > 10000 {
            data.distractions = Array(data.distractions.suffix(10000))
        }
    }

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(StatsData.self, from: raw) {
            data = decoded
        }
    }

    private func save() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(data)
            try raw.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("FocusGuard 统计写入失败：\(error.localizedDescription)")
        }
    }
}
