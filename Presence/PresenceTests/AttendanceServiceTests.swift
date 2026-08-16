import XCTest
import SwiftData
#if canImport(PresenceKit)
@testable import PresenceKit
#else
@testable import Presence
#endif

final class AttendanceServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var service: AttendanceService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let cont = try ModelSchema.createContainer(inMemory: true)
        self.container = cont
        let ctx = ModelContext(cont)
        self.context = ctx
        self.service = AttendanceService(context: ctx)
    }

    override func tearDownWithError() throws {
        self.service = nil
        self.container = nil
        self.context = nil
        try super.tearDownWithError()
    }

    @MainActor
    func testAttendanceStateTransitionsAndDuplicatePrevention() throws {
        let subject = Subject(name: "Data Science", shortName: "Data Science")
        self.context.insert(subject)
        try self.context.save()

        let occ = ClassOccurrence(
            subject: subject,
            date: "2026-08-18",
            startTime: "14:00",
            endTime: "15:00",
            state: .scheduled
        )
        self.context.insert(occ)
        try self.context.save()

        let item = DayClassItem(
            occurrence: occ,
            subject: subject,
            attendanceRecord: nil,
            isOngoing: false,
            isUpcoming: true,
            isPast: false
        )

        // 1. Mark Present
        try self.service.markOccurrenceAttendance(item: item, status: .present)
        var records = try self.context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.status, .present)
        XCTAssertEqual(occ.state, .conducted)

        // 2. Mark Missed on same occurrence -> Prevent duplicate record, update in-place
        let updatedItem = DayClassItem(
            occurrence: occ,
            subject: subject,
            attendanceRecord: records.first,
            isOngoing: false,
            isUpcoming: false,
            isPast: true
        )
        try self.service.markOccurrenceAttendance(item: updatedItem, status: .missed)
        records = try self.context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(records.count, 1) // Exactly 1, no duplicate
        XCTAssertEqual(records.first?.status, .missed)

        // 3. Undo restores previous Present status
        let undone = try self.service.undoLastAction()
        XCTAssertTrue(undone)
        records = try self.context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.status, .present)
    }

    @MainActor
    func testExtraClassCreationAndAttendance() throws {
        let subject = Subject(name: "Major Project", shortName: "Project")
        self.context.insert(subject)
        try self.context.save()

        let extraOcc = try self.service.addExtraClass(
            subject: subject,
            date: "2026-08-20",
            startTime: "16:45",
            endTime: "17:45",
            status: .present,
            notes: "Lab revision session"
        )

        XCTAssertTrue(extraOcc.isExtra)
        XCTAssertEqual(extraOcc.state, .conducted)
        XCTAssertEqual(extraOcc.attendanceRecord?.status, .present)

        let stats = StatsEngine.calculateSubjectStats(
            subjectId: subject.id,
            occurrences: [extraOcc],
            attendanceRecords: [extraOcc.attendanceRecord!],
            schedules: [],
            semester: nil
        )
        XCTAssertEqual(stats.totalConducted, 1)
        XCTAssertEqual(stats.pct, 100)
    }

    @MainActor
    func testClassCancellationExcludesFromAttendance() throws {
        let subject = Subject(name: "Network Security", shortName: "NetSec")
        self.context.insert(subject)

        let occ = ClassOccurrence(
            subject: subject,
            date: "2026-08-21",
            startTime: "11:00",
            endTime: "12:00",
            state: .scheduled
        )
        self.context.insert(occ)
        try self.context.save()

        let item = DayClassItem(
            occurrence: occ,
            subject: subject,
            attendanceRecord: nil,
            isOngoing: false,
            isUpcoming: true,
            isPast: false
        )

        try self.service.cancelOccurrence(item: item, reason: "College Holiday")
        XCTAssertEqual(occ.state, .cancelled)
        XCTAssertEqual(occ.cancellationReason, "College Holiday")
        XCTAssertNil(occ.attendanceRecord)

        // Uncancel restores scheduled state
        try self.service.uncancelOccurrence(occurrenceId: occ.id)
        XCTAssertEqual(occ.state, .scheduled)
        XCTAssertNil(occ.cancellationReason)
    }

    @MainActor
    func testHistoricalOccurrenceImmutability() throws {
        let subject = Subject(name: "Compiler Design", shortName: "Compiler Design")
        self.context.insert(subject)

        let oldSchedule = ClassSchedule(subject: subject, weekday: 1, startTime: "09:00", endTime: "10:00")
        self.context.insert(oldSchedule)

        let historicalOcc = ClassOccurrence(
            subject: subject,
            scheduleId: oldSchedule.id,
            date: "2026-08-10",
            startTime: "09:00",
            endTime: "10:00",
            state: .conducted
        )
        self.context.insert(historicalOcc)
        try self.context.save()

        // Modify recurring schedule to Monday 14:00
        oldSchedule.startTime = "14:00"
        oldSchedule.endTime = "15:00"
        try self.context.save()

        // Historical occurrence must remain completely unchanged
        let fetchedOcc = try self.context.fetch(FetchDescriptor<ClassOccurrence>()).first!
        XCTAssertEqual(fetchedOcc.startTime, "09:00")
        XCTAssertEqual(fetchedOcc.endTime, "10:00")
        XCTAssertEqual(fetchedOcc.date, "2026-08-10")
    }

    @MainActor
    func testSubjectDeletionCascadesProperly() throws {
        let subject = Subject(name: "Data Science", shortName: "Data Science")
        self.context.insert(subject)

        let sched = ClassSchedule(subject: subject, weekday: 2, startTime: "14:00", endTime: "15:00")
        self.context.insert(sched)

        let occ = ClassOccurrence(subject: subject, date: "2026-08-18", startTime: "14:00", endTime: "15:00", state: .conducted)
        self.context.insert(occ)

        let rec = AttendanceRecord(occurrence: occ, status: .present)
        self.context.insert(rec)
        occ.attendanceRecord = rec
        subject.schedules = [sched]
        subject.occurrences = [occ]
        try self.context.save()

        // Delete subject
        try self.service.deleteSubject(subject: subject)

        let subjects = try self.context.fetch(FetchDescriptor<Subject>())
        let schedules = try self.context.fetch(FetchDescriptor<ClassSchedule>())
        let occurrences = try self.context.fetch(FetchDescriptor<ClassOccurrence>())
        let records = try self.context.fetch(FetchDescriptor<AttendanceRecord>())

        XCTAssertTrue(subjects.isEmpty)
        XCTAssertTrue(schedules.isEmpty)
        XCTAssertTrue(occurrences.isEmpty)
        XCTAssertTrue(records.isEmpty)
    }
}
