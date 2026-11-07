import SwiftUI

struct StatsSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPageHeader(
                title: "专注统计",
                subtitle: "记录每一次专注，让进步看得见。数据只保存在本机。"
            )

            HStack(spacing: 10) {
                StatTile(
                    title: "今日专注",
                    value: Format.decimalHours(model.todayFocusSeconds) + " 小时",
                    symbol: "clock.fill",
                    tint: Phase.focus.tint
                )
                StatTile(
                    title: "今日完成",
                    value: "\(model.todayRounds) 轮",
                    symbol: "checkmark.seal.fill",
                    tint: Phase.shortBreak.tint
                )
                StatTile(
                    title: "连续天数",
                    value: "\(model.streakDays) 天",
                    symbol: "flame.fill",
                    tint: .orange
                )
                StatTile(
                    title: "今日分心",
                    value: "\(model.todayDistractions) 次",
                    symbol: "eye.slash.fill",
                    tint: .secondary
                )
            }

            SectionCard("最近 7 天") {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(model.weekStats) { stat in
                        chartColumn(stat)
                    }
                }
                .frame(height: 150)
                .padding(.top, 4)

                HStack {
                    Text("本周累计 \(Format.hoursMinutes(model.weekTotalSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("平均 \(Format.hoursMinutes(model.weekTotalSeconds / 7)) / 天")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SectionCard("今日目标") {
                HStack {
                    Text(model.todayGoalText)
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text("\(Int((model.todayGoalProgress * 100).rounded()))%")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(model.todayGoalProgress >= 1 ? Phase.shortBreak.tint : .secondary)
                }
                ProgressView(value: model.todayGoalProgress)
                    .tint(model.todayGoalProgress >= 1 ? Phase.shortBreak.tint : Phase.focus.tint)
                Text("每日目标可在「计时」页修改。累计专注 \(Format.hoursMinutes(model.totalFocusSeconds))。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SectionCard("最近记录") {
                let sessions = Array(model.recentSessions.prefix(6))
                if sessions.isEmpty {
                    EmptyHint(
                        symbol: "clock.badge.questionmark",
                        title: "还没有记录",
                        message: "完成一次专注后，这里会显示你的专注历史。"
                    )
                } else {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        sessionRow(session)
                        if index < sessions.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    model.exportCSV()
                } label: {
                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(model.recentSessions.isEmpty)

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("清空统计", systemImage: "trash")
                }

                Spacer()
            }
        }
        .alert("清空所有统计？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                model.clearStats()
            }
        } message: {
            Text("专注记录和分心记录都会被删除，且无法恢复。")
        }
    }

    private func chartColumn(_ stat: DayStat) -> some View {
        let maxSeconds = max(model.weekStats.map(\.seconds).max() ?? 0, 1)
        let ratio = max(0, min(1, stat.seconds / maxSeconds))
        let isToday = Calendar.current.isDateInToday(stat.date)
        let height = max(4, CGFloat(ratio) * 96)

        return VStack(spacing: 5) {
            Text(stat.minutes > 0 ? "\(stat.minutes)" : "–")
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isToday ? Phase.focus.tint : .secondary)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isToday
                            ? [Phase.focus.tint, Phase.focus.tint.opacity(0.55)]
                            : [Phase.focus.tint.opacity(0.4), Phase.focus.tint.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 26, height: height)

            Text(dayLabel(stat.date))
                .font(.system(size: 10, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Color.primary : Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .frame(height: 128, alignment: .bottom)
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        let weekday = Calendar.current.component(.weekday, from: date)
        return "周" + Format.weekdayName(weekday)
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(session.completed ? Phase.shortBreak.tint : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.goal.isEmpty ? "专注" : session.goal)
                    .font(.callout)
                    .lineLimit(1)
                Text("\(Format.shortDate(session.start)) · \(Format.timeOfDay(session.start)) – \(Format.timeOfDay(session.end))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Text(Format.hoursMinutes(session.actualSeconds))
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
