import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DisciplineSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPageHeader(
                title: "自律护栏",
                subtitle: "在你想分心或离开时拉你一把。所有检测都在本机完成。"
            )

            SectionCard {
                Toggle(isOn: $model.settings.distractionMonitorEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("监控分心应用")
                        Text("专注阶段切到下列应用并停留一段时间时，提醒你回到正轨。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.settings.distractionMonitorEnabled {
                    Divider()
                    HStack {
                        Text("连续停留")
                        Spacer()
                        Picker("连续停留", selection: $model.settings.distractionGraceSeconds) {
                            Text("10 秒").tag(10)
                            Text("20 秒").tag(20)
                            Text("30 秒").tag(30)
                            Text("45 秒").tag(45)
                            Text("60 秒").tag(60)
                            Text("2 分钟").tag(120)
                        }
                        .labelsHidden()
                        .frame(width: 110)
                        Text("后提醒")
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("监控的应用")
                            Spacer()
                            Menu {
                                ForEach(runningApps) { app in
                                    Button(app.name) {
                                        model.addMonitoredApp(bundleID: app.bundleID, name: app.name)
                                    }
                                }
                                Divider()
                                Button("从「应用程序」中选择…") {
                                    chooseApplication()
                                }
                            } label: {
                                Label("添加", systemImage: "plus")
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }

                        if model.settings.monitoredApps.isEmpty {
                            Text("尚未添加应用。可以添加社交、视频或游戏类 App。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(model.settings.monitoredApps) { app in
                                monitoredAppRow(app)
                            }
                        }
                    }
                }
            }

            SectionCard {
                Toggle(isOn: $model.settings.idleAutoPauseEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("空闲时自动暂停")
                        Text("专注阶段检测到键盘和鼠标长时间无操作时，自动暂停计时。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.settings.idleAutoPauseEnabled {
                    Divider()
                    MinuteRow(
                        "判定为空闲",
                        subtitle: "只统计键鼠活动，不读取输入内容。",
                        value: idleMinutesBinding,
                        range: 1...30,
                        step: 1
                    )
                }
            }

            SectionCard {
                Toggle(isOn: $model.settings.hotkeysEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("全局快捷键")
                        Text("在任何应用里都能控制计时器，无需切回菜单栏。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if model.settings.hotkeysEnabled {
                    Divider()
                    HStack(spacing: 18) {
                        hotkeyRow(keys: ["⌃", "⌥", "S"], title: "开始 / 暂停 / 继续")
                        hotkeyRow(keys: ["⌃", "⌥", "K"], title: "跳过当前阶段")
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
                Text("分心监控使用 macOS 的应用激活通知，空闲检测使用系统空闲时间，不需要辅助功能或屏幕录制权限。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var idleMinutesBinding: Binding<Int> {
        Binding(
            get: { max(1, model.settings.idleThresholdSeconds / 60) },
            set: { model.settings.idleThresholdSeconds = max(60, $0 * 60) }
        )
    }

    private struct RunningApp: Identifiable, Hashable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    private var runningApps: [RunningApp] {
        let monitored = Set(model.settings.monitoredApps.map(\.bundleID))
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let bundleID = app.bundleIdentifier,
                      bundleID != Bundle.main.bundleIdentifier,
                      !monitored.contains(bundleID) else { return nil }
                return RunningApp(bundleID: bundleID, name: app.localizedName ?? bundleID)
            }
        return Array(Set(apps)).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func monitoredAppRow(_ app: MonitoredApp) -> some View {
        HStack(spacing: 9) {
            appIcon(for: app.bundleID)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.callout)
                Text(app.bundleID)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                model.removeMonitoredApp(bundleID: app.bundleID)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("移除")
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func appIcon(for bundleID: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: "app.dashed")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private func hotkeyRow(keys: [String], title: String) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(minWidth: 22, minHeight: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 3)
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "选择要监控的应用"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url) else { return }

        let bundleID = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        model.addMonitoredApp(bundleID: bundleID, name: name)
    }
}
