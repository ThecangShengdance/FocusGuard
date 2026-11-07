import Foundation

struct PhaseResult {
    let phase: Phase
    let plannedSeconds: TimeInterval
    let actualSeconds: TimeInterval
    let completed: Bool
    let startedAt: Date?
    let endedAt: Date
}

/// 以「结束时刻」为准的倒计时引擎，避免 Timer 抖动导致累计误差。
/// 所有回调都在主线程触发。
final class TimerEngine {
    private(set) var phase: Phase = .idle
    private(set) var isRunning = false
    private(set) var isPaused = false
    private(set) var completedFocusRounds = 0
    private(set) var totalFocusRounds = 0
    private(set) var plannedDuration: TimeInterval = 0
    private(set) var phaseStartedAt: Date?
    private(set) var cycleStartedAt: Date?

    var config: TimerConfig = .default
    var now: () -> Date = Date.init

    var onTick: ((TimeInterval) -> Void)?
    /// 当前阶段结束（自然完成或跳过），next 为 nil 表示整个循环结束。
    var onPhaseFinished: ((PhaseResult, Phase?) -> Void)?
    /// 用户手动停止，会丢弃当前阶段；可用于记录部分专注。
    var onInterrupted: ((PhaseResult) -> Void)?
    var onCycleFinished: (() -> Void)?
    var onStateChanged: (() -> Void)?

    private var endDate: Date?
    private var remainingWhenPaused: TimeInterval = 0
    private var accumulated: TimeInterval = 0
    private var lastResumeAt: Date?
    private var timer: Timer?
    private var activity: NSObjectProtocol?

    deinit {
        timer?.invalidate()
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
    }

    var remaining: TimeInterval {
        guard phase != .idle else { return 0 }
        if isRunning, let endDate {
            return max(0, endDate.timeIntervalSince(now()))
        }
        return max(0, remainingWhenPaused)
    }

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / plannedDuration))
    }

    /// 阶段已经准备好，但等待用户点击「继续」（例如关闭了自动开始下一阶段）。
    var isAwaitingStart: Bool {
        phase != .idle && isPaused && accumulated <= 0.01
    }

    var roundInCycle: Int {
        guard phase.isFocus else { return totalFocusRounds }
        return min(totalFocusRounds + (isRunning || isPaused ? 1 : 0), max(1, config.totalRounds > 0 ? config.totalRounds : Int.max))
    }

    // MARK: - Actions

    func start() {
        if phase == .idle {
            completedFocusRounds = 0
            totalFocusRounds = 0
            cycleStartedAt = now()
            begin(.focus, autoStart: true)
        } else if isPaused {
            resume()
        }
    }

    func pause() {
        guard isRunning else { return }
        let date = now()
        remainingWhenPaused = remaining
        if let lastResumeAt {
            accumulated += max(0, date.timeIntervalSince(lastResumeAt))
        }
        lastResumeAt = nil
        isRunning = false
        isPaused = true
        endDate = nil
        stopTimer()
        endActivity()
        onTick?(remainingWhenPaused)
        onStateChanged?()
    }

    func resume() {
        guard phase != .idle, isPaused else { return }
        if remainingWhenPaused <= 0 {
            remainingWhenPaused = plannedDuration
        }
        startCountdown()
    }

    func toggle() {
        if isRunning {
            pause()
        } else if phase == .idle {
            start()
        } else {
            resume()
        }
    }

    /// 跳过当前阶段，不计为完成，但推进轮次。
    func skip() {
        guard phase != .idle else { return }
        finishCurrent(natural: false)
    }

    /// 手动终止整个循环。
    func stop() {
        guard phase != .idle else { return }
        let date = now()
        let previous = phase
        var actual = accumulated
        if isRunning, let lastResumeAt {
            actual += max(0, date.timeIntervalSince(lastResumeAt))
        }
        let result = PhaseResult(
            phase: previous,
            plannedSeconds: plannedDuration,
            actualSeconds: max(0, actual),
            completed: false,
            startedAt: phaseStartedAt,
            endedAt: date
        )

        stopTimer()
        endActivity()
        isRunning = false
        isPaused = false
        endDate = nil
        lastResumeAt = nil
        accumulated = 0
        remainingWhenPaused = 0
        phaseStartedAt = nil
        plannedDuration = 0
        phase = .idle
        completedFocusRounds = 0
        totalFocusRounds = 0
        cycleStartedAt = nil

        onInterrupted?(result)
        onTick?(0)
        onStateChanged?()
    }

    // MARK: - Internals

    private func begin(_ next: Phase, autoStart: Bool) {
        stopTimer()
        endActivity()
        phase = next
        plannedDuration = config.duration(for: next)
        remainingWhenPaused = plannedDuration
        accumulated = 0
        phaseStartedAt = nil
        lastResumeAt = nil
        endDate = nil
        isRunning = false
        isPaused = false

        if autoStart {
            startCountdown()
        } else {
            isPaused = true
            onTick?(plannedDuration)
            onStateChanged?()
        }
    }

    private func startCountdown() {
        let date = now()
        if phaseStartedAt == nil {
            phaseStartedAt = date
        }
        isRunning = true
        isPaused = false
        lastResumeAt = date
        endDate = date.addingTimeInterval(remainingWhenPaused)
        startTimer()
        beginActivity()
        onTick?(remainingWhenPaused)
        onStateChanged?()
    }

    private func finishCurrent(natural: Bool) {
        guard phase != .idle else { return }
        let date = now()
        let previous = phase
        var actual = accumulated
        if isRunning, let lastResumeAt {
            actual += max(0, date.timeIntervalSince(lastResumeAt))
        }
        if natural {
            actual = plannedDuration
        }
        let result = PhaseResult(
            phase: previous,
            plannedSeconds: plannedDuration,
            actualSeconds: max(0, actual),
            completed: natural,
            startedAt: phaseStartedAt,
            endedAt: date
        )

        stopTimer()
        endActivity()
        isRunning = false
        isPaused = false
        endDate = nil
        lastResumeAt = nil
        accumulated = 0
        remainingWhenPaused = 0
        phaseStartedAt = nil

        var next: Phase?
        if previous.isFocus {
            totalFocusRounds += 1
            if natural {
                completedFocusRounds += 1
            }
            if config.totalRounds > 0 && totalFocusRounds >= config.totalRounds {
                next = nil
            } else if totalFocusRounds % max(1, config.roundsBeforeLongBreak) == 0 {
                next = .longBreak
            } else {
                next = .shortBreak
            }
        } else {
            next = .focus
        }

        onPhaseFinished?(result, next)

        if let next {
            begin(next, autoStart: config.autoStartNextPhase)
        } else {
            phase = .idle
            plannedDuration = 0
            onCycleFinished?()
            completedFocusRounds = 0
            totalFocusRounds = 0
            cycleStartedAt = nil
            onTick?(0)
            onStateChanged?()
        }
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.5, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func beginActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated], reason: "FocusGuard 倒计时")
    }

    private func endActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    @objc private func tick() {
        guard isRunning else { return }
        let left = remaining
        if left <= 0.05 {
            finishCurrent(natural: true)
        } else {
            onTick?(left)
        }
    }
}
