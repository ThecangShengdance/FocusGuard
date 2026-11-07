import SwiftUI

struct TimerSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPageHeader(
                title: "计时规则",
                subtitle: "设置每一轮专注与休息的时长，以及它们如何循环。"
            )

            SectionCard("阶段时长") {
                MinuteRow(
                    "专注时长",
                    subtitle: "建议 25–60 分钟，保持单段高强度投入。",
                    value: $model.settings.timer.focusMinutes,
                    range: 1...180,
                    step: 5
                )
                Divider()
                MinuteRow(
                    "短休息",
                    subtitle: "每轮专注后的短暂放松，起身走动、远眺。",
                    value: $model.settings.timer.shortBreakMinutes,
                    range: 1...60,
                    step: 1
                )
                Divider()
                MinuteRow(
                    "长休息",
                    subtitle: "完成若干轮后较长的恢复时间。",
                    value: $model.settings.timer.longBreakMinutes,
                    range: 5...120,
                    step: 5
                )
            }

            SectionCard("循环方式") {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("长休息间隔")
                        Text("每完成这么多轮专注，进入一次长休息。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper(
                        "\(model.settings.timer.roundsBeforeLongBreak) 轮",
                        value: $model.settings.timer.roundsBeforeLongBreak,
                        in: 1...12
                    )
                    .monospacedDigit()
                }

                Divider()

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("总轮次")
                        Text("0 表示不限，由你手动终止整个循环。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(model.settings.timer.totalRounds == 0 ? "不限" : "\(model.settings.timer.totalRounds) 轮")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Stepper("", value: $model.settings.timer.totalRounds, in: 0...50)
                        .labelsHidden()
                }

                Divider()

                Toggle(isOn: $model.settings.timer.autoStartNextPhase) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("自动开始下一阶段")
                        Text("关闭后，每个阶段结束会暂停，等你准备好再继续。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SectionCard("今日目标") {
                MinuteRow(
                    "每日专注目标",
                    subtitle: "用于菜单栏弹窗里的目标进度。",
                    value: $model.settings.dailyGoalMinutes,
                    range: 30...720,
                    step: 15
                )
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("本轮目标")
                    TextField("例如：写完第三章习题", text: $model.settings.currentGoal)
                        .textFieldStyle(.roundedBorder)
                    Text("会显示在菜单栏弹窗顶部，提醒你这一轮为什么而坐。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SectionCard("计划预览") {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Phase.focus.tint)
                    Text(previewText)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("修改会立即保存；正在进行的阶段不受影响，下一阶段起生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var previewText: String {
        let config = model.settings.timer
        var text = "\(config.focusMinutes) 分钟专注 → \(config.shortBreakMinutes) 分钟短休息，"
        text += "每 \(config.roundsBeforeLongBreak) 轮换成 \(config.longBreakMinutes) 分钟长休息。"
        if config.totalRounds > 0 {
            text += "完成 \(config.totalRounds) 轮后自动结束。"
        } else {
            text += "之后继续循环，直到你手动停止。"
        }
        return text
    }
}
