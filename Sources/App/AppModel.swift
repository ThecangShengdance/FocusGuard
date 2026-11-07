import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI
import UniformTypeIdentifiers

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var settings: AppSettings {
        didSet { applySettings() }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var isAwaitingStart = false
    @Published private(set) var completedRounds = 0
    @Published private(set) var totalFocusRounds = 0

    @Published private(set) var todayFocusSeconds: TimeInterval = 0
    @Published private(set) var todayRounds = 0
    @Published private(set) var todayDistractions = 0
    @Published private(set) var weekStats: [DayStat] = []
    @Published private(set) var streakDays = 0

    @Published private(set) var currentSchedule: ScheduleBlock?
    @Published private(set) var nextScheduleBlock: ScheduleBlock?
    @Published private(set) var nextScheduleDate: Date?

    @Published private(set) var statusMessage: String?
    @Published var launchError: String?

    let engine = TimerEngine()
    private let stats = StatsStore()
    private let scheduleEngine = ScheduleEngine()
    private let idleMonitor = IdleMonitor()
    private let distractionMonitor = DistractionMonitor()
    private var hotKeyToggle: GlobalHotKey?
    private var hotKeySkip: GlobalHotKey?
    private var statusMessageWork: DispatchWorkItem?
    private var statsTimer: Timer?

    init() {
        settings = SettingsStore.load()
        engine.config = settings.timer

        engine.onTick = { [weak self] remaining in
            self?.applyEngineTick(remaining)
        }
        engine.onStateChanged = { [weak self] in
            guard let self else { return }
            self.applyEngineTick(self.engine.remaining)
        }
        engine.onPhaseFinished = { [weak self] result, next in
            self?.handlePhaseFinished(result, next: next)
        }
        engine.onInterrupted = { [weak self] result in
            self?.handleInterrupted(result)
        }
        engine.onCycleFinished = { [weak self] in
            self?.refreshStats()
        }

        idleMonitor.onIdle = { [weak self] idle in
            self?.handleIdle(idle)
        }
        idleMonitor.start()

        distractionMonitor.isFocusActive = { [weak self] in
            guard let self else { return false }
            return self.engine.phase.isFocus && self.engine.isRunning
        }
        distractionMonitor.onDistraction = { [weak self] app, seconds in
            self?.handleDistraction(app, after: seconds)
        }
        distractionMonitor.start()

        scheduleEngine.onTransition = { [weak self] previous, current, initial in
            self?.handleScheduleTransition(previous: previous, current: current, initial: initial)
        }
        scheduleEngine.start()

        refreshStats()
        applySettings()
        configureHotKeys()

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshStats()
            self?.refreshNextSchedule()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        statsTimer = timer
    }

    // MARK: - Timer actions

    func startTimer() {
        engine.start()
        statusMessage = nil
    }

    func toggleTimer() {
        engine.toggle()
    }

    func pauseTimer() {
        engine.pause()
    }

    func resumeTimer() {
        engine.resume()
    }

    func skipPhase() {
        engine.skip()
    }

    func stopCycle() {
        engine.stop()
    }

    private func applyEngineTick(_ remaining: TimeInterval) {
        let newPhase = engine.phase
        if newPhase != phase {
            phase = newPhase
            idleMonitor.reset()
        }
        self.remaining = remaining
        progress = engine.progress
        isRunning = engine.isRunning
        isPaused = engine.isPaused
        isAwaitingStart = engine.isAwaitingStart
        completedRounds = engine.completedFocusRounds
        totalFocusRounds = engine.totalFocusRounds
        distractionMonitor.focusStateChanged()
    }

    // MARK: - Phase lifecycle

    private func handlePhaseFinished(_ result: PhaseResult, next: Phase?) {
        // 引擎在回调前已推进轮次，这里先同步，避免通知文案使用旧值。
        applyEngineTick(engine.remaining)

        if result.phase.isFocus, result.actualSeconds >= 30 {
            stats.recordFocus(
                start: result.startedAt ?? result.endedAt.addingTimeInterval(-result.actualSeconds),
                end: result.endedAt,
                planned: result.plannedSeconds,
                actual: result.actualSeconds,
                completed: result.completed,
                goal: settings.currentGoal
            )
        }
        refreshStats()

        let autoStart = settings.timer.autoStartNextPhase
        let hint = autoStart ? "" : "点击「继续」开始。"

        switch result.phase {
        case .focus:
            if let next {
                let minutes = Int(settings.timer.duration(for: next) / 60)
                let title = result.completed ? "专注完成 🎉" : "已跳过本次专注"
                let body = result.completed
                    ? "第 \(totalFocusRounds) 轮完成，休息 \(minutes) 分钟。\(hint)"
                    : "进入休息 \(minutes) 分钟。\(hint)"
                notify(title: title, body: body)

                if result.completed, settings.soundEnabled {
                    SoundPlayer.phaseFinished()
                }
                if result.completed, settings.voiceEnabled {
                    SpeechService.shared.speak("专注完成，休息 \(minutes) 分钟")
                }
            } else {
                notify(
                    title: "循环完成 🏁",
                    body: "本轮共完成 \(completedRounds) 个专注轮次，累计 \(Format.hoursMinutes(todayFocusSeconds))。"
                )
                if settings.soundEnabled { SoundPlayer.phaseFinished() }
                if settings.voiceEnabled {
                    SpeechService.shared.speak("本轮计划完成，做得不错")
                }
            }

        case .shortBreak, .longBreak:
            if let next {
                let minutes = Int(settings.timer.duration(for: next) / 60)
                notify(
                    title: "休息结束 ☀️",
                    body: "开始第 \(totalFocusRounds + 1) 轮专注，\(minutes) 分钟。\(hint)"
                )
                if result.completed, settings.soundEnabled { SoundPlayer.breakFinished() }
                if result.completed, settings.voiceEnabled {
                    SpeechService.shared.speak("休息结束，开始专注")
                }
            } else {
                notify(title: "休息结束", body: "今天辛苦了，记得安排下一轮。")
            }

        case .idle:
            break
        }
    }

    private func handleInterrupted(_ result: PhaseResult) {
        if result.phase.isFocus, result.actualSeconds >= 30 {
            stats.recordFocus(
                start: result.startedAt ?? result.endedAt.addingTimeInterval(-result.actualSeconds),
                end: result.endedAt,
                planned: result.plannedSeconds,
                actual: result.actualSeconds,
                completed: false,
                goal: settings.currentGoal
            )
            refreshStats()
            showStatus("已停止，本次专注 \(Format.hoursMinutes(result.actualSeconds))")
        } else {
            showStatus("已停止")
        }
    }

    private func handleIdle(_ idle: TimeInterval) {
        guard settings.idleAutoPauseEnabled, engine.isRunning, engine.phase.isFocus else { return }
        engine.pause()
        showStatus("已离开 \(Format.hoursMinutes(idle))，自动暂停专注")
        if settings.voiceEnabled {
            SpeechService.shared.speak("检测到你离开了，已自动暂停")
        }
    }

    private func handleDistraction(_ app: MonitoredApp, after seconds: TimeInterval) {
        guard engine.isRunning, engine.phase.isFocus else { return }
        stats.recordDistraction(app: app)
        refreshStats()
        notify(
            title: "检测到分心 👀",
            body: "你在 \(app.name) 停留了 \(Int(seconds)) 秒，回来继续专注吧。"
        )
        showStatus("分心：\(app.name)")
        if settings.soundEnabled { SoundPlayer.distraction() }
        if settings.voiceEnabled { SpeechService.shared.speak("回到专注") }
    }

    // MARK: - Schedule

    private func handleScheduleTransition(previous: ScheduleBlock?, current: ScheduleBlock?, initial: Bool) {
        currentSchedule = current
        refreshNextSchedule()

        guard !initial else { return }

        if let current {
            let title = current.kind == .focus ? "日程：学习 / 工作时间" : "日程：休息时间"
            notify(
                title: title,
                body: "\(current.displayTitle) · \(current.timeRangeText)。\(current.kind == .focus ? "开始专注吧。" : "起来活动一下。")"
            )
            if current.kind == .focus, settings.autoStartFromSchedule, engine.phase == .idle {
                startTimer()
            }
            if settings.soundEnabled {
                SoundPlayer.play(current.kind == .focus ? "Glass" : "Ping")
            }
            if settings.voiceEnabled {
                SpeechService.shared.speak(current.kind == .focus ? "现在是学习工作时间" : "现在是休息时间")
            }
        } else if let previous {
            notify(
                title: "日程：\(previous.kind.shortTitle)时间结束",
                body: "现在进入自由时间。"
            )
        }
    }

    func refreshNextSchedule() {
        guard settings.scheduleEnabled else {
            nextScheduleBlock = nil
            nextScheduleDate = nil
            return
        }
        if let next = scheduleEngine.nextBlock(after: Date()) {
            nextScheduleBlock = next.block
            nextScheduleDate = next.start
        } else {
            nextScheduleBlock = nil
            nextScheduleDate = nil
        }
    }

    // MARK: - Settings

    func applySettings() {
        engine.config = settings.timer
        idleMonitor.isEnabled = settings.idleAutoPauseEnabled
        idleMonitor.threshold = TimeInterval(settings.idleThresholdSeconds)
        distractionMonitor.isEnabled = settings.distractionMonitorEnabled
        distractionMonitor.monitoredApps = settings.monitoredApps
        distractionMonitor.graceSeconds = TimeInterval(settings.distractionGraceSeconds)
        scheduleEngine.update(blocks: settings.blocks, isEnabled: settings.scheduleEnabled)
        // 编辑当前时段后，弹窗里的副本也要立即刷新。
        currentSchedule = settings.scheduleEnabled
            ? ScheduleResolver.block(at: Date(), blocks: settings.blocks)
            : nil
        refreshNextSchedule()
        SettingsStore.save(settings)
        configureHotKeys()
    }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { self.settings.launchAtLogin },
            set: { self.setLaunchAtLogin($0) }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if let error = LaunchAtLogin.set(enabled) {
            launchError = error
            return
        }
        launchError = nil
        settings.launchAtLogin = enabled
    }

    func resetSettings() {
        settings = AppSettings()
        refreshNextSchedule()
        showStatus("设置已恢复默认")
    }

    func addMonitoredApp(bundleID: String, name: String) {
        guard !bundleID.isEmpty,
              !settings.monitoredApps.contains(where: { $0.bundleID == bundleID }) else { return }
        settings.monitoredApps.append(MonitoredApp(bundleID: bundleID, name: name))
    }

    func removeMonitoredApp(bundleID: String) {
        settings.monitoredApps.removeAll { $0.bundleID == bundleID }
    }

    // MARK: - Stats

    func refreshStats() {
        todayFocusSeconds = stats.todayFocusSeconds
        todayRounds = stats.todayCompletedRounds
        todayDistractions = stats.todayDistractions
        weekStats = stats.last7Days()
        streakDays = stats.streakDays
    }

    func clearStats() {
        stats.clearAll()
        refreshStats()
        showStatus("统计已清空")
    }

    var recentSessions: [FocusSession] {
        stats.data.sessions.sorted { $0.start > $1.start }
    }

    var totalFocusSeconds: TimeInterval {
        stats.totalFocusSeconds
    }

    var weekTotalSeconds: TimeInterval {
        weekStats.reduce(0) { $0 + $1.seconds }
    }

    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "FocusGuard-\(Format.dayKey(for: Date())).csv"
        panel.title = "导出专注记录"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try stats.exportCSV().write(to: url, atomically: true, encoding: .utf8)
            showStatus("已导出到 \(url.lastPathComponent)")
        } catch {
            showStatus("导出失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Hot keys

    private func configureHotKeys() {
        hotKeyToggle = nil
        hotKeySkip = nil
        guard settings.hotkeysEnabled else { return }

        hotKeyToggle = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_S),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.toggleTimer()
        }

        hotKeySkip = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.skipPhase()
        }
    }

    // MARK: - Derived UI values

    var menuBarText: String {
        switch settings.menuBarStyle {
        case .iconOnly:
            return phase.symbol
        case .timeOnly:
            return phase == .idle ? "专注" : Format.clock(displayRemaining, showSeconds: settings.showSecondsInMenuBar)
        case .iconAndTime:
            return phase == .idle
                ? "\(phase.symbol) \(phase.menuLabel)"
                : "\(phase.symbol) \(phase.menuLabel) \(Format.clock(displayRemaining, showSeconds: settings.showSecondsInMenuBar))"
        }
    }

    var menuBarTooltip: String {
        if phase == .idle {
            return "FocusGuard · 准备开始"
        }
        let state = isRunning ? phase.title : (isAwaitingStart ? "等待开始" : "已暂停")
        return "FocusGuard · \(state) · \(Format.clock(remaining))"
    }

    var menuBarColor: NSColor {
        if phase == .idle { return NSColor.labelColor }
        if !isRunning { return NSColor.secondaryLabelColor }
        switch phase {
        case .focus: return NSColor.systemOrange
        case .shortBreak: return NSColor.systemTeal
        case .longBreak: return NSColor.systemGreen
        case .idle: return NSColor.labelColor
        }
    }

    var displayRemaining: TimeInterval {
        if phase == .idle { return 0 }
        return remaining
    }

    var phaseMinutes: Int {
        Int(settings.timer.duration(for: phase) / 60)
    }

    var roundDescription: String {
        let current = max(1, totalFocusRounds + (phase.isFocus ? 1 : 0))
        if settings.timer.totalRounds > 0 {
            return "第 \(min(current, settings.timer.totalRounds)) / \(settings.timer.totalRounds) 轮"
        }
        return "第 \(current) 轮"
    }

    var primaryActionTitle: String {
        if phase == .idle { return "开始专注" }
        if isRunning { return "暂停" }
        return isAwaitingStart ? "开始下一阶段" : "继续"
    }

    var todayGoalProgress: Double {
        let goal = TimeInterval(max(1, settings.dailyGoalMinutes)) * 60
        return min(1, todayFocusSeconds / goal)
    }

    var todayGoalText: String {
        "\(Format.hoursMinutes(todayFocusSeconds)) / \(settings.dailyGoalMinutes) 分钟"
    }

    var statusText: String {
        if let statusMessage { return statusMessage }
        switch phase {
        case .idle: return "准备好后点击开始，进入第一个专注阶段。"
        case .focus: return isRunning ? "保持专注，当前阶段结束后自动进入休息。" : "专注已暂停。"
        case .shortBreak: return isRunning ? "站起来活动一下，喝口水。" : "休息已暂停。"
        case .longBreak: return isRunning ? "长休息时间，离开屏幕走一走。" : "长休息已暂停。"
        }
    }

    // MARK: - Status message

    private func showStatus(_ message: String) {
        statusMessage = message
        statusMessageWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.statusMessage = nil
        }
        statusMessageWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func notify(title: String, body: String) {
        guard settings.notificationsEnabled else { return }
        NotificationService.shared.deliver(
            title: title,
            body: body,
            accent: NSColor(phase.tint)
        )
    }
}
