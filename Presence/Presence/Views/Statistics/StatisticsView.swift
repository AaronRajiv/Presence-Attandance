import SwiftUI
import SwiftData

public struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Subject.createdAt, order: .forward) private var subjects: [Subject]
    @Query private var schedules: [ClassSchedule]
    @Query private var occurrences: [ClassOccurrence]
    @Query private var attendanceRecords: [AttendanceRecord]
    @Query private var semesters: [Semester]
    @Query private var userPreferences: [UserPreferences]
    @Query private var dayExceptions: [AcademicDayException]

    @State private var selectedSubjectId: String? = nil // nil = Overall
    @State private var targetGoal: Int = 75

    private var activeSemester: Semester? {
        semesters.first
    }

    private var userPref: UserPreferences? {
        userPreferences.first
    }

    private var selectedSubject: Subject? {
        guard let id = selectedSubjectId else { return nil }
        return subjects.first { $0.id == id }
    }

    private var currentStats: (pct: Int?, totalConducted: Int, present: Int, missed: Int, bunkBuffer: Int, catchUpNeeded: Int, projectedPct: Int?, tint: Color) {
        if let sub = selectedSubject {
            let subOccs = occurrences.filter { $0.subject?.id == sub.id }
            let subStats = StatsEngine.calculateSubjectStats(
                subjectId: sub.id,
                occurrences: subOccs,
                attendanceRecords: attendanceRecords,
                schedules: schedules,
                dayExceptions: dayExceptions,
                semester: activeSemester,
                target: targetGoal
            )
            return (
                pct: subStats.pct,
                totalConducted: subStats.totalConducted,
                present: subStats.present,
                missed: subStats.missed,
                bunkBuffer: subStats.bunkBuffer,
                catchUpNeeded: subStats.catchUpNeeded,
                projectedPct: subStats.projectedPct,
                tint: Color(hex: sub.tint)
            )
        } else {
            let overall = StatsEngine.calculateOverallStats(
                subjects: subjects,
                occurrences: occurrences,
                attendanceRecords: attendanceRecords,
                schedules: schedules,
                dayExceptions: dayExceptions,
                semester: activeSemester,
                target: targetGoal
            )
            return (
                pct: overall.pct,
                totalConducted: overall.totalConducted,
                present: overall.present,
                missed: overall.missed,
                bunkBuffer: overall.bunkBuffer,
                catchUpNeeded: overall.catchUpNeeded,
                projectedPct: overall.projectedPct,
                tint: appState.activeAccent
            )
        }
    }

    private var hasData: Bool {
        currentStats.totalConducted > 0
    }

    private var classDayTrends: [WeekdayTrendItem] {
        StatsEngine.calculateAttendanceByClassDay(
            subjectId: selectedSubjectId,
            subjects: subjects,
            schedules: schedules,
            occurrences: occurrences,
            attendanceRecords: attendanceRecords,
            dayExceptions: dayExceptions,
            semester: activeSemester
        )
    }

    private var formattedSemesterDateRange: String? {
        guard let sem = activeSemester else { return nil }
        return TimetableEngine.formatDateRangeHuman(startIso: sem.startDate, endIso: sem.endDate)
    }

    private let targetPresets = [75, 80, 85, 90]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                appState.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        headerSection

                        // Subject Selector (Overall vs Individual Subject)
                        if !subjects.isEmpty {
                            subjectSelectorSection
                        }

                        // 1. Attendance Overview Card
                        attendanceCard

                        // 2. Attendance Goal Segmented Selector
                        attendanceGoalSection

                        // 3. Mathematical Margins Grid (Bunk Buffer & Catch-Up)
                        marginsGrid

                        // 4. Attendance by Class Day Trend
                        attendanceByClassDaySection

                        // 5. Subjects Breakdown Section (only on Overall view)
                        if selectedSubjectId == nil && !subjects.isEmpty {
                            subjectsBreakdownSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if let pref = userPref {
                    targetGoal = pref.targetAttendance
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("ANALYTICS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(appState.activeAccent)

            Text(selectedSubject?.name ?? "Overall Attendance")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(appState.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let dateRange = formattedSemesterDateRange {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Semester · \(dateRange)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(appState.textSecondary)
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Subject Selector

    private var subjectSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "Overall" Pill
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSubjectId = nil
                    }
                } label: {
                    Text("Overall")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedSubjectId == nil ? Color.white : appState.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedSubjectId == nil ? appState.activeAccent : appState.cardBackground,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedSubjectId == nil ? appState.activeAccent : appState.cardBorder, lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)

                // Individual Subjects (handles short and arbitrary long names)
                ForEach(subjects) { sub in
                    let isSelected = selectedSubjectId == sub.id
                    let displayName = sub.shortName.isEmpty ? sub.name : sub.shortName

                    Button {
                        HapticFeedback.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSubjectId = sub.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: sub.tint))
                                .frame(width: 7, height: 7)

                            Text(displayName)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : appState.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color(hex: sub.tint) : appState.cardBackground,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color(hex: sub.tint) : appState.cardBorder, lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 1. Attendance Overview Card

    private var attendanceCard: some View {
        HStack(spacing: 20) {
            AttendanceRingView(
                pct: currentStats.pct,
                tintColor: currentStats.tint,
                size: 80,
                strokeWidth: 8,
                showPercentSymbol: true
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(currentStats.pct != nil ? "\(currentStats.pct!)%" : "—")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(appState.textPrimary)

                    if let pct = currentStats.pct {
                        Text(pct >= targetGoal ? "Above Target" : "Below Target")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(pct >= targetGoal ? PresenceTheme.greenAccent(isDark: appState.isDarkMode) : PresenceTheme.redAccent(isDark: appState.isDarkMode))
                    }
                }

                if hasData {
                    HStack(spacing: 12) {
                        metricItem(label: "Conducted", value: "\(currentStats.totalConducted)", color: appState.textPrimary)
                        metricItem(label: "Present", value: "\(currentStats.present)", color: PresenceTheme.greenAccent(isDark: appState.isDarkMode))
                        metricItem(label: "Missed", value: "\(currentStats.missed)", color: PresenceTheme.redAccent(isDark: appState.isDarkMode))
                    }
                    .padding(.top, 2)
                } else {
                    Text("No attendance data yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appState.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .presenceCard(cornerRadius: 24, useGlass: false)
    }

    private func metricItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(appState.textMuted)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    // MARK: - 2. Attendance Goal Section

    private var attendanceGoalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ATTENDANCE TARGET")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(appState.textMuted)
                Spacer()
                Text("\(targetGoal)% Target")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.activeAccent)
            }

            HStack(spacing: 8) {
                ForEach(targetPresets, id: \.self) { preset in
                    let isSelected = targetGoal == preset
                    Button {
                        HapticFeedback.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            targetGoal = preset
                        }
                    } label: {
                        Text("\(preset)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.white : appState.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                isSelected ? appState.activeAccent : appState.cardBackground,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? appState.activeAccent : appState.cardBorder, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 3. Mathematical Margins Grid

    private var marginsGrid: some View {
        HStack(spacing: 12) {
            // Bunk Buffer Card
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PresenceTheme.greenAccent(isDark: appState.isDarkMode))
                    Text("BUNK BUFFER")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(appState.textMuted)
                }

                if hasData {
                    Text("\(currentStats.bunkBuffer)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(currentStats.bunkBuffer > 0 ? PresenceTheme.greenAccent(isDark: appState.isDarkMode) : appState.textSecondary)

                    Text(currentStats.bunkBuffer > 0 ? "Safe classes to miss" : "No buffer available")
                        .font(.system(size: 11))
                        .foregroundStyle(appState.textSecondary)
                } else {
                    Text("—")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textMuted)

                    Text("No classes logged yet")
                        .font(.system(size: 11))
                        .foregroundStyle(appState.textMuted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presenceCard(cornerRadius: 20, useGlass: false)

            // Catch-Up & Projection Card
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PresenceTheme.orangeAccent(isDark: appState.isDarkMode))
                    Text("CATCH-UP")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(appState.textMuted)
                }

                if hasData {
                    if currentStats.catchUpNeeded > 0 {
                        Text("+\(currentStats.catchUpNeeded)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(PresenceTheme.orangeAccent(isDark: appState.isDarkMode))

                        Text("Classes needed for \(targetGoal)%")
                            .font(.system(size: 11))
                            .foregroundStyle(appState.textSecondary)
                    } else {
                        Text("On Track")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(PresenceTheme.greenAccent(isDark: appState.isDarkMode))
                            .padding(.top, 4)

                        Text("Meeting \(targetGoal)% target")
                            .font(.system(size: 11))
                            .foregroundStyle(appState.textSecondary)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textMuted)

                    Text("No catch-up required yet")
                        .font(.system(size: 11))
                        .foregroundStyle(appState.textMuted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presenceCard(cornerRadius: 20, useGlass: false)
        }
    }

    // MARK: - 4. Attendance by Class Day Section (Trend)

    private var attendanceByClassDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ATTENDANCE BY CLASS DAY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(appState.textMuted)

                Spacer()

                if let sub = selectedSubject {
                    Text(sub.shortName.isEmpty ? sub.name : sub.shortName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: sub.tint))
                } else {
                    Text("All Class Days")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.activeAccent)
                }
            }

            if !classDayTrends.isEmpty {
                VStack(spacing: 12) {
                    ForEach(classDayTrends) { dayItem in
                        HStack(spacing: 12) {
                            Text(dayItem.shortLabel)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(appState.textPrimary)
                                .frame(width: 36, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(appState.secondaryCardBackground)
                                        .frame(height: 10)

                                    if dayItem.totalConducted > 0 {
                                        let ratio = CGFloat(dayItem.present) / CGFloat(dayItem.totalConducted)
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(dayItem.pct >= targetGoal ? PresenceTheme.greenAccent(isDark: appState.isDarkMode) : (dayItem.pct >= targetGoal - 15 ? PresenceTheme.orangeAccent(isDark: appState.isDarkMode) : PresenceTheme.redAccent(isDark: appState.isDarkMode)))
                                            .frame(width: max(geo.size.width * ratio, 8), height: 10)
                                    }
                                }
                            }
                            .frame(height: 10)

                            VStack(alignment: .trailing, spacing: 1) {
                                Text(dayItem.totalConducted > 0 ? "\(dayItem.pct)%" : "—")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(dayItem.totalConducted > 0 ? (dayItem.pct >= targetGoal ? PresenceTheme.greenAccent(isDark: appState.isDarkMode) : PresenceTheme.redAccent(isDark: appState.isDarkMode)) : appState.textMuted)

                                Text("\(dayItem.present)/\(dayItem.totalConducted)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(appState.textSecondary)
                            }
                            .frame(width: 46, alignment: .trailing)
                        }
                    }
                }
                .padding(18)
                .presenceCard(cornerRadius: 24, useGlass: false)
            } else {
                HStack {
                    Text("No scheduled class days configured.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appState.textSecondary)
                    Spacer()
                }
                .padding(16)
                .presenceCard(cornerRadius: 20, useGlass: false)
            }
        }
    }

    // MARK: - 5. Subjects Breakdown Section

    private var subjectsBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBJECT BREAKDOWN")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(appState.textMuted)

            VStack(spacing: 10) {
                ForEach(subjects) { sub in
                    let subOccs = occurrences.filter { $0.subject?.id == sub.id }
                    let subStats = StatsEngine.calculateSubjectStats(
                        subjectId: sub.id,
                        occurrences: subOccs,
                        attendanceRecords: attendanceRecords,
                        schedules: schedules,
                        dayExceptions: dayExceptions,
                        semester: activeSemester,
                        target: targetGoal
                    )

                    Button {
                        HapticFeedback.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSubjectId = sub.id
                        }
                    } label: {
                        HStack(spacing: 12) {
                            AttendanceRingView(
                                pct: subStats.pct,
                                tintColor: Color(hex: sub.tint),
                                size: 40,
                                strokeWidth: 4,
                                showPercentSymbol: false
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(appState.textPrimary)
                                    .lineLimit(1)

                                Text(subStats.totalConducted > 0 ? "\(subStats.present) of \(subStats.totalConducted) classes" : "0 conducted")
                                    .font(.system(size: 12))
                                    .foregroundStyle(appState.textSecondary)
                            }

                            Spacer()

                            if subStats.bunkBuffer > 0 {
                                Text("+\(subStats.bunkBuffer) buffer")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PresenceTheme.greenAccent(isDark: appState.isDarkMode))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PresenceTheme.greenAccent(isDark: appState.isDarkMode).opacity(0.12), in: Capsule())
                            } else if subStats.catchUpNeeded > 0 {
                                Text("+\(subStats.catchUpNeeded) catch-up")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PresenceTheme.orangeAccent(isDark: appState.isDarkMode))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PresenceTheme.orangeAccent(isDark: appState.isDarkMode).opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(14)
                        .presenceCard(cornerRadius: 18, useGlass: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
