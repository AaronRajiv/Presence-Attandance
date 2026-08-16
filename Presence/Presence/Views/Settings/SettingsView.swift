import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query private var userPreferences: [UserPreferences]
    @Query(sort: \Subject.createdAt, order: .forward) private var subjects: [Subject]
    @Query private var semesters: [Semester]

    @State private var showingAddSubjectSheet = false
    @State private var subjectToEdit: Subject?
    @State private var showingTermEditSheet = false
    @State private var showingResetAlert = false
    @State private var showingExportShare = false
    @State private var exportData: String?
    @State private var isDarkMode = true
    @State private var selectedAccent = "#0A84FF"
    @State private var icloudSync = true
    @State private var classNotifications = true
    @State private var reminderTime = 10
    @State private var syncMonitor = ICloudSyncMonitor.shared

    private var activeSemester: Semester? {
        semesters.first
    }

    private var userPref: UserPreferences? {
        userPreferences.first
    }

    private var attendanceService: AttendanceService {
        AttendanceService(context: modelContext)
    }

    private let accentColors = [
        "#0A84FF", // Blue
        "#5E5CE6", // Indigo
        "#64D2FF", // Cyan
        "#30D158", // Green
        "#FF9F0A", // Orange
        "#FF375F", // Pink
        "#BF5AF2"  // Purple
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                appState.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Header
                        headerSection

                        // 1. Appearance Section
                        appearanceSection

                        // 2. Sync & Reminders Section
                        syncAndRemindersSection

                        // 3. Academic Term & Boundaries Section
                        academicTermSection

                        // 4. Subjects & Timetable Section
                        subjectsSection

                        // 5. Data & Privacy Section
                        dataAndPrivacySection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSubjectSheet) {
                SubjectFormView(mode: .create) {
                    showingAddSubjectSheet = false
                }
            }
            .sheet(item: $subjectToEdit) { subject in
                SubjectFormView(mode: .edit(subject)) {
                    subjectToEdit = nil
                }
            }
            .sheet(isPresented: $showingTermEditSheet) {
                SemesterFormSheet(semester: activeSemester) {
                    showingTermEditSheet = false
                }
            }
            .confirmationDialog(
                "Reset All Records",
                isPresented: $showingResetAlert,
                titleVisibility: .visible
            ) {
                Button("Reset All Attendance Records", role: .destructive) {
                    HapticFeedback.warning()
                    resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all attendance logs, occurrences, and history while preserving your configured subjects.")
            }
            .onAppear {
                selectedAccent = appState.accentHex
                isDarkMode = appState.isDarkMode
                if let pref = userPref {
                    reminderTime = pref.reminderMinutes
                    icloudSync = pref.iCloudSyncEnabled
                    classNotifications = pref.notificationsEnabled
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PREFERENCES & DATA")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(appState.activeAccent)

            Text("Settings")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(appState.textPrimary)
        }
        .padding(.top, 4)
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(appState.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 16) {
                // Theme Toggle (Dark / Light) with Real Liquid Glass
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(appState.activeAccent)
                        Text("Theme")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(appState.textPrimary)
                    }

                    Spacer()

                    // Liquid Glass Theme Selector
                    HStack(spacing: 2) {
                        Button {
                            HapticFeedback.light()
                            isDarkMode = true
                            appState.setDarkMode(true)
                            updateAppearancePreference("dark")
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 11))
                                Text("Dark")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(isDarkMode ? appState.activeAccent : appState.textMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                isDarkMode ? appState.activeAccent.opacity(0.18) : Color.clear,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isDarkMode ? appState.activeAccent.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticFeedback.light()
                            isDarkMode = false
                            appState.setDarkMode(false)
                            updateAppearancePreference("light")
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 11))
                                Text("Light")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(!isDarkMode ? appState.activeAccent : appState.textMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                !isDarkMode ? appState.activeAccent.opacity(0.18) : Color.clear,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(!isDarkMode ? appState.activeAccent.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(3)
                    .background(appState.cardBackground, in: Capsule())
                    .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                }

                Divider().background(appState.cardBorder)

                // Accent Color Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accent Color")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(appState.textSecondary)

                    HStack(spacing: 12) {
                        ForEach(PresenceAccentOption.allCases) { opt in
                            let isSelected = appState.activeAccentOption == opt
                            Button {
                                HapticFeedback.light()
                                selectedAccent = opt.hex
                                appState.setAccent(opt.hex)
                                updateAccentPreference(opt.hex)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(opt.color(isDark: appState.isDarkMode))
                                        .frame(width: 28, height: 28)

                                    if isSelected {
                                        Circle()
                                            .stroke(appState.textPrimary, lineWidth: 2.5)
                                            .frame(width: 34, height: 34)
                                    }
                                }
                                .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
            .presenceCard(cornerRadius: 22, useGlass: false)
        }
    }

    // MARK: - Sync & Reminders Section

    private var syncAndRemindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sync & Reminders")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(appState.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 16) {
                // iCloud Sync (Prepared for Apple Developer Configuration)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(appState.textSecondary)
                            Text("iCloud Sync")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(appState.textPrimary)
                        }

                        Spacer()

                        Text("Requires Developer Account")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(appState.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(appState.cardBackground, in: Capsule())
                            .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                    }

                    Text("CloudKit architecture is prepared. Multi-device sync will activate when an Apple Developer Program membership is configured.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(appState.textSecondary)
                        .lineSpacing(2)
                }

                Divider().background(appState.cardBorder)

                // Class Notifications
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(appState.activeAccent)
                        Text("Class Notifications")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(appState.textPrimary)
                    }

                    Spacer()

                    Toggle("", isOn: $classNotifications)
                        .labelsHidden()
                        .tint(appState.activeAccent)
                        .onChange(of: classNotifications) { _, val in
                            updateNotificationsPreference(val)
                        }
                }

                Divider().background(appState.cardBorder)

                // Reminder Time (5m, 10m, 15m, 30m)
                HStack {
                    Text("Reminder Time")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(appState.textPrimary)

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach([5, 10, 15, 30], id: \.self) { mins in
                            let isSelected = reminderTime == mins
                            Button {
                                HapticFeedback.light()
                                reminderTime = mins
                                updateReminderTimePreference(mins)
                            } label: {
                                VStack(spacing: 0) {
                                    Text("\(mins)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                    Text("m")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(isSelected ? Color.white : appState.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(isSelected ? appState.activeAccent : appState.cardBackground, in: Circle())
                                .overlay(Circle().stroke(isSelected ? appState.activeAccent : appState.cardBorder, lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
            .presenceCard(cornerRadius: 22, useGlass: false)
        }
    }

    // MARK: - Academic Term Section

    private var academicTermSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Academic Term & Boundaries")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(appState.textSecondary)
                .padding(.leading, 4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeSemester?.name ?? "Current Semester")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(appState.textPrimary)

                    if let sem = activeSemester {
                        Text("\(sem.startDate) to \(sem.endDate)")
                            .font(.system(size: 13))
                            .foregroundStyle(appState.textSecondary)
                    } else {
                        Text("No active term boundaries set")
                            .font(.system(size: 13))
                            .foregroundStyle(appState.textMuted)
                    }
                }

                Spacer()

                Button {
                    HapticFeedback.light()
                    showingTermEditSheet = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appState.activeAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(appState.cardBackground, in: Capsule())
                        .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .presenceCard(cornerRadius: 22, useGlass: false)
        }
    }

    // MARK: - Subjects Section

    private var subjectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Subjects & Timetable")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(appState.textSecondary)

                Spacer()

                Button {
                    HapticFeedback.light()
                    showingAddSubjectSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add Subject")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(appState.activeAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(appState.cardBackground, in: Capsule())
                    .overlay(Capsule().stroke(appState.cardBorder, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 4)

            VStack(spacing: 12) {
                HStack {
                    Text("\(subjects.count) \(subjects.count == 1 ? "Subject" : "Subjects") Configured")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(appState.textPrimary)
                    Spacer()
                }

                if subjects.isEmpty {
                    Text("No subjects configured yet. Tap + Add Subject to create one.")
                        .font(.system(size: 13))
                        .foregroundStyle(appState.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(subjects) { sub in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: sub.tint))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(appState.textPrimary)

                                    HStack(spacing: 6) {
                                        if let code = sub.courseCode, !code.isEmpty {
                                            Text(code)
                                        }
                                        if let room = sub.room, !room.isEmpty {
                                            Text("· \(room)")
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(appState.textSecondary)
                                }

                                Spacer()

                                Button {
                                    HapticFeedback.light()
                                    subjectToEdit = sub
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(appState.textSecondary)
                                        .frame(width: 28, height: 28)
                                        .background(appState.cardBackground, in: Circle())
                                        .overlay(Circle().stroke(appState.cardBorder, lineWidth: 0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(appState.secondaryCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(appState.cardBorder, lineWidth: 0.8)
                            )
                        }
                    }
                }
            }
            .padding(18)
            .presenceCard(cornerRadius: 22, useGlass: false)
        }
    }

    // MARK: - Data & Privacy Section

    private var dataAndPrivacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data & Privacy")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(appState.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 12) {
                Button {
                    HapticFeedback.light()
                    exportFullBackup()
                } label: {
                    HStack {
                        Label("Export Full Backup (JSON)", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(appState.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(appState.textMuted)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Divider().background(appState.cardBorder)

                Button {
                    HapticFeedback.warning()
                    showingResetAlert = true
                } label: {
                    HStack {
                        Label("Reset All Attendance Records", systemImage: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PresenceTheme.redAccent)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .presenceCard(cornerRadius: 22, useGlass: false)
        }
    }

    // MARK: - Preferences Update Helpers

    private func updateAppearancePreference(_ appearance: String) {
        if let pref = userPref {
            pref.appearance = appearance
            try? modelContext.save()
        }
    }

    private func updateAccentPreference(_ hex: String) {
        if let pref = userPref {
            pref.accentColor = hex
            try? modelContext.save()
        }
    }

    private func updateSyncPreference(_ enabled: Bool) {
        if let pref = userPref {
            pref.iCloudSyncEnabled = enabled
            try? modelContext.save()
        }
    }

    private func updateNotificationsPreference(_ enabled: Bool) {
        if let pref = userPref {
            pref.notificationsEnabled = enabled
            try? modelContext.save()
        }
    }

    private func updateReminderTimePreference(_ minutes: Int) {
        if let pref = userPref {
            pref.reminderMinutes = minutes
            try? modelContext.save()
        }
    }

    private func exportFullBackup() {
        let exportDict: [String: Any] = [
            "version": "2.0.0",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "subjectsCount": subjects.count
        ]
        if let data = try? JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            exportData = str
            showingExportShare = true
        }
    }

    private func resetAllData() {
        try? attendanceService.resetAllAttendanceRecords()
    }
}
