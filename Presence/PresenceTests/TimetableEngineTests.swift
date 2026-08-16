import XCTest
#if canImport(PresenceKit)
@testable import PresenceKit
#else
@testable import Presence
#endif

final class TimetableEngineTests: XCTestCase {
    let semester = Semester(startDate: "2026-08-01", endDate: "2026-11-30")

    func testNextClassResolutionConsistency() {
        let cloudSub = Subject(
            id: "sub-cloud",
            name: "Cloud Computing & Big Data",
            shortName: "Cloud Computing",
            courseCode: "21CS74",
            lecturer: "Prof. Meera Raghavan",
            room: "Block B · 305"
        )
        let schWed = ClassSchedule(subject: cloudSub, weekday: 3, startTime: "15:30", endTime: "16:30", room: "Block B · 305")
        let schFri = ClassSchedule(subject: cloudSub, weekday: 5, startTime: "15:30", endTime: "16:30", room: "Block B · 305")
        cloudSub.schedules = [schWed, schFri]

        let compilerSub = Subject(
            id: "sub-sscd",
            name: "System Software and Compiler Design",
            shortName: "Compiler Design",
            room: "Block C · 402"
        )
        let schMon = ClassSchedule(subject: compilerSub, weekday: 1, startTime: "09:00", endTime: "10:00", room: "Block C · 402")
        compilerSub.schedules = [schMon]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Sunday 2026-08-16 10:00 GMT
        let testSunday = TimetableEngine.parseISODate("2026-08-16", calendar: calendar)

        // 1. Next class for Cloud Computing alone
        let cloudNext = TimetableEngine.getNextClassForSubject(
            subject: cloudSub,
            schedules: [schWed, schFri],
            semester: semester,
            occurrences: [],
            from: testSunday,
            calendar: calendar
        )
        XCTAssertEqual(cloudNext.time, "15:30")
        XCTAssertEqual(cloudNext.label, "Wednesday · 15:30")

        // 2. Next class across all subjects
        let overallNext = TimetableEngine.getNextClassAcrossAllSubjects(
            subjects: [cloudSub, compilerSub],
            schedules: [schWed, schFri, schMon],
            semester: semester,
            occurrences: [],
            from: testSunday,
            calendar: calendar
        )
        XCTAssertNotNil(overallNext)
        XCTAssertEqual(overallNext?.subject.shortName, "Compiler Design")
        XCTAssertEqual(overallNext?.time, "09:00")
        XCTAssertEqual(overallNext?.label, "Tomorrow at 09:00")

        // 3. Live Day Status on Sunday
        let live = TimetableEngine.getLiveDayStatus(
            subjects: [cloudSub, compilerSub],
            schedules: [schWed, schFri, schMon],
            occurrences: [],
            attendanceRecords: [],
            semester: semester,
            now: testSunday,
            calendar: calendar
        )
        XCTAssertFalse(live.hasClassesToday)
        XCTAssertNil(live.ongoing)
        XCTAssertNil(live.nextClassToday)
        XCTAssertEqual(live.nextOverall?.subject.shortName, "Compiler Design")
    }

    func testSemesterBoundariesStrictEnforcement() {
        XCTAssertFalse(TimetableEngine.isDateWithinSemester("2026-07-31", semester: semester))
        XCTAssertTrue(TimetableEngine.isDateWithinSemester("2026-08-01", semester: semester))
        XCTAssertTrue(TimetableEngine.isDateWithinSemester("2026-11-30", semester: semester))
        XCTAssertFalse(TimetableEngine.isDateWithinSemester("2026-12-01", semester: semester))
    }
}
