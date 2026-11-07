import Foundation

enum ScheduleResolver {
    static func block(at date: Date, blocks: [ScheduleBlock], calendar: Calendar = .current) -> ScheduleBlock? {
        let weekday = calendar.component(.weekday, from: date)
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return blocks
            .filter { $0.occurs(onWeekday: weekday) && $0.contains(minute: minute) }
            .sorted { $0.startMinute < $1.startMinute }
            .first
    }

    static func nextBlock(after date: Date,
                          blocks: [ScheduleBlock],
                          calendar: Calendar = .current) -> (block: ScheduleBlock, start: Date)? {
        let enabled = blocks.filter { $0.isEnabled && $0.endMinute > $0.startMinute }
        guard !enabled.isEmpty else { return nil }

        let today = calendar.startOfDay(for: date)
        var best: (block: ScheduleBlock, start: Date)?

        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            for block in enabled where block.weekdays.contains(weekday) {
                guard let start = calendar.date(byAdding: .minute, value: block.startMinute, to: day) else { continue }
                guard start > date else { continue }
                if best == nil || start < best!.start {
                    best = (block, start)
                }
            }
        }
        return best
    }
}

/// 每秒检查一次日程，只在「当前块」发生变化时回调，避免重复提醒。
final class ScheduleEngine {
    var blocks: [ScheduleBlock] = []
    var isEnabled = false
    var calendar: Calendar = .current
    var now: () -> Date = Date.init

    /// previous / current / isInitial（首次评估或静默刷新时为 true，不弹提醒）。
    var onTransition: ((ScheduleBlock?, ScheduleBlock?, Bool) -> Void)?

    private var timer: Timer?
    private var lastBlockID: UUID?
    private var hasBootstrapped = false

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        evaluate(notify: false)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func update(blocks: [ScheduleBlock], isEnabled: Bool, notify: Bool = false) {
        self.blocks = blocks
        self.isEnabled = isEnabled
        evaluate(notify: notify)
    }

    func evaluate(notify: Bool = true) {
        let current = isEnabled
            ? ScheduleResolver.block(at: now(), blocks: blocks, calendar: calendar)
            : nil

        if !hasBootstrapped {
            hasBootstrapped = true
            lastBlockID = current?.id
            onTransition?(nil, current, true)
            return
        }

        guard current?.id != lastBlockID else { return }

        let previous = lastBlockID.flatMap { id in blocks.first { $0.id == id } }
        lastBlockID = current?.id
        onTransition?(previous, current, !notify)
    }

    func nextBlock(after date: Date = Date()) -> (block: ScheduleBlock, start: Date)? {
        guard isEnabled else { return nil }
        return ScheduleResolver.nextBlock(after: date, blocks: blocks, calendar: calendar)
    }

    @objc private func tick() {
        evaluate(notify: true)
    }
}
