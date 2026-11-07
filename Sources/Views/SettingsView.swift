import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case timer
    case schedule
    case stats
    case discipline
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "计时"
        case .schedule: return "日程"
        case .stats: return "统计"
        case .discipline: return "自律"
        case .general: return "通用"
        }
    }

    var symbol: String {
        switch self {
        case .timer: return "timer"
        case .schedule: return "calendar"
        case .stats: return "chart.bar.xaxis"
        case .discipline: return "shield.lefthalf.filled"
        case .general: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: SettingsPage?

    init(initialPage: SettingsPage = .timer) {
        _selection = State(initialValue: initialPage)
    }

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selection) {
                Section("设置") {
                    ForEach(SettingsPage.allCases) { page in
                        Label(page.title, systemImage: page.symbol)
                            .tag(page)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(width: 186)

            Divider()

            ScrollView {
                content
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        switch selection ?? .timer {
        case .timer:
            TimerSettingsView()
        case .schedule:
            ScheduleSettingsView()
        case .stats:
            StatsSettingsView()
        case .discipline:
            DisciplineSettingsView()
        case .general:
            GeneralSettingsView()
        }
    }
}
