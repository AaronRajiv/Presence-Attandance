import SwiftUI
import SwiftData

public struct AddExtraClassSheet: View {
    public let subject: Subject
    public let service: AttendanceService
    public let onDismiss: () -> Void
    public let onSaved: () -> Void

    @State private var selectedDate: Date = Date()
    @State private var startTimeDate: Date = TimetableEngine.dateFromTime24("16:00")
    @State private var endTimeDate: Date = TimetableEngine.dateFromTime24("17:00")
    @State private var room: String = ""
    @State private var status: AttendanceStatus = .present
    @State private var notes: String = ""

    public init(
        subject: Subject,
        service: AttendanceService,
        onDismiss: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.subject = subject
        self.service = service
        self.onDismiss = onDismiss
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Class Time & Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)

                    HStack {
                        Text("Start Time")
                        Spacer()
                        DatePicker("", selection: $startTimeDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }

                    HStack {
                        Text("End Time")
                        Spacer()
                        DatePicker("", selection: $endTimeDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }

                    TextField("Room (default: \(subject.room ?? "—"))", text: $room)
                }

                Section("Attendance Result") {
                    Picker("Attendance Status", selection: $status) {
                        Text("Attended (Present)").tag(AttendanceStatus.present)
                        Text("Missed (Absent)").tag(AttendanceStatus.missed)
                    }
                    .pickerStyle(.segmented)

                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle("Add Extra Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExtraClass()
                    }
                }
            }
            .onAppear {
                room = subject.room ?? ""
            }
        }
    }

    private func saveExtraClass() {
        HapticFeedback.success()
        let dateIso = TimetableEngine.formatISODate(selectedDate)
        let startTimeStr = TimetableEngine.formatTime24Hour(from: startTimeDate)
        let endTimeStr = TimetableEngine.formatTime24Hour(from: endTimeDate)

        do {
            _ = try service.addExtraClass(
                subject: subject,
                date: dateIso,
                startTime: startTimeStr,
                endTime: endTimeStr,
                status: status,
                notes: notes.isEmpty ? nil : notes,
                room: room.isEmpty ? nil : room
            )
            onSaved()
            onDismiss()
        } catch {
            print("Failed to save extra class: \(error)")
        }
    }
}
