import XCTest
import SwiftData
#if canImport(PresenceKit)
@testable import PresenceKit
#else
@testable import Presence
#endif

final class MultiSubjectAndSettingsTests: XCTestCase {
    let semester = Semester(startDate: "2026-08-01", endDate: "2026-11-30")

    // MARK: - 1. Multi-Slot Subject Timetable Tests

    func testSubjectWithThreeSlotsResolvesCorrectlyAcrossDays() {
        let compilerSub = Subject(
            id: "sub-cd",
            name: "Compiler Design",
            shortName: "Compiler",
            room: "EE302",
            tint: "#0A84FF"
        )
        // Mon 10:00-11:00, Wed 14:00-15:00, Fri 09:00-10:00
        let schMon = ClassSchedule(id: "sch-cd-mon", subject: compilerSub, weekday: 1, startTime: "10:00", endTime: "11:00", room: "EE302")
        let schWed = ClassSchedule(id: "sch-cd-wed", subject: compilerSub, weekday: 3, startTime: "14:00", endTime: "15:00", room: "EE302")
        let schFri = ClassSchedule(id: "sch-cd-fri", subject: compilerSub, weekday: 5, startTime: "09:00", endTime: "10:00", room: "EE302")
        compilerSub.schedules = [schMon, schWed, schFri]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Monday 2026-08-17
        let monClasses = TimetableEngine.getClassesForDate(
            dateIso: "2026-08-17",
            subjects: [compilerSub],
            schedules: [schMon, schWed, schFri],
            occurrences: [],
            attendanceRecords: [],
            semester: semester,
            currentTime: TimetableEngine.parseISODate("2026-08-16", calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(monClasses.count, 1)
        XCTAssertEqual(monClasses[0].occurrence.startTime, "10:00")

        // Wednesday 2026-08-19
        let wedClasses = TimetableEngine.getClassesForDate(
            dateIso: "2026-08-19",
            subjects: [compilerSub],
            schedules: [schMon, schWed, schFri],
            occurrences: [],
            attendanceRecords: [],
            semester: semester,
            currentTime: TimetableEngine.parseISODate("2026-08-16", calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(wedClasses.count, 1)
        XCTAssertEqual(wedClasses[0].occurrence.startTime, "14:00")

        // Friday 2026-08-21
        let friClasses = TimetableEngine.getClassesForDate(
            dateIso: "2026-08-21",
            subjects: [compilerSub],
            schedules: [schMon, schWed, schFri],
            occurrences: [],
            attendanceRecords: [],
            semester: semester,
            currentTime: TimetableEngine.parseISODate("2026-08-16", calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(friClasses.count, 1)
        XCTAssertEqual(friClasses[0].occurrence.startTime, "09:00")

        // Tuesday 2026-08-18 (No class scheduled)
        let tueClasses = TimetableEngine.getClassesForDate(
            dateIso: "2026-08-18",
            subjects: [compilerSub],
            schedules: [schMon, schWed, schFri],
            occurrences: [],
            attendanceRecords: [],
            semester: semester,
            currentTime: TimetableEngine.parseISODate("2026-08-16", calendar: calendar),
            calendar: calendar
        )
        XCTAssertEqual(tueClasses.count, 0)
    }

    // MARK: - 2. Deterministic Attendance by Class Day Trend Tests (Part 26)

    func testAttendanceByClassDaySubjectIsolationAndOverallAggregation() {
        // Subject 1: Compiler Design (Tue, Wed, Thu)
        let subCD = Subject(id: "sub-cd", name: "Compiler Design", shortName: "CD", tint: "#0A84FF")
        let schCD_Tue = ClassSchedule(id: "sch-cd-tue", subject: subCD, weekday: 2, startTime: "10:00", endTime: "11:00")
        let schCD_Wed = ClassSchedule(id: "sch-cd-wed", subject: subCD, weekday: 3, startTime: "10:00", endTime: "11:00")
        let schCD_Thu = ClassSchedule(id: "sch-cd-thu", subject: subCD, weekday: 4, startTime: "10:00", endTime: "11:00")
        subCD.schedules = [schCD_Tue, schCD_Wed, schCD_Thu]

        // Subject 2: NSCL (Mon, Wed, Fri)
        let subNSCL = Subject(id: "sub-nscl", name: "Network Security & Cryptography Lab", shortName: "NSCL", tint: "#5E5CE6")
        let schNSCL_Mon = ClassSchedule(id: "sch-nscl-mon", subject: subNSCL, weekday: 1, startTime: "14:00", endTime: "16:00")
        let schNSCL_Wed = ClassSchedule(id: "sch-nscl-wed", subject: subNSCL, weekday: 3, startTime: "14:00", endTime: "16:00")
        let schNSCL_Fri = ClassSchedule(id: "sch-nscl-fri", subject: subNSCL, weekday: 5, startTime: "14:00", endTime: "16:00")
        subNSCL.schedules = [schNSCL_Mon, schNSCL_Wed, schNSCL_Fri]

        let allSchedules = [schCD_Tue, schCD_Wed, schCD_Thu, schNSCL_Mon, schNSCL_Wed, schNSCL_Fri]
        let allSubjects = [subCD, subNSCL]

        // Attendance examples:
        // Compiler Design: Tue -> Present (100%), Wed -> Present (100%), Thu -> Missed (0%)
        // Dates: Aug 18 (Tue), Aug 19 (Wed), Aug 20 (Thu)
        let occCD_Tue = ClassOccurrence(id: "occ-cd-tue", subject: subCD, date: "2026-08-18", startTime: "10:00", endTime: "11:00", state: .conducted)
        let recCD_Tue = AttendanceRecord(id: "rec-cd-tue", occurrence: occCD_Tue, status: .present)

        let occCD_Wed = ClassOccurrence(id: "occ-cd-wed", subject: subCD, date: "2026-08-19", startTime: "10:00", endTime: "11:00", state: .conducted)
        let recCD_Wed = AttendanceRecord(id: "rec-cd-wed", occurrence: occCD_Wed, status: .present)

        let occCD_Thu = ClassOccurrence(id: "occ-cd-thu", subject: subCD, date: "2026-08-20", startTime: "10:00", endTime: "11:00", state: .conducted)
        let recCD_Thu = AttendanceRecord(id: "rec-cd-thu", occurrence: occCD_Thu, status: .missed)

        // NSCL: Mon -> Missed (0%), Wed -> Present (100%), Fri -> Present (100%)
        // Dates: Aug 17 (Mon), Aug 19 (Wed), Aug 21 (Fri)
        let occNSCL_Mon = ClassOccurrence(id: "occ-nscl-mon", subject: subNSCL, date: "2026-08-17", startTime: "14:00", endTime: "16:00", state: .conducted)
        let recNSCL_Mon = AttendanceRecord(id: "rec-nscl-mon", occurrence: occNSCL_Mon, status: .missed)

        let occNSCL_Wed = ClassOccurrence(id: "occ-nscl-wed", subject: subNSCL, date: "2026-08-19", startTime: "14:00", endTime: "16:00", state: .conducted)
        let recNSCL_Wed = AttendanceRecord(id: "rec-nscl-wed", occurrence: occNSCL_Wed, status: .present)

        let occNSCL_Fri = ClassOccurrence(id: "occ-nscl-fri", subject: subNSCL, date: "2026-08-21", startTime: "14:00", endTime: "16:00", state: .conducted)
        let recNSCL_Fri = AttendanceRecord(id: "rec-nscl-fri", occurrence: occNSCL_Fri, status: .present)

        let allOccurrences = [occCD_Tue, occCD_Wed, occCD_Thu, occNSCL_Mon, occNSCL_Wed, occNSCL_Fri]
        let allRecords = [recCD_Tue, recCD_Wed, recCD_Thu, recNSCL_Mon, recNSCL_Wed, recNSCL_Fri]

        // 1. Compiler Design Scoped Trend -> MUST ONLY return [Tue, Wed, Thu]
        let cdTrend = StatsEngine.calculateAttendanceByClassDay(
            subjectId: subCD.id,
            subjects: allSubjects,
            schedules: allSchedules,
            occurrences: allOccurrences,
            attendanceRecords: allRecords,
            semester: semester
        )
        XCTAssertEqual(cdTrend.count, 3, "Compiler Design should only show 3 class days")
        XCTAssertEqual(cdTrend.map { $0.shortLabel }, ["Tue", "Wed", "Thu"])
        XCTAssertEqual(cdTrend[0].pct, 100, "Tue should be 100%")
        XCTAssertEqual(cdTrend[1].pct, 100, "Wed should be 100%")
        XCTAssertEqual(cdTrend[2].pct, 0, "Thu should be 0%")

        // 2. NSCL Scoped Trend -> MUST ONLY return [Mon, Wed, Fri]
        let nsclTrend = StatsEngine.calculateAttendanceByClassDay(
            subjectId: subNSCL.id,
            subjects: allSubjects,
            schedules: allSchedules,
            occurrences: allOccurrences,
            attendanceRecords: allRecords,
            semester: semester
        )
        XCTAssertEqual(nsclTrend.count, 3, "NSCL should only show 3 class days")
        XCTAssertEqual(nsclTrend.map { $0.shortLabel }, ["Mon", "Wed", "Fri"])
        XCTAssertEqual(nsclTrend[0].pct, 0, "Mon should be 0%")
        XCTAssertEqual(nsclTrend[1].pct, 100, "Wed should be 100%")
        XCTAssertEqual(nsclTrend[2].pct, 100, "Fri should be 100%")

        // 3. Overall Trend -> MUST return [Mon, Tue, Wed, Thu, Fri] and NO Sat/Sun
        let overallTrend = StatsEngine.calculateAttendanceByClassDay(
            subjectId: nil,
            subjects: allSubjects,
            schedules: allSchedules,
            occurrences: allOccurrences,
            attendanceRecords: allRecords,
            semester: semester
        )
        XCTAssertEqual(overallTrend.count, 5, "Overall should show all 5 academic weekdays")
        XCTAssertEqual(overallTrend.map { $0.shortLabel }, ["Mon", "Tue", "Wed", "Thu", "Fri"])
        // Mon: 0/1 (0%), Tue: 1/1 (100%), Wed: 2/2 (100%), Thu: 0/1 (0%), Fri: 1/1 (100%)
        XCTAssertEqual(overallTrend[0].pct, 0)
        XCTAssertEqual(overallTrend[1].pct, 100)
        XCTAssertEqual(overallTrend[2].pct, 100)
        XCTAssertEqual(overallTrend[3].pct, 0)
        XCTAssertEqual(overallTrend[4].pct, 100)
    }

    // MARK: - 3. Academic Day Exception (Holiday & Leave) Tests

    func testCollegeHolidayExcludesFromConductedAndDoesNotCountAsMissed() {
        let sub = Subject(id: "sub-cd", name: "Compiler Design", shortName: "CD")
        let sch = ClassSchedule(id: "sch-1", subject: sub, weekday: 4, startTime: "10:00", endTime: "11:00")
        sub.schedules = [sch]

        // Thursday Aug 20 marked as College Holiday
        let holiday = AcademicDayException(date: "2026-08-20", type: .holiday, reason: "Independence Day")
        let occHoliday = ClassOccurrence(id: "occ-hol", subject: sub, date: "2026-08-20", startTime: "10:00", endTime: "11:00", state: .conducted)

        // Thursday Aug 13 normal class (Present)
        let occNormal = ClassOccurrence(id: "occ-norm", subject: sub, date: "2026-08-13", startTime: "10:00", endTime: "11:00", state: .conducted)
        let recNormal = AttendanceRecord(id: "rec-norm", occurrence: occNormal, status: .present)

        let stats = StatsEngine.calculateSubjectStats(
            subjectId: sub.id,
            occurrences: [occNormal, occHoliday],
            attendanceRecords: [recNormal],
            schedules: [sch],
            dayExceptions: [holiday],
            semester: semester,
            target: 75
        )

        XCTAssertEqual(stats.totalConducted, 1, "Holiday occurrence must NOT count as conducted")
        XCTAssertEqual(stats.present, 1)
        XCTAssertEqual(stats.missed, 0)
        XCTAssertEqual(stats.pct, 100, "Percentage remains 100%")
    }

    func testCIEDayExceptionExcludesClassesFromConducted() {
        let sub = Subject(id: "sub-cd", name: "Compiler Design", shortName: "CD", tint: "#0A84FF")
        let sch = ClassSchedule(id: "sch-1", subject: sub, weekday: 1, startTime: "10:00", endTime: "11:00")
        sub.schedules = [sch]

        let occ1 = ClassOccurrence(id: "occ-1", subject: sub, date: "2026-08-17", startTime: "10:00", endTime: "11:00", state: .conducted)
        let rec1 = AttendanceRecord(id: "rec-1", occurrence: occ1, status: .present)

        let occ2_cie = ClassOccurrence(id: "occ-2", subject: sub, date: "2026-08-24", startTime: "10:00", endTime: "11:00", state: .conducted)

        let cie = AcademicDayException(id: "exc-cie", date: "2026-08-24", type: .cie, reason: "CIE 1 Examination")

        let stats = StatsEngine.calculateSubjectStats(
            subjectId: sub.id,
            occurrences: [occ1, occ2_cie],
            attendanceRecords: [rec1],
            schedules: [sch],
            dayExceptions: [cie],
            semester: semester,
            target: 75
        )

        XCTAssertEqual(stats.totalConducted, 1, "CIE Exam occurrence must NOT count as conducted regular class")
        XCTAssertEqual(stats.present, 1)
        XCTAssertEqual(stats.missed, 0)
        XCTAssertEqual(stats.pct, 100)
    }

    // MARK: - 4. Exact Mathematical Bunk Buffer and Catch-Up Tests

    func testExactBunkBufferFormula() {
        // Conducted = 20, Present = 18, Missed = 2, Target = 85%
        // Max x where 18 / (20 + x) >= 0.85 -> floor(1800/85) - 20 = 21 - 20 = 1
        let metrics = StatsEngine.calculateAttendanceMetrics(present: 18, missed: 2, target: 85)
        XCTAssertEqual(metrics.bunkBuffer, 1)
        XCTAssertEqual(metrics.catchUpNeeded, 0)
    }

    func testExactCatchUpFormula() {
        // Conducted = 10, Present = 7, Missed = 3, Target = 75%
        // Min x where (7 + x) / (10 + x) >= 0.75 -> ceil((75*10 - 700) / 25) = ceil(50/25) = 2
        let metrics = StatsEngine.calculateAttendanceMetrics(present: 7, missed: 3, target: 75)
        XCTAssertEqual(metrics.bunkBuffer, 0)
        XCTAssertEqual(metrics.catchUpNeeded, 2)
    }

    // MARK: - 5. AppState Settings & Theme Tests

    func testAppStateAccentAndThemePersistence() {
        let appState = AppState()
        appState.setAccent("#FF9F0A")
        XCTAssertEqual(appState.accentHex, "#FF9F0A")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "user_accent_hex"), "#FF9F0A")

        appState.setDarkMode(false)
        XCTAssertFalse(appState.isDarkMode)
        XCTAssertEqual(appState.colorScheme, .light)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "user_dark_mode"), false)

        appState.setDarkMode(true)
        XCTAssertTrue(appState.isDarkMode)
        XCTAssertEqual(appState.colorScheme, .dark)
    }

    // MARK: - 6. Human-Readable Date Range Tests

    func testHumanReadableDateRangeFormatting() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // Same year: "3 August – 16 December"
        let sameYear = TimetableEngine.formatDateRangeHuman(
            startIso: "2026-08-03",
            endIso: "2026-12-16",
            calendar: cal
        )
        XCTAssertEqual(sameYear, "3 August – 16 December")

        // Cross year: "3 August 2026 – 16 January 2027"
        let crossYear = TimetableEngine.formatDateRangeHuman(
            startIso: "2026-08-03",
            endIso: "2027-01-16",
            calendar: cal
        )
        XCTAssertEqual(crossYear, "3 August 2026 – 16 January 2027")
    }

    // MARK: - 7. Semester Boundaries Strictly Filter Classes Outside Range

    func testSemesterBoundariesStrictlyFilterClassesOutsideRange() {
        let sub = Subject(id: "sub-net", name: "Computer Networks and Network Security", shortName: "Networks", tint: "#64D2FF")
        let sch = ClassSchedule(id: "sch-net", subject: sub, weekday: 1, startTime: "10:00", endTime: "11:00")
        sub.schedules = [sch]

        let sem = Semester(startDate: "2026-08-03", endDate: "2026-10-31")

        // Occurrence before semester: 2026-07-27
        let occBefore = ClassOccurrence(id: "occ-before", subject: sub, date: "2026-07-27", startTime: "10:00", endTime: "11:00", state: .conducted)
        let recBefore = AttendanceRecord(id: "rec-before", occurrence: occBefore, status: .missed)

        // Occurrence inside semester: 2026-08-10
        let occInside = ClassOccurrence(id: "occ-inside", subject: sub, date: "2026-08-10", startTime: "10:00", endTime: "11:00", state: .conducted)
        let recInside = AttendanceRecord(id: "rec-inside", occurrence: occInside, status: .present)

        // Occurrence after semester: 2026-11-09
        let occAfter = ClassOccurrence(id: "occ-after", subject: sub, date: "2026-11-09", startTime: "10:00", endTime: "11:00", state: .conducted)
        let recAfter = AttendanceRecord(id: "rec-after", occurrence: occAfter, status: .present)

        let stats = StatsEngine.calculateSubjectStats(
            subjectId: sub.id,
            occurrences: [occBefore, occInside, occAfter],
            attendanceRecords: [recBefore, recInside, recAfter],
            schedules: [sch],
            semester: sem,
            target: 75
        )

        // Only occInside must be counted!
        XCTAssertEqual(stats.totalConducted, 1)
        XCTAssertEqual(stats.present, 1)
        XCTAssertEqual(stats.missed, 0)
        XCTAssertEqual(stats.pct, 100)
    }

    // MARK: - 8. Stage 4 Duplicate Prevention & Attendance Mutation Tests

    func testAttendanceMarkingAndUpdatePreventsDuplicateRecords() throws {
        let container = try ModelContainer(for: ModelSchema.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let service = AttendanceService(context: context)

        let sub = Subject(name: "Compiler Design", shortName: "CD", tint: "#0A84FF")
        context.insert(sub)

        let sch = ClassSchedule(subject: sub, weekday: 1, startTime: "09:00", endTime: "10:00")
        context.insert(sch)
        sub.schedules = [sch]

        // Virtual DayClassItem
        let virtOcc = ClassOccurrence(
            id: "virt-cd-2026-08-10-sch1",
            subject: nil,
            scheduleId: sch.id,
            date: "2026-08-10",
            startTime: "09:00",
            endTime: "10:00",
            state: .scheduled
        )
        let item = DayClassItem(occurrence: virtOcc, subject: sub, attendanceRecord: nil, isOngoing: false, isUpcoming: false, isPast: true)

        // 1. Mark Present
        try service.markOccurrenceAttendance(item: item, status: .present)
        let recs1 = try context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(recs1.count, 1)
        XCTAssertEqual(recs1.first?.status, .present)

        // Fetch the created occurrence
        let occs1 = try context.fetch(FetchDescriptor<ClassOccurrence>())
        XCTAssertEqual(occs1.count, 1)
        let realOcc = occs1.first!
        let updatedItem = DayClassItem(occurrence: realOcc, subject: sub, attendanceRecord: recs1.first, isOngoing: false, isUpcoming: false, isPast: true)

        // 2. Change from Present -> Missed (must update existing record, NOT create another)
        try service.markOccurrenceAttendance(item: updatedItem, status: .missed)
        let recs2 = try context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(recs2.count, 1, "Duplicate AttendanceRecord was created instead of updating in-place")
        XCTAssertEqual(recs2.first?.status, .missed)

        // 3. Mark Missed again (must be idempotent)
        try service.markOccurrenceAttendance(item: updatedItem, status: .missed)
        let recs3 = try context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(recs3.count, 1)
        XCTAssertEqual(recs3.first?.status, .missed)
    }

    // MARK: - 9. Stage 4 Subject Cascade Deletion

    func testSubjectCascadeDeletion() throws {
        let container = try ModelContainer(for: ModelSchema.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let service = AttendanceService(context: context)

        let sub = Subject(name: "Operating Systems", shortName: "OS", tint: "#30D158")
        context.insert(sub)

        let sch = ClassSchedule(subject: sub, weekday: 2, startTime: "11:00", endTime: "12:00")
        context.insert(sch)
        sub.schedules = [sch]

        let occ = ClassOccurrence(subject: sub, scheduleId: sch.id, date: "2026-08-11", startTime: "11:00", endTime: "12:00", state: .conducted)
        context.insert(occ)
        sub.occurrences = [occ]

        let rec = AttendanceRecord(occurrence: occ, status: .present)
        context.insert(rec)
        occ.attendanceRecord = rec

        try context.save()

        // Delete subject
        try service.deleteSubject(subject: sub)

        let subs = try context.fetch(FetchDescriptor<Subject>())
        let schedules = try context.fetch(FetchDescriptor<ClassSchedule>())
        let occs = try context.fetch(FetchDescriptor<ClassOccurrence>())
        let records = try context.fetch(FetchDescriptor<AttendanceRecord>())

        XCTAssertEqual(subs.count, 0)
        XCTAssertEqual(schedules.count, 0)
        XCTAssertEqual(occs.count, 0)
        XCTAssertEqual(records.count, 0)
    }

    // MARK: - 10. Bunk Buffer & Catch-Up Edge Cases

    func testBunkBufferAndCatchUpEdgeCases() {
        // Zero conducted: 0/0 -> buffer: 0, catchUp: 0
        let zero = StatsEngine.calculateAttendanceMetrics(present: 0, missed: 0, target: 75)
        XCTAssertEqual(zero.bunkBuffer, 0)
        XCTAssertEqual(zero.catchUpNeeded, 0)
        XCTAssertNil(zero.pct)

        // 100% attendance: 10/10 at 75% target -> buffer: floor(1000/75) - 10 = 13 - 10 = 3
        let full = StatsEngine.calculateAttendanceMetrics(present: 10, missed: 0, target: 75)
        XCTAssertEqual(full.pct, 100)
        XCTAssertEqual(full.bunkBuffer, 3)
        XCTAssertEqual(full.catchUpNeeded, 0)

        // Exactly at target: 75/100 at 75% -> buffer: floor(7500/75) - 100 = 0, catchUp: 0
        let exact = StatsEngine.calculateAttendanceMetrics(present: 75, missed: 25, target: 75)
        XCTAssertEqual(exact.pct, 75)
        XCTAssertEqual(exact.bunkBuffer, 0)
        XCTAssertEqual(exact.catchUpNeeded, 0)

        // Severely below target: 0/5 at 75% -> buffer: 0, catchUp: ceil((75*5 - 0)/(25)) = ceil(375/25) = 15
        let low = StatsEngine.calculateAttendanceMetrics(present: 0, missed: 5, target: 75)
        XCTAssertEqual(low.pct, 0)
        XCTAssertEqual(low.bunkBuffer, 0)
        XCTAssertEqual(low.catchUpNeeded, 15)
    }

    // MARK: - 11. Calendar Month Grid & Late-Month (27-31) Selection Tests

    func testCalendarMonthGridHasUniqueIDsAndExactAugustSelection() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let aug2026 = TimetableEngine.parseISODate("2026-08-01", calendar: cal)
        let grid = TimetableEngine.generateMonthGrid(for: aug2026, calendar: cal)

        // 1. Total cells must be a multiple of 7 (complete weeks)
        XCTAssertEqual(grid.count % 7, 0)
        XCTAssertEqual(grid.count, 42) // 6 leading + 31 days + 5 trailing = 42

        // 2. All IDs must be strictly unique
        let ids = grid.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Found duplicate IDs in calendar month grid")

        // 3. Dates 27, 28, 29, 30, 31 must be present with exact ISO format
        for day in 27...31 {
            let expectedIso = String(format: "2026-08-%02d", day)
            let cell = grid.first(where: { $0.dateIso == expectedIso })
            XCTAssertNotNil(cell, "Cell for \(expectedIso) was missing from grid")
            XCTAssertEqual(cell?.dayNumber, day)
            XCTAssertEqual(cell?.id, expectedIso)
        }

        // 4. Test February 2026 (28 days) and Leap Year February 2028 (29 days)
        let feb2026 = TimetableEngine.parseISODate("2026-02-01", calendar: cal)
        let feb2026Grid = TimetableEngine.generateMonthGrid(for: feb2026, calendar: cal)
        let feb2026Days = feb2026Grid.compactMap { $0.dayNumber }
        XCTAssertEqual(feb2026Days.count, 28)
        XCTAssertEqual(feb2026Days.last, 28)

        let feb2028 = TimetableEngine.parseISODate("2028-02-01", calendar: cal)
        let feb2028Grid = TimetableEngine.generateMonthGrid(for: feb2028, calendar: cal)
        let feb2028Days = feb2028Grid.compactMap { $0.dayNumber }
        XCTAssertEqual(feb2028Days.count, 29)
        XCTAssertEqual(feb2028Days.last, 29)
    }

    // MARK: - 12. Timetable Slot Mutation & Immediate Schedule Refresh

    func testTimetableSlotMutationRemovesMondayAndAddsTuesdayImmediately() {
        let sub = Subject(id: "sub-os", name: "Operating Systems", shortName: "OS", tint: "#30D158")
        let schMon = ClassSchedule(id: "sch-mon", subject: sub, weekday: 1, startTime: "09:00", endTime: "10:00", active: true)
        sub.schedules = [schMon]

        let sem = Semester(startDate: "2026-08-01", endDate: "2026-11-30")

        // 1. Monday Aug 10, 2026 has class
        let monClasses = TimetableEngine.getClassesForDate(
            dateIso: "2026-08-10", // Monday
            subjects: [sub],
            schedules: [schMon],
            occurrences: [],
            attendanceRecords: [],
            semester: sem,
            currentTime: Date()
        )
        XCTAssertEqual(monClasses.count, 1)

        // 2. Mutate schedule: Remove Monday, Add Tuesday
        schMon.active = false
        schMon.subject = nil
        let schTue = ClassSchedule(id: "sch-tue", subject: sub, weekday: 2, startTime: "10:00", endTime: "11:00", active: true)
        sub.schedules = [schTue]

        // 3. Monday Aug 10 must now have ZERO classes
        let updatedMonClasses = TimetableEngine.getClassesForDate(
            dateIso: "2026-08-10", // Monday
            subjects: [sub],
            schedules: [schTue],
            occurrences: [],
            attendanceRecords: [],
            semester: sem,
            currentTime: Date()
        )
        XCTAssertEqual(updatedMonClasses.count, 0, "Stale Monday schedule appeared after deleting Monday slot")

        // 4. Tuesday Aug 11 must now have 1 class
        let tueClasses = TimetableEngine.getClassesForDate(
            dateIso: "2026-08-11", // Tuesday
            subjects: [sub],
            schedules: [schTue],
            occurrences: [],
            attendanceRecords: [],
            semester: sem,
            currentTime: Date()
        )
        XCTAssertEqual(tueClasses.count, 1)
        XCTAssertEqual(tueClasses.first?.occurrence.startTime, "10:00")
    }

    // MARK: - 13. STAGE 5: End-to-End User Flow (10 Subjects, 100+ Records, Exceptions, Persistence)

    func testStage5FullUserFlow10Subjects100RecordsAndPersistence() throws {
        let schema = Schema([
            Subject.self,
            ClassSchedule.self,
            ClassOccurrence.self,
            AttendanceRecord.self,
            Semester.self,
            AcademicDayException.self,
            UserPreferences.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)
        let service = AttendanceService(context: context)

        // 1. Create Semester (Aug 3, 2026 – Dec 16, 2026)
        let sem = Semester(name: "Fall 2026", startDate: "2026-08-03", endDate: "2026-12-16")
        context.insert(sem)

        // 2. Set Preferences
        let prefs = UserPreferences(targetAttendance: 80, appearance: "dark", accentColor: "#FF9F0A")
        context.insert(prefs)

        // 3. Create 10 realistic subjects with recurring multi-slots
        var subjects: [Subject] = []
        let subjectData: [(String, String, String, String)] = [
            ("sub-1", "Compiler Design", "SSCD", "#0A84FF"),
            ("sub-2", "Network Security", "NSCL", "#5E5CE6"),
            ("sub-3", "Data Science", "DS", "#BF5AF2"),
            ("sub-4", "Big Data Analytics", "BDA", "#0A84FF"),
            ("sub-5", "Cloud Computing", "CC", "#30D158"),
            ("sub-6", "Machine Learning", "ML", "#FF9F0A"),
            ("sub-7", "Software Engineering", "SE", "#FF375F"),
            ("sub-8", "Database Systems", "DBMS", "#64D2FF"),
            ("sub-9", "Computer Networks", "CN", "#0A84FF"),
            ("sub-10", "Operating Systems", "OS", "#5E5CE6")
        ]

        var allSchedules: [ClassSchedule] = []
        for (id, name, short, tint) in subjectData {
            let sub = Subject(id: id, name: name, shortName: short, tint: tint)
            context.insert(sub)
            subjects.append(sub)

            // Slot 1: Monday
            let sch1 = ClassSchedule(id: "\(id)-sch-mon", subject: sub, weekday: 1, startTime: "09:30", endTime: "10:30", room: "LH-101")
            // Slot 2: Wednesday
            let sch2 = ClassSchedule(id: "\(id)-sch-wed", subject: sub, weekday: 3, startTime: "11:00", endTime: "12:00", room: "LH-101")
            sub.schedules = [sch1, sch2]
            context.insert(sch1)
            context.insert(sch2)
            allSchedules.append(contentsOf: [sch1, sch2])
        }

        try context.save()

        // 4. Create 120 attendance records across subjects and weeks
        var allOccurrences: [ClassOccurrence] = []
        var allRecords: [AttendanceRecord] = []

        var recCounter = 0
        for week in 1...12 {
            let dayNum = 3 + (week - 1) * 7 // Mondays in Aug/Sep/Oct/Nov
            let dateIso = String(format: "2026-08-%02d", min(dayNum, 31))
            for sub in subjects {
                recCounter += 1
                let occ = ClassOccurrence(
                    id: "occ-\(sub.id)-w\(week)",
                    subject: sub,
                    date: dateIso,
                    startTime: "09:30",
                    endTime: "10:30",
                    isExtra: false,
                    state: .conducted
                )
                context.insert(occ)
                allOccurrences.append(occ)

                let status: AttendanceStatus = (recCounter % 4 == 0) ? .missed : .present
                let rec = AttendanceRecord(id: "rec-\(occ.id)", occurrence: occ, status: status)
                context.insert(rec)
                allRecords.append(rec)
            }
        }

        // 5. Add Academic Day Exceptions
        try service.setDayException(date: "2026-08-15", type: .holiday, reason: "Independence Day")
        try service.setDayException(date: "2026-08-20", type: .leave, reason: "Medical Leave")
        try service.setDayException(date: "2026-08-27", type: .cie, reason: "CIE Exam Day")

        try context.save()

        // 6. Verify overall stats
        let overall = StatsEngine.calculateOverallStats(
            subjects: subjects,
            occurrences: allOccurrences,
            attendanceRecords: allRecords,
            schedules: allSchedules,
            semester: sem,
            target: 80
        )
        XCTAssertEqual(overall.totalConducted, 120)
        XCTAssertEqual(overall.present, 90) // 3/4 present = 75%
        XCTAssertEqual(overall.missed, 30)
        XCTAssertEqual(overall.pct, 75)
        XCTAssertEqual(overall.catchUpNeeded, 30) // Need 30 consecutive classes to reach 80% (120/150 = 80%)

        // 7. Verify subject-specific stats
        for sub in subjects {
            let subOccs = allOccurrences.filter { $0.subject?.id == sub.id }
            let subRecs = allRecords.filter { rec in
                rec.occurrence != nil && subOccs.contains(where: { $0.id == rec.occurrence!.id })
            }
            let subStats = StatsEngine.calculateSubjectStats(
                subjectId: sub.id,
                occurrences: subOccs,
                attendanceRecords: subRecs,
                schedules: allSchedules,
                semester: sem,
                target: 80
            )
            XCTAssertEqual(subStats.totalConducted, 12)
        }
    }

    // MARK: - 14. STAGE 5: Attendance Math, Changing Targets & Edge Cases

    func testStage5AttendanceMathTargetMatrixAndEdgeCases() {
        // Zero conducted: pct is nil, buffer 0, catchUp 0
        let zero = StatsEngine.calculateAttendanceMetrics(present: 0, missed: 0, target: 75)
        XCTAssertNil(zero.pct)
        XCTAssertEqual(zero.bunkBuffer, 0)
        XCTAssertEqual(zero.catchUpNeeded, 0)

        // 1/1 -> 100%, buffer: floor(100/75) - 1 = 1 - 1 = 0 (at 75%), catchUp 0
        let oneOfOne = StatsEngine.calculateAttendanceMetrics(present: 1, missed: 0, target: 75)
        XCTAssertEqual(oneOfOne.pct, 100)
        XCTAssertEqual(oneOfOne.bunkBuffer, 0)
        XCTAssertEqual(oneOfOne.catchUpNeeded, 0)

        // 0/1 -> 0%, buffer 0, catchUp: ceil((75*1 - 0)/25) = 3
        let zeroOfOne = StatsEngine.calculateAttendanceMetrics(present: 0, missed: 1, target: 75)
        XCTAssertEqual(zeroOfOne.pct, 0)
        XCTAssertEqual(zeroOfOne.bunkBuffer, 0)
        XCTAssertEqual(zeroOfOne.catchUpNeeded, 3)

        // 7/9 -> 77.7% -> rounded to 78%
        let sevenOfNine = StatsEngine.calculateAttendanceMetrics(present: 7, missed: 2, target: 75)
        XCTAssertEqual(sevenOfNine.pct, 78)
        XCTAssertEqual(sevenOfNine.bunkBuffer, 0) // floor(700/75) - 9 = 9 - 9 = 0
        XCTAssertEqual(sevenOfNine.catchUpNeeded, 0)

        // Changing Targets: 75, 80, 85, 90 on 100 conducted (85 present, 15 missed)
        // 85% attendance
        let t75 = StatsEngine.calculateAttendanceMetrics(present: 85, missed: 15, target: 75)
        XCTAssertEqual(t75.pct, 85)
        XCTAssertEqual(t75.bunkBuffer, 13) // floor(8500/75) - 100 = 113 - 100 = 13
        XCTAssertEqual(t75.catchUpNeeded, 0)

        let t80 = StatsEngine.calculateAttendanceMetrics(present: 85, missed: 15, target: 80)
        XCTAssertEqual(t80.pct, 85)
        XCTAssertEqual(t80.bunkBuffer, 6) // floor(8500/80) - 100 = 106 - 100 = 6
        XCTAssertEqual(t80.catchUpNeeded, 0)

        let t85 = StatsEngine.calculateAttendanceMetrics(present: 85, missed: 15, target: 85)
        XCTAssertEqual(t85.pct, 85)
        XCTAssertEqual(t85.bunkBuffer, 0) // floor(8500/85) - 100 = 100 - 100 = 0
        XCTAssertEqual(t85.catchUpNeeded, 0)

        let t90 = StatsEngine.calculateAttendanceMetrics(present: 85, missed: 15, target: 90)
        XCTAssertEqual(t90.pct, 85)
        XCTAssertEqual(t90.bunkBuffer, 0)
        XCTAssertEqual(t90.catchUpNeeded, 50) // ceil((90*100 - 85*100)/(10)) = ceil(500/10) = 50
    }

    // MARK: - 15. STAGE 5: Strict Semester Boundary Exclusions

    func testStage5SemesterBoundaryStrictExclusions() {
        let sub = Subject(id: "sub-ai", name: "AI", shortName: "AI", tint: "#0A84FF")
        let sch = ClassSchedule(id: "sch-ai", subject: sub, weekday: 1, startTime: "09:00", endTime: "10:00")
        sub.schedules = [sch]

        let sem = Semester(startDate: "2026-08-01", endDate: "2026-11-30")

        // 1. Occurrence before semester (2026-07-20)
        let beforeOcc = ClassOccurrence(id: "occ-before", subject: sub, date: "2026-07-20", startTime: "09:00", endTime: "10:00", isExtra: false, state: .conducted)
        let beforeRec = AttendanceRecord(id: "rec-before", occurrence: beforeOcc, status: .missed)

        // 2. Occurrence inside semester (2026-09-14)
        let insideOcc = ClassOccurrence(id: "occ-inside", subject: sub, date: "2026-09-14", startTime: "09:00", endTime: "10:00", isExtra: false, state: .conducted)
        let insideRec = AttendanceRecord(id: "rec-inside", occurrence: insideOcc, status: .present)

        // 3. Occurrence after semester (2026-12-15)
        let afterOcc = ClassOccurrence(id: "occ-after", subject: sub, date: "2026-12-15", startTime: "09:00", endTime: "10:00", isExtra: false, state: .conducted)
        let afterRec = AttendanceRecord(id: "rec-after", occurrence: afterOcc, status: .missed)

        let allOccs = [beforeOcc, insideOcc, afterOcc]
        let allRecs = [beforeRec, insideRec, afterRec]

        let stats = StatsEngine.calculateSubjectStats(
            subjectId: sub.id,
            occurrences: allOccs,
            attendanceRecords: allRecs,
            schedules: [sch],
            semester: sem,
            target: 75
        )

        // ONLY the inside occurrence (1 present, 0 missed = 100%) must count!
        XCTAssertEqual(stats.totalConducted, 1)
        XCTAssertEqual(stats.present, 1)
        XCTAssertEqual(stats.missed, 0)
        XCTAssertEqual(stats.pct, 100)
    }

    // MARK: - 16. STAGE 5: Subject-Specific Weekday Trend Filters

    func testStage5SubjectWeekdayTrendOnlyContainsScheduledDays() {
        let sub = Subject(id: "sub-cd", name: "Compiler Design", shortName: "CD", tint: "#0A84FF")
        // Scheduled ONLY on Tue (2), Wed (3), Thu (4)
        let schTue = ClassSchedule(id: "sch-tue", subject: sub, weekday: 2, startTime: "09:00", endTime: "10:00")
        let schWed = ClassSchedule(id: "sch-wed", subject: sub, weekday: 3, startTime: "10:00", endTime: "11:00")
        let schThu = ClassSchedule(id: "sch-thu", subject: sub, weekday: 4, startTime: "11:00", endTime: "12:00")
        sub.schedules = [schTue, schWed, schThu]

        let sem = Semester(startDate: "2026-08-01", endDate: "2026-11-30")

        let weekdayTrend = StatsEngine.calculateAttendanceByClassDay(
            subjectId: sub.id,
            subjects: [sub],
            schedules: [schTue, schWed, schThu],
            occurrences: [],
            attendanceRecords: [],
            dayExceptions: [],
            semester: sem
        )

        // Must contain EXACTLY 3 weekdays: Tuesday, Wednesday, Thursday
        XCTAssertEqual(weekdayTrend.count, 3)
        let weekdaysPresent = weekdayTrend.map { $0.weekday }
        XCTAssertEqual(weekdaysPresent, [2, 3, 4])
        XCTAssertFalse(weekdaysPresent.contains(1), "Monday should not appear for Compiler Design")
        XCTAssertFalse(weekdaysPresent.contains(5), "Friday should not appear for Compiler Design")
        XCTAssertFalse(weekdaysPresent.contains(6), "Saturday should not appear for Compiler Design")
        XCTAssertFalse(weekdaysPresent.contains(0), "Sunday should not appear for Compiler Design")
    }

    // MARK: - 17. STAGE 5: Settings Theme and Accent Colors Validation

    func testStage5SettingsAndThemePersistence() {
        let validAccents = [
            "#0A84FF", // Blue
            "#5E5CE6", // Indigo
            "#64D2FF", // Cyan
            "#30D158", // Green
            "#FF9F0A", // Orange
            "#FF375F", // Pink
            "#BF5AF2"  // Purple
        ]

        for accent in validAccents {
            let pref = UserPreferences(targetAttendance: 75, appearance: "dark", accentColor: accent)
            XCTAssertEqual(pref.accentColor, accent)
            XCTAssertEqual(pref.appearance, "dark")
        }

        let lightPref = UserPreferences(targetAttendance: 85, appearance: "light", accentColor: "#30D158")
        XCTAssertEqual(lightPref.appearance, "light")
        XCTAssertEqual(lightPref.targetAttendance, 85)
        XCTAssertEqual(lightPref.accentColor, "#30D158")
    }
}


