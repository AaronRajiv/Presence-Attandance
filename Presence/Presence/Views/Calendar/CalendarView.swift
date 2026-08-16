import SwiftUI
import SwiftData

public struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Subject.createdAt, order: .forward) private var subjects: [Subject]
    @Query private var schedules: [ClassSchedule]
    @Query private var occurrences: [ClassOccurrence]
    @Query private var attendanceRecords: [AttendanceRecord]
    @Query private var semesters: [Semester]
    @Query private var dayExceptions: [AcademicDayException]

    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showingDayExceptionSheet = false

    private var activeSemester: Semester? {
        semesters.first
    }

    private var attendanceService: AttendanceService {
        AttendanceService(context: modelContext)
    }

    private var selectedDateISO: String {
        TimetableEngine.formatISODate(selectedDate)
    }

    private var todayISO: String {
        TimetableEngine.formatISODate(Date())
    }

    private var currentDayException: AcademicDayException? {
        dayExceptions.first { $0.date == selectedDateISO }
    }

    private var dayClasses: [DayClassItem] {
        TimetableEngine.getClassesForDate(
            dateIso: selectedDateISO,
            subjects: subjects,
            schedules: schedules,
            occurrences: occurrences,
            attendanceRecords: attendanceRecords,
            semester: activeSemester,
            currentTime: Date()
        )
    }

    private var formattedCurrentMonthHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var formattedSelectedDateHeader: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        return dateFormatter.string(from: selectedDate)
    }

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    private let calendar = Calendar.current

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                appState.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header
                        headerView

                        // Calendar Card
                        calendarCard

                        // Selected Date Overview & Class List
                        selectedDateSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingDayExceptionSheet) {
                DayExceptionSheet(
                    dateIso: selectedDateISO,
                    service: attendanceService,
                    currentException: currentDayException,
                    onUpdated: {}
                )
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        let yearString = calendar.component(.year, from: currentMonth).description
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthString = monthFormatter.string(from: currentMonth)

        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(yearString)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(appState.activeAccent)

                Text(monthString)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                if selectedDateISO != todayISO {
                    Button {
                        HapticFeedback.light()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentMonth = Date()
                            selectedDate = Date()
                        }
                    } label: {
                        Text("Today")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(appState.activeAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(appState.cardBackground, in: Capsule())
                            .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }

                // Month navigation chevrons
                HStack(spacing: 4) {
                    Button {
                        HapticFeedback.light()
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(appState.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(appState.cardBackground, in: Circle())
                            .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        HapticFeedback.light()
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(appState.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(appState.cardBackground, in: Circle())
                            .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: 12) {
            // Weekday Row
            HStack {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(appState.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            // Month Days Grid with stable unique IDs
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(monthDaysGrid, id: \.id) { cell in
                    if let d = cell.date, let dayNum = cell.dayNumber, let dIso = cell.dateIso {
                        calendarDayCell(date: d, dayNumber: dayNum, dateIso: dIso)
                    } else {
                        Color.clear
                            .frame(height: 42)
                    }
                }
            }

            Divider()
                .background(appState.cardBorder)
                .padding(.top, 4)

            // Attendance Dots Legend
            HStack(spacing: 14) {
                legendItem(color: PresenceTheme.greenAccent, label: "Present")
                legendItem(color: PresenceTheme.redAccent, label: "Missed")
                legendItem(color: PresenceTheme.purpleAccent, label: "Holiday")
                legendItem(color: PresenceTheme.orangeAccent, label: "Leave")
                legendItem(color: PresenceTheme.tealAccent, label: "CIE")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .presenceCard(cornerRadius: 24, useGlass: false)
    }

    private var monthDaysGrid: [CalendarDayModel] {
        TimetableEngine.generateMonthGrid(for: currentMonth, calendar: calendar)
    }

    private func calendarDayCell(date: Date, dayNumber: Int, dateIso: String) -> some View {
        let isSelected = (dateIso == selectedDateISO)
        let isToday = (dateIso == todayISO)
        let dayExc = dayExceptions.first { $0.date == dateIso }

        let cellClasses = TimetableEngine.getClassesForDate(
            dateIso: dateIso,
            subjects: subjects,
            schedules: schedules,
            occurrences: occurrences,
            attendanceRecords: attendanceRecords,
            semester: activeSemester,
            currentTime: Date()
        )

        let hasPresent = cellClasses.contains { $0.attendanceRecord?.status == .present }
        let hasMissed = cellClasses.contains { $0.attendanceRecord?.status == .missed }
        let hasScheduled = !cellClasses.isEmpty

        return Button {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(appState.activeAccent)
                            .frame(width: 32, height: 32)
                            .shadow(color: appState.activeAccent.opacity(0.35), radius: 6)
                    } else if isToday {
                        Circle()
                            .stroke(appState.activeAccent, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }

                    Text("\(dayNumber)")
                        .font(.system(size: 14, weight: isSelected || isToday ? .bold : (hasScheduled ? .semibold : .regular), design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : (isToday ? appState.activeAccent : (hasScheduled ? appState.textPrimary : appState.textMuted)))
                }

                // Attendance Status Indicators
                if let exc = dayExc {
                    Circle()
                        .fill(exceptionColor(exc.type))
                        .frame(width: 4, height: 4)
                } else {
                    HStack(spacing: 2) {
                        if hasPresent {
                            Circle()
                                .fill(PresenceTheme.greenAccent)
                                .frame(width: 4, height: 4)
                        }
                        if hasMissed {
                            Circle()
                                .fill(PresenceTheme.redAccent)
                                .frame(width: 4, height: 4)
                        }
                        if !hasPresent && !hasMissed && hasScheduled {
                            Circle()
                                .fill(appState.textMuted.opacity(0.6))
                                .frame(width: 3, height: 3)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .frame(height: 42)
        }
        .buttonStyle(.plain)
    }

    private func exceptionColor(_ type: DayExceptionType) -> Color {
        switch type {
        case .holiday: return PresenceTheme.purpleAccent
        case .leave: return PresenceTheme.orangeAccent
        case .cie: return PresenceTheme.tealAccent
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(appState.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - Selected Date Section

    private var selectedDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formattedSelectedDateHeader)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)

                Spacer()

                // Mark / Manage Day Exception Button
                Button {
                    HapticFeedback.light()
                    showingDayExceptionSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: currentDayException?.type.icon ?? "calendar.badge.clock")
                            .font(.system(size: 11, weight: .bold))
                        Text(currentDayException?.type.title ?? "Mark Day")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(currentDayException != nil ? exceptionColor(currentDayException!.type) : appState.activeAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(currentDayException != nil ? exceptionColor(currentDayException!.type).opacity(0.18) : appState.cardBackground, in: Capsule())
                    .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }

            // Exceptions or Class Rows
            if let exc = currentDayException {
                exceptionBannerView(exc)
            } else if dayClasses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundStyle(appState.textMuted.opacity(0.6))
                        .padding(.top, 4)

                    Text("No classes scheduled or logged for this date.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(appState.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .presenceCard(cornerRadius: 22, useGlass: false)
            } else {
                VStack(spacing: 10) {
                    ForEach(dayClasses, id: \.occurrence.id) { item in
                        dayClassRow(item)
                    }
                }
            }
        }
    }

    private func exceptionBannerView(_ exc: AcademicDayException) -> some View {
        VStack(spacing: 8) {
            Image(systemName: exc.type.icon)
                .font(.system(size: 34))
                .foregroundStyle(exceptionColor(exc.type))
                .padding(.top, 6)

            Text(exc.reason ?? exc.type.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(appState.textPrimary)

            Text(descriptionForException(exc.type))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(appState.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .presenceCard(cornerRadius: 22, useGlass: false)
    }

    private func descriptionForException(_ type: DayExceptionType) -> String {
        switch type {
        case .holiday:
            return "Institution-wide holiday. Classes are not conducted and do not count against attendance."
        case .leave:
            return "You were on personal leave for this date. Scheduled classes are marked as absent."
        case .cie:
            return "Internal assessment examination day. Regular timetable classes are suspended."
        }
    }

    private func dayClassRow(_ item: DayClassItem) -> some View {
        let isCancelled = item.occurrence.state == .cancelled
        let status = item.attendanceRecord?.status

        let start12 = TimetableEngine.formatTime12Hour(from: item.occurrence.startTime)
        let end12 = TimetableEngine.formatTime12Hour(from: item.occurrence.endTime)

        return HStack(spacing: 12) {
            // Subject tint vertical indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: item.subject.tint))
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.subject.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(appState.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(start12) – \(end12)")
                    Text("·")
                    Text(item.occurrence.room ?? item.subject.room ?? "Classroom")
                }
                .font(.system(size: 12))
                .foregroundStyle(appState.textSecondary)
            }

            Spacer()

            if isCancelled {
                HStack(spacing: 6) {
                    Text("Cancelled")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(PresenceTheme.orangeAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PresenceTheme.orangeAccent.opacity(0.18), in: Capsule())

                    Button {
                        HapticFeedback.medium()
                        try? attendanceService.uncancelOccurrence(occurrenceId: item.occurrence.id)
                        appState.showUndo(text: "Uncancelled \(item.subject.shortName)")
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(appState.activeAccent)
                            .frame(width: 28, height: 28)
                            .background(appState.cardBackground, in: Circle())
                            .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Non-wrapping Unambiguous Attendance Action Controls
                HStack(spacing: 8) {
                    // 1. Present Button
                    Button {
                        HapticFeedback.success()
                        try? attendanceService.markOccurrenceAttendance(item: item, status: .present)
                        appState.showUndo(text: "Marked \(item.subject.shortName) Present")
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Present")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(status == .present ? Color.white : PresenceTheme.greenAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(status == .present ? PresenceTheme.greenAccent : PresenceTheme.greenAccent.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(status == .present ? PresenceTheme.greenAccent : PresenceTheme.greenAccent.opacity(0.3), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark \(item.subject.name) as Present")
                    .accessibilityHint(status == .present ? "Currently marked Present. Double tap to re-confirm." : "Double tap to mark as Present.")

                    // 2. Missed Button
                    Button {
                        HapticFeedback.warning()
                        try? attendanceService.markOccurrenceAttendance(item: item, status: .missed)
                        appState.showUndo(text: "Marked \(item.subject.shortName) Missed")
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Missed")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(status == .missed ? Color.white : PresenceTheme.redAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(status == .missed ? PresenceTheme.redAccent : PresenceTheme.redAccent.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(status == .missed ? PresenceTheme.redAccent : PresenceTheme.redAccent.opacity(0.3), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark \(item.subject.name) as Missed")
                    .accessibilityHint(status == .missed ? "Currently marked Missed. Double tap to re-confirm." : "Double tap to mark as Missed.")
                }
            }
        }
        .padding(14)
        .presenceCard(cornerRadius: 20, useGlass: false)
    }

    // MARK: - Calendar Helpers

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentMonth = newMonth
            }
        }
    }
}
