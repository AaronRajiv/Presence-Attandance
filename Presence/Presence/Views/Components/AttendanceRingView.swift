import SwiftUI

public struct AttendanceRingView: View {
    public let pct: Int?
    public let tintColor: Color
    public let size: CGFloat
    public let strokeWidth: CGFloat
    public let showPercentSymbol: Bool

    public init(
        pct: Int?,
        tintColor: Color = PresenceTheme.blueAccent,
        size: CGFloat = 40,
        strokeWidth: CGFloat = 3.5,
        showPercentSymbol: Bool = false
    ) {
        self.pct = pct
        self.tintColor = tintColor
        self.size = size
        self.strokeWidth = strokeWidth
        self.showPercentSymbol = showPercentSymbol
    }

    private var progress: Double {
        guard let p = pct else { return 0.0 }
        return Double(p) / 100.0
    }

    private var displayColor: Color {
        guard let p = pct else { return Color.white.opacity(0.2) }
        if p >= 85 { return PresenceTheme.greenAccent }
        if p >= 75 { return tintColor }
        if p >= 65 { return PresenceTheme.orangeAccent }
        return PresenceTheme.redAccent
    }

    public var body: some View {
        ZStack {
            // Track circle (visible subtle track in dark mode)
            Circle()
                .stroke(
                    Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )

            // Active progress circle
            if pct != nil {
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        displayColor,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
            }

            // Centered percentage or dash
            if let p = pct {
                HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                    Text("\(p)")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(PresenceTheme.textPrimary)

                    if showPercentSymbol {
                        Text("%")
                            .font(.system(size: size * 0.15, weight: .semibold, design: .rounded))
                            .foregroundStyle(PresenceTheme.textSecondary)
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: size * 0.32, weight: .medium, design: .rounded))
                    .foregroundStyle(PresenceTheme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pct != nil ? "Attendance: \(pct!) percent" : "No attendance recorded")
    }
}
