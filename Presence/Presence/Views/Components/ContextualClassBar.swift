import SwiftUI

public struct ContextualClassBar: View {
    public let liveStatus: LiveDayStatus
    public let onSelectSubject: ((Subject) -> Void)?
    public let onMarkAttendance: ((DayClassItem, AttendanceStatus) -> Void)?

    public init(
        liveStatus: LiveDayStatus,
        onSelectSubject: ((Subject) -> Void)? = nil,
        onMarkAttendance: ((DayClassItem, AttendanceStatus) -> Void)? = nil
    ) {
        self.liveStatus = liveStatus
        self.onSelectSubject = onSelectSubject
        self.onMarkAttendance = onMarkAttendance
    }

    public var body: some View {
        Group {
            if let ongoing = liveStatus.ongoing {
                ongoingCard(ongoing)
            } else if let nextToday = liveStatus.nextClassToday {
                upcomingCard(nextToday)
            } else if liveStatus.allConcludedToday {
                concludedCard()
            } else if let nextOverall = liveStatus.nextOverall {
                overallNextCard(nextOverall)
            } else {
                noClassesCard()
            }
        }
        .presenceCard(cornerRadius: 20, useGlass: true)
    }

    @ViewBuilder
    private func ongoingCard(_ item: DayClassItem) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Pulsing live indicator
                ZStack {
                    Circle()
                        .fill(PresenceTheme.blueAccent.opacity(0.3))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(PresenceTheme.blueAccent)
                        .frame(width: 7, height: 7)
                }

                Text("NOW IN SESSION")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PresenceTheme.blueAccent)

                Spacer()

                Text("\(item.occurrence.startTime)–\(item.occurrence.endTime)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PresenceTheme.textSecondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.subject.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PresenceTheme.textPrimary)
                        .lineLimit(1)

                    Text(item.occurrence.room ?? item.subject.room ?? "Classroom")
                        .font(.system(size: 12))
                        .foregroundStyle(PresenceTheme.textSecondary)
                }

                Spacer()

                // Quick Attendance Buttons
                HStack(spacing: 6) {
                    if item.attendanceRecord?.status == .present {
                        Button {
                            HapticFeedback.success()
                            onMarkAttendance?(item, .present)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Present")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(PresenceTheme.greenAccent)
                        .controlSize(.small)
                    } else {
                        Button {
                            HapticFeedback.success()
                            onMarkAttendance?(item, .present)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Present")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .buttonStyle(.glass)
                        .tint(PresenceTheme.greenAccent)
                        .controlSize(.small)
                    }

                    if item.attendanceRecord?.status == .missed {
                        Button {
                            HapticFeedback.warning()
                            onMarkAttendance?(item, .missed)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Missed")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(PresenceTheme.redAccent)
                        .controlSize(.small)
                    } else {
                        Button {
                            HapticFeedback.warning()
                            onMarkAttendance?(item, .missed)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Missed")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .buttonStyle(.glass)
                        .tint(PresenceTheme.redAccent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func upcomingCard(_ item: DayClassItem) -> some View {
        Button {
            onSelectSubject?(item.subject)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(PresenceTheme.blueAccent)

                HStack(spacing: 4) {
                    Text("Next:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PresenceTheme.textPrimary)

                    Text("\(item.subject.shortName) at \(item.occurrence.startTime)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PresenceTheme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Text(item.occurrence.room ?? item.subject.room ?? "—")
                    .font(.system(size: 12))
                    .foregroundStyle(PresenceTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func overallNextCard(_ next: NextOverallClassResult) -> some View {
        Button {
            onSelectSubject?(next.subject)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(PresenceTheme.textSecondary)

                HStack(spacing: 4) {
                    Text("Next:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PresenceTheme.textPrimary)

                    Text("\(next.subject.shortName) · \(next.label)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PresenceTheme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Text(next.room)
                    .font(.system(size: 12))
                    .foregroundStyle(PresenceTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func concludedCard() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(PresenceTheme.blueAccent)

            Text("All scheduled classes concluded for today")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PresenceTheme.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func noClassesCard() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 15))
                .foregroundStyle(PresenceTheme.textMuted)

            Text("No classes scheduled for today")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PresenceTheme.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
