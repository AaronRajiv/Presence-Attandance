import XCTest
import SwiftData
#if canImport(PresenceKit)
@testable import PresenceKit
#else
@testable import Presence
#endif

final class PresenceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.container = try ModelSchema.createContainer(inMemory: true)
        self.context = ModelContext(self.container)
    }

    override func tearDownWithError() throws {
        self.container = nil
        self.context = nil
        try super.tearDownWithError()
    }

    func testModelContainerInitialization() throws {
        XCTAssertNotNil(self.container)
        XCTAssertNotNil(self.context)
    }

    func testSubjectModelPersistence() throws {
        let subject = Subject(
            name: "System Software and Compiler Design",
            shortName: "Compiler Design",
            courseCode: "21CS71",
            lecturer: "Dr. Aravind Menon",
            room: "Block C · 402",
            tint: "#0A84FF"
        )
        self.context.insert(subject)
        try self.context.save()

        let descriptor = FetchDescriptor<Subject>()
        let fetched = try self.context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.shortName, "Compiler Design")
    }

    func testOccurrenceAndAttendanceRecordRelationship() throws {
        let subject = Subject(name: "Data Science", shortName: "Data Science")
        self.context.insert(subject)

        let occurrence = ClassOccurrence(
            subject: subject,
            date: "2026-08-16",
            startTime: "14:00",
            endTime: "15:00",
            room: "Lab 3 · 210",
            isExtra: false,
            state: .conducted
        )
        self.context.insert(occurrence)

        let record = AttendanceRecord(
            occurrence: occurrence,
            status: .present,
            notes: "Regular lecture"
        )
        self.context.insert(record)
        try self.context.save()

        let occDescriptor = FetchDescriptor<ClassOccurrence>()
        let fetchedOccs = try self.context.fetch(occDescriptor)
        XCTAssertEqual(fetchedOccs.count, 1)
        XCTAssertEqual(fetchedOccs.first?.state, .conducted)
        XCTAssertEqual(fetchedOccs.first?.attendanceRecord?.status, .present)
    }
}
