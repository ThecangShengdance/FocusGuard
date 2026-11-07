import AppKit
import SwiftUI

/// 屏幕右上角的应用内提醒横幅。
/// 当系统通知不可用（未授权 / ad-hoc 签名被拒 / 发送失败）时作为兜底，
/// 保证阶段切换、日程切换和分心提醒一定能被看到。
final class ReminderPresenter {
    static let shared = ReminderPresenter()

    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 104),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }

    func show(title: String, body: String, accent: NSColor = .systemOrange) {
        DispatchQueue.main.async {
            self.dismissWork?.cancel()

            let panel = self.panel ?? self.makePanel()
            self.panel = panel

            let root = ReminderBannerView(
                title: title,
                message: body,
                accent: Color(nsColor: accent),
                onClose: { self.hide() }
            )
            let host = NSHostingView(rootView: root)
            host.frame = NSRect(origin: .zero, size: panel.frame.size)
            host.autoresizingMask = [.width, .height]
            panel.contentView = host

            if let screen = NSScreen.main ?? NSScreen.screens.first {
                let visible = screen.visibleFrame
                panel.setFrameOrigin(
                    NSPoint(
                        x: visible.maxX - panel.frame.width - 12,
                        y: visible.maxY - panel.frame.height - 12
                    )
                )
            } else {
                panel.center()
            }

            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1
            }

            let work = DispatchWorkItem { self.hide() }
            self.dismissWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
        }
    }

    func hide() {
        dismissWork?.cancel()
        dismissWork = nil
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }
}

private struct ReminderBannerView: View {
    let title: String
    let message: String
    let accent: Color
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 1)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("关闭提醒")
        }
        .padding(14)
        .frame(width: 380, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
    }
}
