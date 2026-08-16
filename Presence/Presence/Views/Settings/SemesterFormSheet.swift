import SwiftUI
import SwiftData

public struct SemesterFormSheet: View {
    public let semester: Semester?
    public let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var name: String = "Current Semester"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()

    public init(semester: Semester?, onDismiss: @escaping () -> Void) {
        self.semester = semester
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Term Details") {
                    TextField("Semester Name", text: $name)
                }

                Section("Academic Boundaries") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Academic Term")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSemester()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || startDate >= endDate)
                }
            }
            .onAppear {
                if let sem = semester {
                    name = sem.name
                    startDate = TimetableEngine.parseISODate(sem.startDate)
                    endDate = TimetableEngine.parseISODate(sem.endDate)
                }
            }
        }
    }

    private func saveSemester() {
        HapticFeedback.medium()
        let startIso = TimetableEngine.formatISODate(startDate)
        let endIso = TimetableEngine.formatISODate(endDate)

        if let existing = semester {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.startDate = startIso
            existing.endDate = endIso
            existing.updatedAt = Date()
        } else {
            let newSem = Semester(
                name: name.trimmingCharacters(in: .whitespaces),
                startDate: startIso,
                endDate: endIso
            )
            modelContext.insert(newSem)
        }

        try? modelContext.save()
        onDismiss()
    }
}
