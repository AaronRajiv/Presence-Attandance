import SwiftUI
import SwiftData

public struct SubjectFormView: View {
    public enum Mode {
        case create
        case edit(Subject)
    }

    public let mode: Mode
    public let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var name: String = ""
    @State private var shortName: String = ""
    @State private var courseCode: String = ""
    @State private var lecturer: String = ""
    @State private var room: String = ""
    @State private var tint: String = "#0A84FF"
    @State private var slots: [ScheduleSlotDraft] = []

    private let availableColors = [
        "#0A84FF", // Blue
        "#5E5CE6", // Indigo
        "#BF5AF2", // Purple
        "#FF375F", // Pink
        "#FF9F0A", // Orange
        "#30D158", // Green
        "#64D2FF", // Teal
        "#FFD60A"  // Yellow
    ]

    public struct ScheduleSlotDraft: Identifiable, Equatable {
        public var id: UUID = UUID()
        public var weekday: Int
        public var startDate: Date
        public var endDate: Date
        public var room: String

        public init(
            id: UUID = UUID(),
            weekday: Int = 1,
            startDate: Date = TimetableEngine.dateFromTime24("09:00"),
            endDate: Date = TimetableEngine.dateFromTime24("10:00"),
            room: String = ""
        ) {
            self.id = id
            self.weekday = weekday
            self.startDate = startDate
            self.endDate = endDate
            self.room = room
        }

        public var startTime24: String {
            TimetableEngine.formatTime24Hour(from: startDate)
        }

        public var endTime24: String {
            TimetableEngine.formatTime24Hour(from: endDate)
        }
    }

    public init(mode: Mode = .create, onDismiss: @escaping () -> Void) {
        self.mode = mode
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Subject Details") {
                    TextField("Full Name (e.g. Compiler Design)", text: $name)
                    TextField("Short Name (e.g. Compiler)", text: $shortName)
                    TextField("Course Code (e.g. 21CS71)", text: $courseCode)
                    TextField("Lecturer (e.g. Dr. Aravind Menon)", text: $lecturer)
                    TextField("Default Room (e.g. Block C · 402)", text: $room)
                }

