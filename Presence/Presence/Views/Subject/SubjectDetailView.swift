import SwiftUI
import SwiftData

public struct SubjectDetailView: View {
    public let subject: Subject
    public let service: AttendanceService
    public let semester: Semester?
    public let userTarget: Int
    public let onClose: () -> Void
    public let onTriggerUndo: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @Query private var schedules: [ClassSchedule]
    @Query private var occurrences: [ClassOccurrence]
    @Query private var attendanceRecords: [AttendanceRecord]
    @Query private var dayExceptions: [AcademicDayException]

    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showingEditSheet = false
    @State private var showingExtraClassSheet = false
    @State private var extraClassDefaultStatus: AttendanceStatus = .present
    @State private var showingDeleteConfirmation = false

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var subSchedules: [ClassSchedule] {
        if let direct = subject.schedules, !direct.isEmpty {
            return direct.filter { $0.active }
        }
        return schedules.filter { $0.subject?.id == subject.id && $0.active }
    }

    private var subOccurrences: [ClassOccurrence] {
        occurrences.filter { $0.subject?.id == subject.id }
    }

    private var subRecords: [AttendanceRecord] {
        attendanceRecords.filter { rec in
            rec.occurrence != nil && subOccurrences.contains(where: { $0.id == rec.occurrence!.id })
        }
    }

    private var stats: SubjectStats {
        StatsEngine.calculateSubjectStats(
            subjectId: subject.id,
            occurrences: subOccurrences,
            attendanceRecords: subRecords,
            schedules: schedules,
            dayExceptions: dayExceptions,
            semester: semester,
            target: userTarget
        )
    }

    private var nextClass: NextClassResult {
        TimetableEngine.getNextClassForSubject(
            subject: subject,
            schedules: schedules,
            semester: semester,
            occurrences: subOccurrences
        )
    }

    private var selectedDateISO: String {
        TimetableEngine.formatISODate(selectedDate)
    }

    private var todayDateISO: String {
        TimetableEngine.formatISODate(Date())
    }

    private var isSelectedDateToday: Bool {
        selectedDateISO == todayDateISO
    }

    private var currentDayException: AcademicDayException? {
        dayExceptions.first { $0.date == selectedDateISO }
    }

    private var formattedSelectedHeader: (eyebrow: String, title: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let titleStr = formatter.string(from: selectedDate)
        let eyebrowStr = isSelectedDateToday ? "TODAY" : "SELECTED DATE"
        return (eyebrowStr, titleStr)
    }

    private var formattedCurrentMonthHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    // Classes on selected date for this subject
    private var selectedDayItems: [DayClassItem] {
        let all = TimetableEngine.getClassesForDate(
            dateIso: selectedDateISO,
            subjects: [subject],
            schedules: schedules,
            occurrences: occurrences,
            attendanceRecords: attendanceRecords,
            semester: semester,
            currentTime: Date()
        )
        return all.filter { $0.subject.id == subject.id }
    }

    private var activeItem: DayClassItem? {
        selectedDayItems.first
    }

    private var isCancelled: Bool {
        activeItem?.occurrence.state == .cancelled
    }

    private var currentStatus: AttendanceStatus? {
        activeItem?.attendanceRecord?.status
    }

    // Today item for the info tile
    private var todayClassItem: DayClassItem? {
        let all = TimetableEngine.getClassesForDate(
            dateIso: todayDateISO,
            subjects: [subject],
            schedules: schedules,
            occurrences: occurrences,
            attendanceRecords: attendanceRecords,
            semester: semester,
            currentTime: Date()
        )
        return all.first { $0.subject.id == subject.id }
    }

    private var scheduledWeekdays: Set<Int> {
        Set(subSchedules.map { $0.weekday })
    }

    public init(
        subject: Subject,
        service: AttendanceService,
        semester: Semester?,
        userTarget: Int = 75,
        onClose: @escaping () -> Void,
        onTriggerUndo: @escaping (String) -> Void
    ) {
        self.subject = subject
        self.service = service
        self.semester = semester
        self.userTarget = userTarget
        self.onClose = onClose
        self.onTriggerUndo = onTriggerUndo
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            appState.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Header Bar
                    headerSection

                    // 2. Attendance Summary Card
                    attendanceSummaryCard

                    // 3. Today Info & Room Tiles (2 columns)
                    infoTilesGrid

                    // 4. Weekly Recurring Schedule Section
                    weeklyScheduleSection

                    // 5. Month Calendar Header & Month Navigation
                    calendarHeaderSection

                    // 6. Interactive Month Calendar Card with Attendance Dots
                    monthCalendarCard

                    // 7. Selected Date Context & Action Controls
                    selectedDateActionCard

                    // 8. Delete Subject Option
                    deleteSubjectSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            SubjectFormView(mode: .edit(subject)) {
                showingEditSheet = false
            }
        }
        .sheet(isPresented: $showingExtraClassSheet) {
            AddExtraClassSheet(
                subject: subject,
                service: service,
                onDismiss: {
                    showingExtraClassSheet = false
                },
                onSaved: {
                    showingExtraClassSheet = false
                    onTriggerUndo("Logged extra class")
                }
            )
        }
        .confirmationDialog(
            "Delete Subject",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(subject.name)", role: .destructive) {
                HapticFeedback.warning()
                try? service.deleteSubject(subject: subject)
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all scheduled classes and attendance history for \(subject.name).")
        }
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(subject.shortName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Color(hex: subject.tint))

