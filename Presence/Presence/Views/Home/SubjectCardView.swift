import SwiftUI

public struct SubjectCardView: View {
    @Environment(AppState.self) private var appState

    public let subject: Subject
    public let stats: SubjectStats
    public let nextClass: NextClassResult
    public let todayItem: DayClassItem?
    public var namespace: Namespace.ID?
    public let onTap: () -> Void

    public init(
        subject: Subject,
        stats: SubjectStats,
        nextClass: NextClassResult,
        todayItem: DayClassItem?,
        namespace: Namespace.ID? = nil,
        onTap: @escaping () -> Void
    ) {
        self.subject = subject
        self.stats = stats
        self.nextClass = nextClass
        self.todayItem = todayItem
        self.namespace = namespace
        self.onTap = onTap
    }

    private var isCancelled: Bool {
        todayItem?.occurrence.state == .cancelled
    }

    private var todayStatusText: String {
        if isCancelled {
            return "Cancelled"
        }
        if let status = todayItem?.attendanceRecord?.status {
            return status == .present ? "Present" : "Missed"
        }
        if todayItem?.isOngoing == true {
            return "Live"
        }
        if todayItem?.isUpcoming == true {
            return TimetableEngine.formatTime12Hour(from: todayItem!.occurrence.startTime)
        }
        if todayItem != nil {
            return "Today"
        }
        return "No class"
    }

    private var todayStatusBackground: Color {
        if isCancelled {
            return PresenceTheme.orangeAccent.opacity(0.18)
        }
        if let status = todayItem?.attendanceRecord?.status {
            return status == .present ? PresenceTheme.greenAccent.opacity(0.22) : PresenceTheme.redAccent.opacity(0.22)
        }
        if todayItem != nil {
            return Color(hex: subject.tint).opacity(0.18)
        }
        return appState.secondaryCardBackground
    }

    private var todayStatusForeground: Color {
        if isCancelled {
            return PresenceTheme.orangeAccent
        }
        if let status = todayItem?.attendanceRecord?.status {
            return status == .present ? PresenceTheme.greenAccent : PresenceTheme.redAccent
        }
        if todayItem != nil {
            return Color(hex: subject.tint)
        }
        return appState.textMuted
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Top row: Accent dot on left, compact attendance ring on right
                HStack(alignment: .top) {
                    Circle()
                        .fill(Color(hex: subject.tint))
                        .frame(width: 9, height: 9)
                        .shadow(color: Color(hex: subject.tint).opacity(0.8), radius: 6)
                        .padding(.top, 4)

                    Spacer()

                    AttendanceRingView(
                        pct: stats.pct,
                        tintColor: Color(hex: subject.tint),
                        size: 38,
                        strokeWidth: 3.5,
                        showPercentSymbol: false
                    )
                }

                Spacer(minLength: 12)

                // Middle: Full Subject Name & Lecturer
                VStack(alignment: .leading, spacing: 3) {
                    Text(subject.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let lecturer = subject.lecturer, !lecturer.isEmpty {
                        Text(lecturer)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(appState.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 14)

                // Bottom row: Next schedule & Today status pill
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .background(appState.cardBorder)
                        .padding(.bottom, 2)

                    HStack(alignment: .bottom, spacing: 4) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("NEXT")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(0.6)
                                .foregroundStyle(appState.textMuted)

                            Text(nextClass.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(appState.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if todayItem != nil {
                            Text(todayStatusText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(todayStatusForeground)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(todayStatusBackground, in: Capsule())
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(14)
            .frame(minHeight: 160)
            .presenceCard(cornerRadius: 24, useGlass: false)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subject.name), Attendance: \(stats.pct.map { "\($0) percent" } ?? "No classes yet"), Next class: \(nextClass.label)")
        .accessibilityHint("Double tap to view subject details and attendance history")
    }
}
