import XCTest
#if canImport(PresenceKit)
@testable import PresenceKit
#else
@testable import Presence
#endif

final class ProjectionEdgeCaseTests: XCTestCase {
    func testCase1ZeroConductedReturnsSafeZeroMarginsAndNilPercentage() {
        let m = StatsEngine.calculateAttendanceMetrics(present: 0, missed: 0, target: 75, remainingScheduled: 0)
        XCTAssertNil(m.pct)
        XCTAssertEqual(m.bunkBuffer, 0)
        XCTAssertEqual(m.catchUpNeeded, 0)
    }

    func testCase2HundredPercentAttendanceAt75TargetYieldsSafeBunkBuffer() {
        // 8 present, 0 missed -> maxTotal = floor(8 / 0.75) = 10 -> buffer = 10 - 8 = 2
        let m = StatsEngine.calculateAttendanceMetrics(present: 8, missed: 0, target: 75, remainingScheduled: 0)
        XCTAssertEqual(m.pct, 100)
        XCTAssertEqual(m.bunkBuffer, 2)
        XCTAssertEqual(m.catchUpNeeded, 0)
    }

    func testCase3ExactlyAtTargetYieldsZeroBufferAndZeroCatchUp() {
        let m = StatsEngine.calculateAttendanceMetrics(present: 75, missed: 25, target: 75, remainingScheduled: 0)
        XCTAssertEqual(m.pct, 75)
        XCTAssertEqual(m.bunkBuffer, 0)
        XCTAssertEqual(m.catchUpNeeded, 0)
    }

    func testCase4BelowTargetCalculatesRequiredCatchUpConsecutiveClasses() {
        // 70 present, 30 missed at 75% target -> numerator = 75*100 - 100*70 = 500; denom = 25 -> 20 classes
        let m = StatsEngine.calculateAttendanceMetrics(present: 70, missed: 30, target: 75, remainingScheduled: 0)
        XCTAssertEqual(m.pct, 70)
        XCTAssertEqual(m.catchUpNeeded, 20)
        XCTAssertEqual(m.bunkBuffer, 0)
    }

    func testCase5Targets80And90CalculateCorrectly() {
        let m80 = StatsEngine.calculateAttendanceMetrics(present: 80, missed: 20, target: 80, remainingScheduled: 0)
        XCTAssertEqual(m80.pct, 80)
        XCTAssertEqual(m80.bunkBuffer, 0)

        let m90 = StatsEngine.calculateAttendanceMetrics(present: 95, missed: 5, target: 90, remainingScheduled: 0)
        XCTAssertEqual(m90.pct, 95)
        XCTAssertEqual(m90.bunkBuffer, 5)
    }

    func testCase6ProjectedPercentageWithFutureRemainingClasses() {
        let m = StatsEngine.calculateAttendanceMetrics(present: 50, missed: 50, target: 75, remainingScheduled: 100)
        XCTAssertEqual(m.pct, 50)
        XCTAssertEqual(m.projectedPct, 75)
    }

    func testCase7OnlyCancelledClassesRemainingYieldsZeroRemainingCounted() {
        let subject = Subject(name: "NetSec", shortName: "NetSec")
        let sched = ClassSchedule(subject: subject, weekday: 1, startTime: "11:00", endTime: "12:00") // Monday
        subject.schedules = [sched]

        let sem = Semester(startDate: "2026-08-01", endDate: "2026-11-30")
        let fromDate = TimetableEngine.parseISODate("2026-11-20")

        let baseCount = StatsEngine.countRemainingScheduledClasses(
            subjectId: subject.id,
            schedules: [sched],
            occurrences: [],
            semester: sem,
            fromDate: fromDate
        )

        let cancelledOcc = ClassOccurrence(
            subject: subject,
            scheduleId: sched.id,
            date: "2026-11-23", // Monday
            startTime: "11:00",
            endTime: "12:00",
            state: .cancelled
        )

        let countWithCancelled = StatsEngine.countRemainingScheduledClasses(
            subjectId: subject.id,
            schedules: [sched],
            occurrences: [cancelledOcc],
            semester: sem,
            fromDate: fromDate
        )

        XCTAssertEqual(countWithCancelled, baseCount - 1)
    }

    func testCase8NegativeOrExtremeInputsNeverReturnNegativeBuffersOrNaN() {
        let m = StatsEngine.calculateAttendanceMetrics(present: -10, missed: -5, target: 75, remainingScheduled: 0)
        XCTAssertEqual(m.totalConducted, 0)
        XCTAssertEqual(m.bunkBuffer, 0)
        XCTAssertEqual(m.catchUpNeeded, 0)
    }

    func testCase9EmptyTrendAndWeeklyDistributionOnZeroAttendanceData() {
        let trend = StatsEngine.calculateAttendanceTrend(occurrences: [], attendanceRecords: [], range: .month)
        XCTAssertTrue(trend.isEmpty)

        let weekly = StatsEngine.calculateWeeklyDistribution(occurrences: [], attendanceRecords: [])
        XCTAssertEqual(weekly.count, 7)
        XCTAssertTrue(weekly.allSatisfy { $0.total == 0 && $0.pct == 0 })
    }

    func testCase10OverallStatisticsMatchesEmptyStateRequirements() {
        let subject = Subject(name: "Test Subject", shortName: "Test")
        let sem = Semester()
        let overall = StatsEngine.calculateOverallStats(
            subjects: [subject],
            occurrences: [],
            attendanceRecords: [],
            schedules: [],
            semester: sem
        )

        XCTAssertEqual(overall.totalConducted, 0)
        XCTAssertNil(overall.pct)
        XCTAssertEqual(overall.bunkBuffer, 0)
        XCTAssertEqual(overall.catchUpNeeded, 0)
    }
}