                    if let code = subject.courseCode, !code.isEmpty {
                        Text(code)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(appState.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(appState.cardBackground, in: Capsule())
                    }
                }

                Text(subject.name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)
                    .lineLimit(2)

                if let lecturer = subject.lecturer, !lecturer.isEmpty {
                    Text(lecturer)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(appState.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Edit Subject Button
                Button {
                    HapticFeedback.light()
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(appState.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(appState.cardBackground, in: Circle())
                        .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                // Close Button
                Button {
                    HapticFeedback.light()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(appState.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(appState.cardBackground, in: Circle())
                        .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 2. Attendance Summary Card

    private var attendanceSummaryCard: some View {
        HStack(spacing: 18) {
            AttendanceRingView(
                pct: stats.pct,
                tintColor: Color(hex: subject.tint),
                size: 80,
                strokeWidth: 8,
                showPercentSymbol: true
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Attended")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appState.textSecondary)
                    Spacer()
                    Text(stats.totalConducted > 0 ? "\(stats.present) of \(stats.totalConducted)" : "0 conducted")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textPrimary)
                }

                HStack {
                    Text("Missed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appState.textSecondary)
                    Spacer()
                    Text("\(stats.missed)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PresenceTheme.redAccent)
                }

                if stats.bunkBuffer > 0 {
                    HStack {
                        Text("Safe bunks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(appState.textSecondary)
                        Spacer()
                        Text("\(stats.bunkBuffer) \(stats.bunkBuffer == 1 ? "class" : "classes")")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PresenceTheme.greenAccent)
                    }
                }

                if stats.catchUpNeeded > 0 {
                    HStack {
                        Text("Needed to target")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(appState.textSecondary)
                        Spacer()
                        Text("+\(stats.catchUpNeeded)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PresenceTheme.orangeAccent)
                    }
                }

                HStack {
                    Text("Next class")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appState.textSecondary)
                    Spacer()
                    Text(nextClass.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(appState.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .presenceCard(cornerRadius: 24, useGlass: false)
    }

    // MARK: - 3. Info Tiles Grid (Today & Room)

    private var infoTilesGrid: some View {
        HStack(spacing: 12) {
            // Today Status Tile
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(appState.activeAccent)
                    Text("Today")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textSecondary)
                }

                Text(todayTileStatusText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presenceCard(cornerRadius: 18, useGlass: false)

            // Room Tile
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(appState.activeAccent)
                    Text("Room")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textSecondary)
                }

                Text(subject.room ?? subSchedules.first?.room ?? "—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presenceCard(cornerRadius: 18, useGlass: false)
        }
    }

    private var todayTileStatusText: String {
        if let exc = dayExceptions.first(where: { $0.date == todayDateISO }) {
            return exc.type.title
        }
        if let item = todayClassItem {
            if item.occurrence.state == .cancelled {
                return "Cancelled"
            }
            if let st = item.attendanceRecord?.status {
                return st.rawValue.capitalized
            }
            return "Class · \(TimetableEngine.formatTime12Hour(from: item.occurrence.startTime))"
        }
        let dayOfWeek = calendar.component(.weekday, from: Date()) - 1
        if scheduledWeekdays.contains(dayOfWeek) {
            let slot = subSchedules.first { $0.weekday == dayOfWeek }
            return "Class · \(slot != nil ? TimetableEngine.formatTime12Hour(from: slot!.startTime) : "")"
        }
        return "No class"
    }

    // MARK: - 4. Weekly Recurring Schedule Section

    private var weeklyScheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(appState.activeAccent)
                    Text("WEEKLY SCHEDULE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(appState.textMuted)
                }

                Spacer()

                Button {
                    HapticFeedback.light()
                    showingEditSheet = true
                } label: {
                    Text("Edit Slots")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(appState.activeAccent)
                }
                .buttonStyle(.plain)
            }

            if subSchedules.isEmpty {
                HStack {
                    Text("No recurring class timings configured.")
                        .font(.system(size: 13))
                        .foregroundStyle(appState.textSecondary)
                    Spacer()
                    Button {
                        HapticFeedback.light()
                        showingEditSheet = true
                    } label: {
                        Text("+ Add Slot")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(appState.activeAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(appState.cardBackground, in: Capsule())
                            .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .presenceCard(cornerRadius: 18, useGlass: false)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(subSchedules) { slot in
                            let start12 = TimetableEngine.formatTime12Hour(from: slot.startTime)
                            let end12 = TimetableEngine.formatTime12Hour(from: slot.endTime)
                            HStack(spacing: 6) {
                                Text(weekdayShort(slot.weekday))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(appState.activeAccent)

                                Text("\(start12)–\(end12)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(appState.textSecondary)

                                if let r = slot.room ?? subject.room, !r.isEmpty {
                                    Text("· \(r)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(appState.textMuted)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(appState.cardBackground, in: Capsule())
                            .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. Calendar Header & Navigation

    private var calendarHeaderSection: some View {
        HStack {
            // Add Extra Class button
            Button {
                HapticFeedback.light()
                extraClassDefaultStatus = .present
                showingExtraClassSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Extra Class")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(appState.activeAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(appState.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
            }
            .buttonStyle(.plain)

            Spacer()

            // Month Navigator chevrons & title
            HStack(spacing: 6) {
                Button {
                    HapticFeedback.light()
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(appState.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(appState.cardBackground, in: Circle())
                        .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                Text(formattedCurrentMonthHeader)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)
                    .frame(minWidth: 100, alignment: .center)

                Button {
                    HapticFeedback.light()
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(appState.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(appState.cardBackground, in: Circle())
                        .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 6. Interactive Month Calendar Card
 
     private var monthCalendarCard: some View {
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

             // Days Grid with stable unique IDs
             LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                 ForEach(monthDaysGrid, id: \.id) { cell in
                     if let d = cell.date, let dayNum = cell.dayNumber, let dIso = cell.dateIso {
                         subjectDayCell(date: d, dayNumber: dayNum, dateIso: dIso)
                     } else {
                         Color.clear
                             .frame(height: 38)
                     }
                 }
             }

             Divider()
                 .background(appState.cardBorder)
                 .padding(.top, 4)

             // Attendance Legend
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

     private func subjectDayCell(date: Date, dayNumber: Int, dateIso: String) -> some View {
         let isSelected = (dateIso == selectedDateISO)
         let isToday = (dateIso == todayDateISO)

         let dayExc = dayExceptions.first { $0.date == dateIso }

         // Find occurrences for this subject and date
         let dateOccurrences = subOccurrences.filter { $0.date == dateIso }
         let hasPresent = dateOccurrences.contains { occ in
             subRecords.first { $0.occurrence?.id == occ.id }?.status == .present
         }
         let hasMissed = dateOccurrences.contains { occ in
             subRecords.first { $0.occurrence?.id == occ.id }?.status == .missed
         }
         let hasCancelled = dateOccurrences.contains { $0.state == .cancelled }

         let weekdayIndex = calendar.component(.weekday, from: date) - 1
         let isScheduled = scheduledWeekdays.contains(weekdayIndex)

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
                         .font(.system(size: 14, weight: isSelected || isToday ? .bold : (isScheduled ? .semibold : .regular), design: .rounded))
                         .foregroundStyle(isSelected ? Color.white : (isToday ? appState.activeAccent : (isScheduled ? appState.textPrimary : appState.textMuted)))
                 }

                 // Attendance Status Dots
                 if let exc = dayExc {
                     Circle()
                         .fill(exceptionColor(exc.type))
                         .frame(width: 4, height: 4)
                 } else {
                     HStack(spacing: 2) {
                         if hasCancelled {
                             Circle()
                                 .fill(PresenceTheme.orangeAccent)
                                 .frame(width: 4, height: 4)
                         } else if hasPresent {
                             Circle()
                                 .fill(PresenceTheme.greenAccent)
                                 .frame(width: 4, height: 4)
                         } else if hasMissed {
                             Circle()
                                 .fill(PresenceTheme.redAccent)
                                 .frame(width: 4, height: 4)
                         } else {
                             Spacer().frame(height: 4)
                         }
                     }
                 }
             }
             .frame(height: 40)
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
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(appState.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - 7. Selected Date Action Card

    private var selectedDateActionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Selected Date Heading
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedSelectedHeader.eyebrow)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(appState.activeAccent)
                    Text(formattedSelectedHeader.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textPrimary)
                }

                Spacer()

                if let exc = currentDayException {
                    Text(exc.type.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(exceptionColor(exc.type))
                } else if let item = activeItem {
                    let s12 = TimetableEngine.formatTime12Hour(from: item.occurrence.startTime)
                    let e12 = TimetableEngine.formatTime12Hour(from: item.occurrence.endTime)
                    Text("\(s12)–\(e12)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(appState.textSecondary)
                } else {
                    Text("No class scheduled")
                        .font(.system(size: 12))
                        .foregroundStyle(appState.textMuted)
                }
            }

            if let exc = currentDayException {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exc.reason ?? exc.type.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(exceptionColor(exc.type))
                        Text(excDescription(exc.type))
                            .font(.system(size: 11))
                            .foregroundStyle(appState.textSecondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(exceptionColor(exc.type).opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if isCancelled {
                // Cancelled banner with restore button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Class Cancelled")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PresenceTheme.orangeAccent)
                        Text("Excluded from attendance calculations")
                            .font(.system(size: 11))
                            .foregroundStyle(appState.textSecondary)
                    }

                    Spacer()

                    Button {
                        HapticFeedback.medium()
                        if let item = activeItem {
                            try? service.uncancelOccurrence(occurrenceId: item.occurrence.id)
                            onTriggerUndo("Restored class")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Restore")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.activeAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(appState.cardBackground, in: Capsule())
                        .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(PresenceTheme.orangeAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                // Non-wrapping Present / Missed Action Controls
                HStack(spacing: 12) {
                    // Present Button
                    Button {
                        markAttendance(.present)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: currentStatus == .present ? "checkmark.circle.fill" : "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Present")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .lineLimit(1)
                        .foregroundStyle(currentStatus == .present ? Color.white : PresenceTheme.greenAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(currentStatus == .present ? PresenceTheme.greenAccent : PresenceTheme.greenAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(currentStatus == .present ? PresenceTheme.greenAccent : PresenceTheme.greenAccent.opacity(0.3), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)

                    // Missed Button
                    Button {
                        markAttendance(.missed)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: currentStatus == .missed ? "xmark.circle.fill" : "xmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("Missed")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .lineLimit(1)
                        .foregroundStyle(currentStatus == .missed ? Color.white : PresenceTheme.redAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(currentStatus == .missed ? PresenceTheme.redAccent : PresenceTheme.redAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(currentStatus == .missed ? PresenceTheme.redAccent : PresenceTheme.redAccent.opacity(0.3), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // If scheduled active item exists, allow Cancel Class or Clear Attendance
                if let item = activeItem {
                    HStack(spacing: 12) {
                        Button {
                            HapticFeedback.warning()
                            try? service.cancelOccurrence(item: item, reason: "Class Cancelled")
                            onTriggerUndo("Cancelled class")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "slash.circle")
                                Text("Cancel Class")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(appState.textMuted)
                        }
                        .buttonStyle(.plain)

                        if currentStatus != nil {
                            Spacer()

                            Button {
                                HapticFeedback.light()
                                try? service.unmarkOccurrence(occurrenceId: item.occurrence.id)
                                onTriggerUndo("Cleared attendance")
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Clear Attendance")
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(appState.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(18)
        .presenceCard(cornerRadius: 24, useGlass: false)
    }

    private func excDescription(_ type: DayExceptionType) -> String {
        switch type {
        case .holiday: return "College holiday: classes excluded from attendance calculations."
        case .leave: return "Personal leave applied across all classes for this date."
        case .cie: return "CIE examination day: regular classes do not run."
        }
    }

    private func markAttendance(_ status: AttendanceStatus) {
        HapticFeedback.success()
        if let item = activeItem {
            try? service.markOccurrenceAttendance(item: item, status: status)
            onTriggerUndo("Marked \(status.rawValue.capitalized)")
        } else {
            // Prompt extra class sheet prefilled with this status and date
            extraClassDefaultStatus = status
            showingExtraClassSheet = true
        }
    }

    // MARK: - 8. Delete Subject Section

    private var deleteSubjectSection: some View {
        Button(role: .destructive) {
            HapticFeedback.warning()
            showingDeleteConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                Text("Delete Subject")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(PresenceTheme.redAccent.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(appState.secondaryCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(appState.cardBorder, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentMonth = newMonth
            }
        }
    }

    private func weekdayShort(_ day: Int) -> String {
        switch day {
        case 0: return "Sun"
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        default: return "Day \(day)"
        }
    }
}
