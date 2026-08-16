import XCTest
#if canImport(PresenceKit)
@testable import PresenceKit
#else
@testable import Presence
#endif

final class AttendanceMathTests: XCTestCase {
    func testFormulaPresentDividedByTotalConducted() {
        let metrics = StatsEngine.calculateAttendanceMetrics(present: 15, missed: 5, target: 75, remainingScheduled: 0)
        XCTAssertEqual(metrics.pct, 75)
        XCTAssertEqual(metrics.totalConducted, 20)
    }

    func testEmptyStateReturnsNilPercentageAndZeroMargins() {
        let metrics = StatsEngine.calculateAttendanceMetrics(present: 0, missed: 0, target: 75, remainingScheduled: 10)
        XCTAssertNil(metrics.pct)
        XCTAssertEqual(metrics.totalConducted, 0)
        XCTAssertEqual(metrics.bunkBuffer, 0)
        XCTAssertEqual(metrics.catchUpNeeded, 0)
        XCTAssertNil(metrics.projectedPct)
    }

    func testAllPresentYields100Percent() {
        let metrics = StatsEngine.calculateAttendanceMetrics(present: 100, missed: 0, target: 75, remainingScheduled: 0)
        XCTAssertEqual(metrics.pct, 100)
        XCTAssertEqual(metrics.totalConducted, 100)
        XCTAssertEqual(metrics.bunkBuffer, 33)
        XCTAssertEqual(metrics.catchUpNeeded, 0)
    }

    func testAllMissedYieldsZeroPercent() {
        let metrics = StatsEngine.calculateAttendanceMetrics(present: 0, missed: 10, target: 75, remainingScheduled: 0)
        XCTAssertEqual(metrics.pct, 0)
        XCTAssertEqual(metrics.totalConducted, 10)
        XCTAssertEqual(metrics.bunkBuffer, 0)
        XCTAssertEqual(metrics.catchUpNeeded, 30)
    }

    func testExtraClassesIncorporatedBasedOnAttendanceResult() {
        // 2 present (1 normal, 1 extra) and 2 missed (1 normal, 1 extra) -> 2/4 = 50%
        let metrics = StatsEngine.calculateAttendanceMetrics(present: 2, missed: 2, target: 75, remainingScheduled: 0)
        XCTAssertEqual(metrics.pct, 50)
        XCTAssertEqual(metrics.totalConducted, 4)
    }

    func testCancelledClassesExcludedFromStats() {
        let subject = Subject(name: "Compiler Design", shortName: "Compiler Design")
        let occConducted = ClassOccurrence(
            subject: subject,
            date: "2026-08-17",
            startTime: "09:00",
            endTime: "10:00",
            state: .conducted
        )
        let record = AttendanceRecord(occurrence: occConducted, status: .present)
        occConducted.attendanceRecord = record

        let occCancelled = ClassOccurrence(
            subject: subject,
            date: "2026-08-19",
            startTime: "09:00",
            endTime: "10:00",
            state: .cancelled,
            cancellationReason: "National Holiday"
        )

        let stats = StatsEngine.calculateSubjectStats(
            subjectId: subject.id,
            occurrences: [occConducted, occCancelled],
            attendanceRecords: [record],
            schedules: [],
            semester: nil
        )

        XCTAssertEqual(stats.totalConducted, 1)
        XCTAssertEqual(stats.present, 1)
        XCTAssertEqual(stats.missed, 0)
        XCTAssertEqual(stats.pct, 100)
        XCTAssertEqual(stats.totalCancelled, 1)
    }
}