                Section("Accent Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(availableColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: tint == colorHex ? 2.5 : 0)
                                        .padding(-2)
                                    )
                                .onTapGesture {
                                    HapticFeedback.light()
                                    tint = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Recurring Timetable Slots
                Section {
                    ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Slot \(index + 1)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(appState.activeAccent)

                                Spacer()

                                Picker("", selection: bindingForWeekday(at: index)) {
                                    ForEach(0..<7) { idx in
                                        Text(TimetableEngine.dayNames[idx]).tag(idx)
                                    }
                                }
                                .pickerStyle(.menu)

                                if slots.count > 1 {
                                    Button(role: .destructive) {
                                        HapticFeedback.light()
                                        slots.remove(at: index)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(PresenceTheme.redAccent)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 6)
                                }
                            }

                            // Native Time Pickers
                            HStack {
                                Text("Start Time")
                                    .font(.subheadline)
                                Spacer()
                                DatePicker("", selection: bindingForStartDate(at: index), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }

                            HStack {
                                Text("End Time")
                                    .font(.subheadline)
                                Spacer()
                                DatePicker("", selection: bindingForEndDate(at: index), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }

                            HStack {
                                Text("Room")
                                    .font(.subheadline)
                                Spacer()
                                TextField("Default: \(room.isEmpty ? "None" : room)", text: bindingForRoom(at: index))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Explicit Add Slot Button
                    Button {
                        HapticFeedback.light()
                        let nextWeekday = slots.isEmpty ? 1 : ((slots.last!.weekday + 2) % 7)
                        slots.append(ScheduleSlotDraft(
                            id: UUID(),
                            weekday: nextWeekday,
                            startDate: TimetableEngine.dateFromTime24("09:00"),
                            endDate: TimetableEngine.dateFromTime24("10:00"),
                            room: room
                        ))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Add Another Time Slot")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(appState.activeAccent)
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Weekly Class Timetable (\(slots.count) \(slots.count == 1 ? "Slot" : "Slots"))")
                } footer: {
                    Text("Add multiple recurring timetable slots for this subject (e.g. Mon 10:00 AM, Wed 2:00 PM, Fri 9:00 AM).")
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSubject()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                populateInitialData()
            }
        }
    }

    // MARK: - Bindings Helpers for Indexed Mutation

    private func bindingForWeekday(at index: Int) -> Binding<Int> {
        Binding(
            get: { slots.indices.contains(index) ? slots[index].weekday : 1 },
            set: { if slots.indices.contains(index) { slots[index].weekday = $0 } }
        )
    }

    private func bindingForStartDate(at index: Int) -> Binding<Date> {
        Binding(
            get: { slots.indices.contains(index) ? slots[index].startDate : Date() },
            set: { if slots.indices.contains(index) { slots[index].startDate = $0 } }
        )
    }

    private func bindingForEndDate(at index: Int) -> Binding<Date> {
        Binding(
            get: { slots.indices.contains(index) ? slots[index].endDate : Date() },
            set: { if slots.indices.contains(index) { slots[index].endDate = $0 } }
        )
    }

    private func bindingForRoom(at index: Int) -> Binding<String> {
        Binding(
            get: { slots.indices.contains(index) ? slots[index].room : "" },
            set: { if slots.indices.contains(index) { slots[index].room = $0 } }
        )
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "Add Subject"
        case .edit: return "Edit Subject"
        }
    }

    private func populateInitialData() {
        switch mode {
        case .create:
            if slots.isEmpty {
                slots = [
                    ScheduleSlotDraft(
                        id: UUID(),
                        weekday: 1, // Monday
                        startDate: TimetableEngine.dateFromTime24("09:00"),
                        endDate: TimetableEngine.dateFromTime24("10:00"),
                        room: room
                    )
                ]
            }
        case let .edit(subject):
            name = subject.name
            shortName = subject.shortName
            courseCode = subject.courseCode ?? ""
            lecturer = subject.lecturer ?? ""
            room = subject.room ?? ""
            tint = subject.tint

            if let schedules = subject.schedules, !schedules.isEmpty {
                slots = schedules.map { sch in
                    ScheduleSlotDraft(
                        id: UUID(),
                        weekday: sch.weekday,
                        startDate: TimetableEngine.dateFromTime24(sch.startTime),
                        endDate: TimetableEngine.dateFromTime24(sch.endTime),
                        room: sch.room ?? ""
                    )
                }
            } else {
                slots = [
                    ScheduleSlotDraft(
                        id: UUID(),
                        weekday: 1,
                        startDate: TimetableEngine.dateFromTime24("09:00"),
                        endDate: TimetableEngine.dateFromTime24("10:00"),
                        room: room
                    )
                ]
            }
        }
    }

    private func saveSubject() {
        HapticFeedback.medium()
        let resolvedShortName = shortName.trimmingCharacters(in: .whitespaces).isEmpty ? name : shortName

        switch mode {
        case .create:
            let newSubject = Subject(
                name: name.trimmingCharacters(in: .whitespaces),
                shortName: resolvedShortName.trimmingCharacters(in: .whitespaces),
                courseCode: courseCode.isEmpty ? nil : courseCode,
                lecturer: lecturer.isEmpty ? nil : lecturer,
                room: room.isEmpty ? nil : room,
                tint: tint
            )
            modelContext.insert(newSubject)
            newSubject.schedules = []

            for draft in slots {
                let sch = ClassSchedule(
                    subject: newSubject,
                    weekday: draft.weekday,
                    startTime: draft.startTime24,
                    endTime: draft.endTime24,
                    room: draft.room.isEmpty ? (room.isEmpty ? nil : room) : draft.room
                )
                newSubject.schedules?.append(sch)
                modelContext.insert(sch)
            }

        case let .edit(subject):
            subject.name = name.trimmingCharacters(in: .whitespaces)
            subject.shortName = resolvedShortName.trimmingCharacters(in: .whitespaces)
            subject.courseCode = courseCode.isEmpty ? nil : courseCode
            subject.lecturer = lecturer.isEmpty ? nil : lecturer
            subject.room = room.isEmpty ? nil : room
            subject.tint = tint
            subject.updatedAt = Date()

            // Remove previous schedules and add new ones (preserving historical occurrences)
            if let existingSchedules = subject.schedules {
                for sch in existingSchedules {
                    sch.active = false
                    sch.subject = nil
                    modelContext.delete(sch)
                }
            }
            subject.schedules?.removeAll()
            subject.schedules = []

            for draft in slots {
                let sch = ClassSchedule(
                    subject: subject,
                    weekday: draft.weekday,
                    startTime: draft.startTime24,
                    endTime: draft.endTime24,
                    room: draft.room.isEmpty ? (room.isEmpty ? nil : room) : draft.room
                )
                subject.schedules?.append(sch)
                modelContext.insert(sch)
            }
        }

        try? modelContext.save()
        onDismiss()
    }
}
