import SwiftUI

struct ScheduleSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingBlock: ScheduleBlock?

    private var sortedBlocks: [ScheduleBlock] {
        model.settings.blocks.sorted {
            if $0.startMinute != $1.startMinute { return $0.startMinute < $1.startMinute }
            return $0.displayTitle < $1.displayTitle
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsPageHeader(
                title: "日程提醒",
                subtitle: "按星期几和时段安排学习与休息，到点自动提醒你切换状态。"
            )

            SectionCard {
                Toggle(isOn: $model.settings.scheduleEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("启用日程提醒")
                        Text("到达设定时间时发送系统通知，提醒你开始或结束学习。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if model.settings.scheduleEnabled {
                    Divider()
                    Toggle(isOn: $model.settings.autoStartFromSchedule) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("日程开始时自动启动专注")
                            Text("仅在计时器空闲时生效；已经在专注中不会打断你。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            SectionCard("时间段") {
                if sortedBlocks.isEmpty {
                    EmptyHint(
                        symbol: "calendar.badge.plus",
                        title: "还没有时间段",
                        message: "添加一段学习时间和一段休息时间，让日程替你守住节奏。"
                    )
                } else {
                    ForEach(Array(sortedBlocks.enumerated()), id: \.element.id) { index, block in
                        blockRow(block)
                        if index < sortedBlocks.count - 1 {
                            Divider()
                        }
                    }
                }

                Button {
                    editingBlock = ScheduleBlock.newDefault()
                } label: {
                    Label("添加时间段", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 2)
            }

            currentStatus

            Text("同一星期几的时段不能重叠；结束时间必须晚于开始时间（不支持跨天，跨天请拆成两段）。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(item: $editingBlock) { block in
            ScheduleBlockEditor(block: block, existingBlocks: model.settings.blocks) { saved in
                upsert(saved)
            }
        }
    }

    @ViewBuilder
    private var currentStatus: some View {
        if model.settings.scheduleEnabled {
            SectionCard("当前状态") {
                if let current = model.currentSchedule {
                    HStack(spacing: 10) {
                        Image(systemName: current.kind.symbol)
                            .foregroundStyle(current.kind.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("正在「\(current.displayTitle)」")
                                .font(.callout.weight(.medium))
                            Text("\(current.timeRangeText) · \(current.daysText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(current.kind.shortTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(current.kind.tint)
                    }
                } else if let next = model.nextScheduleBlock, let date = model.nextScheduleDate {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(next.kind.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("下一段：\(next.displayTitle)")
                                .font(.callout.weight(.medium))
                            Text("\(Format.relativeDay(date)) \(Format.timeOfDay(date)) 开始")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("暂无正在进行的时段，也没有找到后续安排。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func blockRow(_ block: ScheduleBlock) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(block.isEnabled ? block.kind.tint : Color.secondary.opacity(0.3))
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(block.displayTitle)
                        .font(.callout.weight(.medium))
                        .strikethrough(!block.isEnabled, color: .secondary)
                    Text(block.kind.shortTitle)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(block.kind.tint.opacity(block.isEnabled ? 0.13 : 0.06)))
                        .foregroundStyle(block.isEnabled ? block.kind.tint : .secondary)
                }
                Text("\(block.daysText) · \(block.timeRangeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Toggle("", isOn: enabledBinding(for: block))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            Button {
                editingBlock = block
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("编辑")

            Button {
                delete(block)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("删除")
        }
        .opacity(block.isEnabled ? 1 : 0.62)
    }

    private func enabledBinding(for block: ScheduleBlock) -> Binding<Bool> {
        Binding(
            get: { block.isEnabled },
            set: { newValue in
                var blocks = model.settings.blocks
                guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
                blocks[index].isEnabled = newValue
                model.settings.blocks = blocks
                if newValue, !model.settings.scheduleEnabled {
                    model.settings.scheduleEnabled = true
                }
            }
        )
    }

    private func delete(_ block: ScheduleBlock) {
        model.settings.blocks.removeAll { $0.id == block.id }
    }

    private func upsert(_ block: ScheduleBlock) {
        var blocks = model.settings.blocks
        if let index = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[index] = block
        } else {
            blocks.append(block)
        }
        model.settings.blocks = blocks
        if block.isEnabled, !model.settings.scheduleEnabled {
            model.settings.scheduleEnabled = true
        }
    }
}

struct ScheduleBlockEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ScheduleBlock
    @State private var errorText: String?

    private let existingBlocks: [ScheduleBlock]
    private let onSave: (ScheduleBlock) -> Void

    private let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    init(block: ScheduleBlock, existingBlocks: [ScheduleBlock], onSave: @escaping (ScheduleBlock) -> Void) {
        _draft = State(initialValue: block)
        self.existingBlocks = existingBlocks
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(existingBlocks.contains(where: { $0.id == draft.id }) ? "编辑时间段" : "添加时间段")
                    .font(.title3.weight(.semibold))
                Text("设置名称、类型、重复的星期和起止时间。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("名称")
                    .font(.callout.weight(.medium))
                TextField("例如：上午写论文", text: $draft.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("类型")
                    .font(.callout.weight(.medium))
                Picker("类型", selection: $draft.kind) {
                    ForEach(ScheduleKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("重复")
                        .font(.callout.weight(.medium))
                    Spacer()
                    Button("工作日") { draft.weekdays = Set(2...6) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    Button("每天") { draft.weekdays = Set(1...7) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    Button("周末") { draft.weekdays = Set([1, 7]) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }

                HStack(spacing: 7) {
                    ForEach(weekdayOrder, id: \.self) { weekday in
                        let selected = draft.weekdays.contains(weekday)
                        Button {
                            if selected {
                                draft.weekdays.remove(weekday)
                            } else {
                                draft.weekdays.insert(weekday)
                            }
                        } label: {
                            Text(Format.weekdayName(weekday))
                                .font(.callout.weight(selected ? .semibold : .regular))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(selected ? draft.kind.tint.opacity(0.18) : Color.primary.opacity(0.05))
                                )
                                .foregroundStyle(selected ? draft.kind.tint : Color.primary)
                                .overlay(
                                    Circle().stroke(selected ? draft.kind.tint.opacity(0.45) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("开始")
                        .font(.callout.weight(.medium))
                    DatePicker("", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("结束")
                        .font(.callout.weight(.medium))
                    DatePicker("", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                Spacer()
                Text(draft.timeRangeText)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(draft.kind.tint)
                    .padding(.top, 20)
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("时段切换时会发送通知；开启「自动启动专注」后，学习时段开始还会自动启动计时器。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 470, height: 560)
    }

    private func timeBinding(_ keyPath: WritableKeyPath<ScheduleBlock, Int>) -> Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let base = calendar.startOfDay(for: Date())
                return calendar.date(byAdding: .minute, value: draft[keyPath: keyPath], to: base) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                draft[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    private func save() {
        var candidate = draft
        candidate.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !candidate.weekdays.isEmpty else {
            errorText = "至少选择一天。"
            return
        }
        guard candidate.endMinute > candidate.startMinute else {
            errorText = "结束时间必须晚于开始时间。"
            return
        }

        for other in existingBlocks where other.id != candidate.id && other.isEnabled {
            guard !other.weekdays.isDisjoint(with: candidate.weekdays) else { continue }
            if candidate.startMinute < other.endMinute && other.startMinute < candidate.endMinute {
                errorText = "与「\(other.displayTitle) \(other.timeRangeText)」时间重叠。"
                return
            }
        }

        onSave(candidate)
        dismiss()
    }
}
