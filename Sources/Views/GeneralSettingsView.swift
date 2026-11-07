import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPageHeader(
                title: "通用",
                subtitle: "菜单栏外观、提醒方式与启动选项。"
            )

            SectionCard("菜单栏") {
                Picker("菜单栏显示", selection: $model.settings.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Toggle(isOn: $model.settings.showSecondsInMenuBar) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("显示秒数")
                        Text("关闭后只显示分钟，菜单栏更安静。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("预览")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(model.menuBarText)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.07))
                        )
                }
            }

            SectionCard("提醒") {
                Toggle(isOn: $model.settings.notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("阶段提醒")
                        Text("阶段结束、日程切换和分心提醒都会提醒你；系统通知不可用时自动显示应用内横幅。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider()
                Toggle(isOn: $model.settings.soundEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("提示音")
                        Text("阶段切换时播放简短的提示音。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                Toggle(isOn: $model.settings.voiceEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("语音播报")
                        Text("用中文朗读「现在是学习工作时间 / 休息时间」。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("应用内提醒")
                        Text("系统通知不可用时，会在屏幕右上角显示提醒横幅，确保不会错过阶段切换。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("打开系统通知设置") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    Spacer(minLength: 8)
                    Button("测试提醒") {
                        NotificationService.shared.deliver(
                            title: "专注卫士",
                            body: "这是一条测试提醒：该休息一下了。",
                            accent: NSColor(model.phase.tint)
                        )
                    }
                    .controlSize(.small)
                }
            }

            SectionCard("启动") {
                Toggle(isOn: model.launchAtLoginBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("登录时自动启动")
                        Text("开机后静默驻留在菜单栏。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let launchError = model.launchError {
                    Label(launchError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("系统可能要求在「系统设置 → 通用 → 登录项」中允许 FocusGuard。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SectionCard("数据与重置") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("恢复默认设置")
                        Text("计时、日程、提醒和监控设置都会回到初始值。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("恢复默认") {
                        showResetConfirm = true
                    }
                }

                Text("所有设置和统计均保存在本机，不会上传。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SectionCard("关于") {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 30))
                        .foregroundStyle(Phase.focus.tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FocusGuard · 专注卫士")
                            .font(.callout.weight(.semibold))
                        Text("版本 \(version) · 菜单栏自律计时器")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text("专注 45 分钟，休息 5 分钟；把节奏交给计时器，把注意力留给自己。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .alert("恢复默认设置？", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                model.resetSettings()
            }
        } message: {
            Text("当前设置会被覆盖，统计数据不会被删除。")
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
