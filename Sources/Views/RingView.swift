import SwiftUI

struct RingView: View {
    let progress: Double
    let phase: Phase
    let timeText: String
    let subtitle: String
    var size: CGFloat = 170
    var lineWidth: CGFloat = 13

    private var clamped: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.002, clamped))
                .stroke(
                    AngularGradient(
                        colors: [phase.tint.opacity(0.45), phase.tint, phase.tint],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: clamped)

            VStack(spacing: 5) {
                Text(phase == .idle ? "准备开始" : phase.menuTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(phase == .idle ? Color.secondary : phase.tint)

                Text(timeText)
                    .font(.system(size: 33, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: size, height: size)
    }
}
