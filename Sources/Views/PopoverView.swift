import AppKit
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 13) {
            header
            goal
            RingView(
                progress: model.progress,
                phase: model.phase,
                timeText: model.phase == .idle ? "--:--" : Format.clock(model.remaining),
                subtitle: ringSubtitle
            )
            controls
            roundRow
            Divider()
            statsRow
            scheduleRow
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 336)
        .onAppear {
            model.refreshStats()
            model.refreshNextSchedule()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            PhaseBadge(phase: model.phase, paused: model.phase != .idle && !model.isRunning)
            Spacer()
            if model.settings.scheduleEnabled, let schedule = model.currentSchedule {
                Text(schedule.kind.shortTitle)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(schedule.kind.tint.opacity(0.12)))
                    .foregroundStyle(schedule.kind.tint)
            }
            Button {
                NotificationCenter.default.post(name: .focusGuardOpenSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("打开设置")
        }
    }

    private var goal: some View {
        Group {
            if model.settings.currentGoal.isEmpty {
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(model.phase.tint)
                    Text(model.settings.currentGoal)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minHeight: 34)
    }

    private var ringSubtitle: String {
        switch model.phase {
        case .idle:
            let total = model.settings.timer.totalRounds
            let focus = model.settings.timer.focusMinutes
            return total > 0
                ? "共 \(total) 轮 · 每轮 \(focus) 分钟"
                : "不限轮次 · 每轮 \(focus) 分钟"
        case .focus:
            return model.roundDescription
        case .shortBreak, .longBreak:
            if model.totalFocusRounds > 0 {
                return "已完成 \(model.completedRounds) 轮专注"
            }
            return "放松一下眼睛"
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                model.toggleTimer()
            } label: {
                Label(model.primaryActionTitle, systemImage: model.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(model.phase == .idle ? Color.accentColor : model.phase.tint)

            if model.phase != .idle {
                Button {
                    model.skipPhase()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .frame(width: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("跳过当前阶段（⌃⌥K）")

                Button {
                    model.stopCycle()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("终止整个循环")
            }
        }
    }

    private var roundRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<dotTotal, id: \.self) { index in
                Circle()
                    .fill(index < dotDone ? model.phase.tint : Color.secondary.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
            Spacer()
            Text(roundCaption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(height: 14)
    }

    private var dotTotal: Int {
        if model.settings.timer.totalRounds > 0 {
            return min(model.settings.timer.totalRounds, 12)
        }
        return min(model.settings.timer.roundsBeforeLongBreak, 12)
    }

    private var dotDone: Int {
        if model.settings.timer.totalRounds > 0 {
            return min(model.totalFocusRounds, dotTotal)
        }
        if model.phase == .longBreak {
            return dotTotal
        }
        return model.totalFocusRounds % max(1, model.settings.timer.roundsBeforeLongBreak)
    }

    private var roundCaption: String {
        let total = model.settings.timer.totalRounds
        if total > 0 {
            return "\(dotDone) / \(total) 轮"
        }
        let remaining = max(0, model.settings.timer.roundsBeforeLongBreak - dotDone)
        return remaining == 0 ? "该长休息了" : "再 \(remaining) 轮长休息"
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            StatTile(
                title: "今日专注",
                value: Format.decimalHours(model.todayFocusSeconds) + "h",
                symbol: "clock",
                tint: Phase.focus.tint
            )
            StatTile(
                title: "完成轮次",
                value: "\(model.todayRounds)",
                symbol: "checkmark.circle",
                tint: Phase.shortBreak.tint
            )
            StatTile(
                title: "分心次数",
                value: "\(model.todayDistractions)",
                symbol: "eye.slash",
                tint: .secondary
            )
        }
    }

    private var scheduleRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let block = model.currentSchedule {
                HStack(spacing: 6) {
                    Image(systemName: block.kind.symbol)
                        .foregroundStyle(block.kind.tint)
                    Text("当前日程 · \(block.displayTitle)")
                        .lineLimit(1)
                    Spacer()
                    Text(block.timeRangeText)
                        .monospacedDigit()
                }
                Text("到点会提醒你切换到\(block.kind == .focus ? "休息" : "专注")")
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            } else if model.settings.scheduleEnabled,
                      let next = model.nextScheduleBlock,
                      let date = model.nextScheduleDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundStyle(next.kind.tint)
                    Text("下一段 · \(Format.relativeDay(date)) \(Format.timeOfDay(date))")
                    Spacer()
                    Text(next.displayTitle)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                    Text(scheduleHint)
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }

    private var scheduleHint: String {
        if !model.settings.scheduleEnabled { return "日程提醒未开启" }
        if model.settings.blocks.isEmpty { return "日程已开启 · 还没有时间段" }
        return "日程已开启 · 暂无后续安排"
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("设置") {
                NotificationCenter.default.post(name: .focusGuardOpenSettings, object: nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)

            if model.streakDays > 0 {
                Text("🔥 连续 \(model.streakDays) 天")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("退出") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }
}
