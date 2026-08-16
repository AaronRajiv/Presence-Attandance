import SwiftUI
import SwiftData

public struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(AppState.self) private var appState

    @Query(sort: \Subject.createdAt, order: .forward) private var subjects: [Subject]
    @Query private var schedules: [ClassSchedule]
    @Query private var occurrences: [ClassOccurrence]
    @Query private var attendanceRecords: [AttendanceRecord]
    @Query private var semesters: [Semester]
    @Query private var userPreferences: [UserPreferences]
    @Query private var dayExceptions: [AcademicDayException]

    @State private var selectedSubject: Subject?
    @State private var showingAddSubjectSheet = false
    @State private var showingDayExceptionSheet = false
    @State private var undoMessage: String?

    @Namespace private var morphNamespace

    private var activeSemester: Semester? {
        semesters.first
    }

    private var targetAttendance: Int {
        userPreferences.first?.targetAttendance ?? 75
    }

    private var attendanceService: AttendanceService {
        AttendanceService(context: modelContext)
    }

    private var todayIso: String {
        TimetableEngine.formatISODate(Date())
    }

    private var todayException: AcademicDayException? {
        dayExceptions.first { $0.date == todayIso }
    }

    private var liveStatus: LiveDayStatus {
        TimetableEngine.getLiveDayStatus(
            subjects: subjects,
            schedules: schedules,
            occurrences: occurrences,
            attendanceRecords: attendanceRecords,
            semester: activeSemester
        )
    }

    private var formattedCurrentDate: (dayName: String, dateFormatted: String) {
        let now = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d"

        return (dayFormatter.string(from: now).uppercased(), dateFormatter.string(from: now))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                appState.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. Contextual Header: Date & Actions
                        headerSection

                        // 2. Contextual Class Bar
                        ContextualClassBar(
                            liveStatus: liveStatus,
                            onSelectSubject: { subject in
                                openSubject(subject)
                            },
                            onMarkAttendance: { item, status in
                                markQuickAttendance(item, status: status)
                            }
                        )

                        // 3. Subject Cards Two-Column Grid or Empty State
                        if subjects.isEmpty {
                            emptySubjectsView
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(subjects) { subject in
                                    let subOccs = occurrences.filter { $0.subject?.id == subject.id }
                                    let subRecords = attendanceRecords.filter { rec in
                                        rec.occurrence != nil && subOccs.contains(where: { $0.id == rec.occurrence!.id })
                                    }
                                    let stats = StatsEngine.calculateSubjectStats(
                                        subjectId: subject.id,
                                        occurrences: subOccs,
                                        attendanceRecords: subRecords,
                                        schedules: schedules,
                                        dayExceptions: dayExceptions,
                                        semester: activeSemester,
                                        target: targetAttendance
                                    )
                                    let nextClass = TimetableEngine.getNextClassForSubject(
                                        subject: subject,
                                        schedules: schedules,
                                        semester: activeSemester,
                                        occurrences: subOccs
                                    )
                                    let todayItem = liveStatus.todayClasses.first { $0.subject.id == subject.id }

                                    SubjectCardView(
                                        subject: subject,
                                        stats: stats,
                                        nextClass: nextClass,
                                        todayItem: todayItem,
                                        namespace: morphNamespace,
                                        onTap: {
                                            openSubject(subject)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }

                // Floating Undo Toast
                if let message = undoMessage {
                    UndoBannerView(
                        message: message,
                        onUndo: {
                            performUndo()
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                undoMessage = nil
                            }
                        }
                    )
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSubjectSheet) {
                SubjectFormView(mode: .create) {
                    showingAddSubjectSheet = false
                }
            }
            .sheet(isPresented: $showingDayExceptionSheet) {
                DayExceptionSheet(
                    dateIso: todayIso,
                    service: attendanceService,
                    currentException: todayException,
                    onUpdated: {}
                )
            }
            .sheet(item: $selectedSubject) { subject in
                SubjectDetailView(
                    subject: subject,
                    service: attendanceService,
                    semester: activeSemester,
                    userTarget: targetAttendance,
                    onClose: {
                        closeSubject()
                    },
                    onTriggerUndo: { msg in
                        triggerUndoBanner(msg)
                    }
                )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedCurrentDate.dayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(appState.activeAccent)

                Text(formattedCurrentDate.dateFormatted)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                // Day Exception Shortcut Button
                Button {
                    HapticFeedback.light()
                    showingDayExceptionSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: todayException?.type.icon ?? "calendar.badge.clock")
                            .font(.system(size: 11, weight: .bold))
                        Text(todayException?.type.title ?? "Day")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(todayException != nil ? exceptionColor(todayException!.type) : appState.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(todayException != nil ? exceptionColor(todayException!.type).opacity(0.18) : appState.cardBackground, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(appState.cardBorder, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todayException != nil ? "Today marked as \(todayException!.type.title)" : "Mark Day Exception")
                .accessibilityHint("Double tap to mark today as a Holiday, Personal Leave, or CIE Exam Day")

                // Add Subject Action Button
                Button {
                    HapticFeedback.light()
                    showingAddSubjectSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Subject")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(appState.activeAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(appState.cardBackground, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(appState.cardBorder, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add New Subject")
                .accessibilityHint("Double tap to create a new subject and configure its weekly timetable")
            }
        }
        .padding(.top, 4)
    }

    private func exceptionColor(_ type: DayExceptionType) -> Color {
        switch type {
        case .holiday: return PresenceTheme.purpleAccent
        case .leave: return PresenceTheme.orangeAccent
        case .cie: return PresenceTheme.tealAccent
        }
    }

    // MARK: - Empty State

    private var emptySubjectsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 44))
                .foregroundStyle(appState.textMuted.opacity(0.6))
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("No Subjects Yet")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(appState.textPrimary)

                Text("Add your subjects and weekly class timetable to begin tracking your attendance.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(appState.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button {
                HapticFeedback.light()
                showingAddSubjectSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add Your First Subject")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(appState.activeAccent, in: Capsule())
                .shadow(color: appState.activeAccent.opacity(0.4), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .presenceCard(cornerRadius: 24, useGlass: false)
    }

    // MARK: - Navigation & Action Handlers

    private func openSubject(_ subject: Subject) {
        HapticFeedback.light()
        selectedSubject = subject
    }

    private func closeSubject() {
        selectedSubject = nil
    }

    private func markQuickAttendance(_ item: DayClassItem, status: AttendanceStatus) {
        do {
            try attendanceService.markOccurrenceAttendance(item: item, status: status)
            triggerUndoBanner("Marked \(item.subject.shortName) as \(status.rawValue.capitalized)")
        } catch {
            print("Failed to mark quick attendance: \(error)")
        }
    }

    private func triggerUndoBanner(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            undoMessage = text
        }
    }

    private func performUndo() {
        do {
            let restored = try attendanceService.undoLastAction()
            if restored {
                HapticFeedback.success()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    undoMessage = nil
                }
            }
        } catch {
            print("Undo failed: \(error)")
        }
    }
}
