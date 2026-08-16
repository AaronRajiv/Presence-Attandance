import SwiftUI
import SwiftData

public struct DayExceptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query private var dayExceptions: [AcademicDayException]

    public let initialDateIso: String
    public let service: AttendanceService
    public let onUpdated: () -> Void

    @State private var currentMonth: Date
    @State private var selectedDate: Date
    @State private var selectedType: DayExceptionType?
    @State private var reason: String = ""

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    public init(
        dateIso: String,
        service: AttendanceService,
        currentException: AcademicDayException? = nil,
        onUpdated: @escaping () -> Void
    ) {
        self.initialDateIso = dateIso
        self.service = service
        self.onUpdated = onUpdated

        let d = TimetableEngine.parseISODate(dateIso)
        _selectedDate = State(initialValue: d)
        _currentMonth = State(initialValue: d)
        _selectedType = State(initialValue: currentException?.type)
        _reason = State(initialValue: currentException?.reason ?? "")
    }

    private var selectedDateIso: String {
        TimetableEngine.formatISODate(selectedDate)
    }

    private var activeExceptionForSelectedDate: AcademicDayException? {
        dayExceptions.first { $0.date == selectedDateIso }
    }

    private var formattedDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: selectedDate)
    }

    private var formattedCurrentMonthHeader: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: currentMonth)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                appState.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DAY MANAGEMENT")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(appState.activeAccent)

                            Text("Academic Exceptions")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(appState.textPrimary)

                            Text("Configure institution-wide holidays, CIE internal exam days, or personal leave across the calendar.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(appState.textSecondary)
                                .padding(.top, 2)
                        }
                        .padding(16)
                        .presenceCard(cornerRadius: 20, useGlass: false)

                        // 1. Interactive Month Calendar for Date Selection
                        monthCalendarCard

                        // 2. Selected Date Context Banner
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SELECTED DATE")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(1.0)
                                    .foregroundStyle(appState.activeAccent)

                                Text(formattedDateString)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(appState.textPrimary)
                            }

                            Spacer()

                            if let exc = activeExceptionForSelectedDate {
                                Text(exc.type.title)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(typeColor(exc.type))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(typeColor(exc.type).opacity(0.18), in: Capsule())
                            }
                        }
                        .padding(14)
                        .presenceCard(cornerRadius: 18, useGlass: false)

                        // 3. Option Selection Cards (Normal Day, Holiday, Leave, CIE)
                        VStack(spacing: 10) {
                            // Normal Day
                            optionCard(
                                title: "Normal Day",
                                subtitle: "Scheduled timetable classes run as usual.",
                                icon: "calendar",
                                isSelected: selectedType == nil,
                                tint: appState.activeAccent
                            ) {
                                selectedType = nil
                            }

                            // College Holiday
                            optionCard(
                                title: "College Holiday",
                                subtitle: "Institution-wide holiday. Classes are not conducted and excluded from attendance calculation.",
                                icon: "sun.max.fill",
                                isSelected: selectedType == .holiday,
                                tint: PresenceTheme.purpleAccent
                            ) {
                                selectedType = .holiday
                            }

                            // Personal Leave
                            optionCard(
                                title: "Personal Leave",
                                subtitle: "Student-level leave applied across all classes scheduled for this date.",
                                icon: "person.badge.shield.checkmark.fill",
                                isSelected: selectedType == .leave,
                                tint: PresenceTheme.orangeAccent
                            ) {
                                selectedType = .leave
                            }

                            // CIE Exam Day
                            optionCard(
                                title: "CIE Exam Day",
                                subtitle: "Internal assessment examination day. Regular timetable classes do not run.",
                                icon: "doc.text.fill",
                                isSelected: selectedType == .cie,
                                tint: PresenceTheme.tealAccent
                            ) {
                                selectedType = .cie
                            }
                        }

                        // Reason Input if Exception selected
                        if selectedType != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reason (Optional)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(appState.textSecondary)

                                TextField(
                                    placeholderForType(selectedType),
                                    text: $reason
                                )
                                .font(.system(size: 14))
                                .foregroundStyle(appState.textPrimary)
                                .padding(12)
                                .background(appState.secondaryCardBackground, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(appState.cardBorder, lineWidth: 0.8)
                                )
                            }
                            .padding(16)
                            .presenceCard(cornerRadius: 20, useGlass: false)
                        }

                        // Save Action Button
                        Button {
                            HapticFeedback.success()
                            saveException()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Apply Changes")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(appState.activeAccent, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(color: appState.activeAccent.opacity(0.35), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(appState.activeAccent)
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                let iso = TimetableEngine.formatISODate(newDate)
                if let exc = dayExceptions.first(where: { $0.date == iso }) {
                    selectedType = exc.type
                    reason = exc.reason ?? ""
                } else {
                    selectedType = nil
                    reason = ""
                }
            }
        }
    }

    // MARK: - Interactive Calendar Card

    private var monthCalendarCard: some View {
        VStack(spacing: 12) {
            // Month Navigation
            HStack {
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

                Spacer()

                Text(formattedCurrentMonthHeader)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.textPrimary)

                Spacer()

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

            // Weekday Headers
            HStack {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(appState.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            // Days Grid with stable unique IDs
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(monthDaysGrid, id: \.id) { cell in
                    if let d = cell.date, let dayNum = cell.dayNumber, let dIso = cell.dateIso {
                        dayCell(date: d, dayNumber: dayNum, dateIso: dIso)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }

            Divider().background(appState.cardBorder)

            // Legend
            HStack(spacing: 14) {
                legendItem(color: PresenceTheme.purpleAccent, label: "Holiday")
                legendItem(color: PresenceTheme.orangeAccent, label: "Leave")
                legendItem(color: PresenceTheme.tealAccent, label: "CIE Exam")
            }
        }
        .padding(16)
        .presenceCard(cornerRadius: 20, useGlass: false)
    }

    private var monthDaysGrid: [CalendarDayModel] {
        TimetableEngine.generateMonthGrid(for: currentMonth, calendar: calendar)
    }

    private func dayCell(date: Date, dayNumber: Int, dateIso: String) -> some View {
        let isSelected = (dateIso == selectedDateIso)
        let isToday = (dateIso == TimetableEngine.formatISODate(Date()))
        let dayExc = dayExceptions.first { $0.date == dateIso }

        return Button {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = date
                if let exc = dayExc {
                    selectedType = exc.type
                    reason = exc.reason ?? ""
                } else {
                    selectedType = nil
                    reason = ""
                }
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(appState.activeAccent)
                            .frame(width: 28, height: 28)
                    } else if isToday {
                        Circle()
                            .stroke(appState.activeAccent, lineWidth: 1.2)
                            .frame(width: 28, height: 28)
                    }

                    Text("\(dayNumber)")
                        .font(.system(size: 13, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : (isToday ? appState.activeAccent : appState.textPrimary))
                }

                if let exc = dayExc {
                    Circle()
                        .fill(typeColor(exc.type))
                        .frame(width: 4, height: 4)
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(appState.textSecondary)
        }
    }

    // MARK: - Option Card

    private func optionCard(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                action()
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? tint : appState.secondaryCardBackground)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(appState.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(tint)
                }
            }
            .padding(14)
            .background(
                isSelected ? tint.opacity(0.12) : appState.cardBackground,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.4) : appState.cardBorder, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions & Helpers

    private func typeColor(_ type: DayExceptionType) -> Color {
        switch type {
        case .holiday: return PresenceTheme.purpleAccent
        case .leave: return PresenceTheme.orangeAccent
        case .cie: return PresenceTheme.tealAccent
        }
    }

    private func placeholderForType(_ type: DayExceptionType?) -> String {
        switch type {
        case .holiday: return "e.g. Independence Day, College Fest"
        case .leave: return "e.g. Sick Leave, Medical, Personal"
        case .cie: return "e.g. CIE 1 - Compiler Design & Networks"
        case .none: return "e.g. Reason"
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentMonth = newMonth
            }
        }
    }

    private func saveException() {
        do {
            if let type = selectedType {
                try service.setDayException(
                    date: selectedDateIso,
                    type: type,
                    reason: reason.trimmingCharacters(in: .whitespaces).isEmpty ? nil : reason.trimmingCharacters(in: .whitespaces)
                )
            } else {
                try service.removeDayException(date: selectedDateIso)
            }
            onUpdated()
            dismiss()
        } catch {
            print("Failed to save day exception: \(error)")
        }
    }
}
