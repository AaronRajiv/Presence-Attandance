import Foundation

public struct AttendanceMetrics: Sendable, Equatable {
    public let pct: Int?
    public let totalConducted: Int
    public let bunkBuffer: Int
    public let catchUpNeeded: Int
    public let projectedPct: Int?

    public init(
        pct: Int?,
        totalConducted: Int,
        bunkBuffer: Int,
        catchUpNeeded: Int,
        projectedPct: Int?
    ) {
        self.pct = pct
        self.totalConducted = totalConducted
        self.bunkBuffer = bunkBuffer
        self.catchUpNeeded = catchUpNeeded
        self.projectedPct = projectedPct
    }
}

public struct SubjectStats: Sendable, Equatable {
    public let subjectId: String
    public let present: Int
    public let missed: Int
    public let totalConducted: Int
    public let pct: Int?
    public let bunkBuffer: Int
    public let catchUpNeeded: Int
    public let projectedPct: Int?
    public let totalScheduled: Int
    public let totalCancelled: Int

    public init(
        subjectId: String,
        present: Int,
        missed: Int,
        totalConducted: Int,
        pct: Int?,
        bunkBuffer: Int,
        catchUpNeeded: Int,
        projectedPct: Int?,
        totalScheduled: Int,
        totalCancelled: Int
    ) {
        self.subjectId = subjectId
        self.present = present
        self.missed = missed
        self.totalConducted = totalConducted
        self.pct = pct
        self.bunkBuffer = bunkBuffer
        self.catchUpNeeded = catchUpNeeded
        self.projectedPct = projectedPct
        self.totalScheduled = totalScheduled
        self.totalCancelled = totalCancelled
    }
}

public struct OverallStats: Sendable, Equatable {
    public let present: Int
    public let missed: Int
    public let totalConducted: Int
    public let pct: Int?
    public let bunkBuffer: Int
    public let catchUpNeeded: Int
    public let projectedPct: Int?
    public let totalScheduled: Int
    public let totalCancelled: Int

    public init(
        present: Int,
        missed: Int,
        totalConducted: Int,
        pct: Int?,
        bunkBuffer: Int,
        catchUpNeeded: Int,
        projectedPct: Int?,
        totalScheduled: Int,
        totalCancelled: Int
    ) {
        self.present = present
        self.missed = missed
        self.totalConducted = totalConducted
        self.pct = pct
        self.bunkBuffer = bunkBuffer
        self.catchUpNeeded = catchUpNeeded
        self.projectedPct = projectedPct
        self.totalScheduled = totalScheduled
        self.totalCancelled = totalCancelled
    }
}

public struct WeekdayTrendItem: Sendable, Equatable, Identifiable {
    public var id: Int { weekday }
    public let weekday: Int // 0=Sun, 1=Mon, ..., 6=Sat
    public let dayName: String
    public let shortLabel: String
    public let present: Int
    public let missed: Int
    public let totalConducted: Int
    public let pct: Int

    public init(
        weekday: Int,
        dayName: String,
        shortLabel: String,
        present: Int,
        missed: Int,
        totalConducted: Int,
        pct: Int
    ) {
        self.weekday = weekday
        self.dayName = dayName
        self.shortLabel = shortLabel
        self.present = present
        self.missed = missed
        self.totalConducted = totalConducted
        self.pct = pct
    }
}

public struct WeeklyBucket: Sendable, Equatable, Identifiable {
    public var id: String { label }
    public let label: String
    public let present: Int
    public let total: Int
    public let pct: Int

    public init(label: String, present: Int, total: Int, pct: Int) {
        self.label = label
        self.present = present
        self.total = total
        self.pct = pct
    }
}

public struct TrendPoint: Sendable, Equatable, Identifiable {
    public var id: String { label }
    public let label: String
    public let pct: Int

    public init(label: String, pct: Int) {
        self.label = label
        self.pct = pct
    }
}

public enum TrendRange: String, CaseIterable, Sendable {
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
}

public enum StatsEngine {
    public static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    public static let weekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public static func calculateAttendanceMetrics(
        present: Int,
        missed: Int,
        target: Int = 75,
        remainingScheduled: Int = 0
    ) -> AttendanceMetrics {
        let safePresent = max(0, present)
        let safeMissed = max(0, missed)
        let totalConducted = safePresent + safeMissed

        // Empty state: No conducted classes yet
        if totalConducted == 0 {
            return AttendanceMetrics(
                pct: nil,
                totalConducted: 0,
                bunkBuffer: 0,
                catchUpNeeded: 0,
                projectedPct: nil
            )
        }

        let rawPct = (Double(safePresent) / Double(totalConducted)) * 100.0
        let pct = Int(rawPct.rounded())

        // Safe Bunk Buffer: Maximum additional classes that can be missed while remaining >= target
        // Mathematical formula: Floor(100 * Present / Target) - Conducted
        var bunkBuffer = 0
        if target > 0 && target <= 100 {
            let maxTotal = Int(floor(Double(safePresent * 100) / Double(target)))
            bunkBuffer = max(0, maxTotal - totalConducted)
        }

        // Catch-Up Needed: Minimum consecutive classes that must be attended to reach target
        // Mathematical formula: Ceil((Target * Conducted - 100 * Present) / (100 - Target))
        var catchUpNeeded = 0
        if pct < target && target < 100 {
            let denom = 100 - target
            let numerator = target * totalConducted - 100 * safePresent
            if denom > 0 && numerator > 0 {
                catchUpNeeded = Int(ceil(Double(numerator) / Double(denom)))
            }
        }

        // Projected Percentage if all remaining scheduled classes are attended
        var projectedPct = pct
        let projTotal = totalConducted + remainingScheduled
        if projTotal > 0 {
            projectedPct = Int(round((Double(safePresent + remainingScheduled) / Double(projTotal)) * 100.0))
        }

        return AttendanceMetrics(
            pct: pct,
            totalConducted: totalConducted,
            bunkBuffer: bunkBuffer,
            catchUpNeeded: catchUpNeeded,
            projectedPct: projectedPct
        )
    }

    public static func countRemainingScheduledClasses(
        subjectId: String,
        schedules: [ClassSchedule],
        occurrences: [ClassOccurrence],
        dayExceptions: [AcademicDayException] = [],
        semester: Semester,
        fromDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let subSchedules = schedules.filter { sch in
            (sch.subject?.id == subjectId || sch.id.contains(subjectId)) && sch.active
        }
        if subSchedules.isEmpty { return 0 }

        let semesterEnd = TimetableEngine.parseISODate(semester.endDate, calendar: calendar)
        let semesterStart = TimetableEngine.parseISODate(semester.startDate, calendar: calendar)

        if fromDate >= semesterEnd { return 0 }

        let holidayDates = Set(dayExceptions.filter { $0.type == .holiday }.map { $0.date })

        var count = 0
        guard var current = calendar.date(byAdding: .day, value: 1, to: fromDate) else { return 0 }

        while current <= semesterEnd {
            if current >= semesterStart {
                let dateIso = TimetableEngine.formatISODate(current, calendar: calendar)
                if !holidayDates.contains(dateIso) {
                    let wd = TimetableEngine.weekdayIndex(for: current, calendar: calendar)
                    let matching = subSchedules.filter { $0.weekday == wd }
                    for sch in matching {
                        let existingOcc = occurrences.first { occ in
                            (occ.subject?.id == subjectId) && occ.date == dateIso && (occ.scheduleId == sch.id || occ.startTime == sch.startTime)
                        }

                        if let occ = existingOcc, occ.state == .cancelled || occ.state == .conducted {
                            continue
                        }

                        count += 1
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return count
    }

    public static func calculateSubjectStats(
        subjectId: String,
        occurrences: [ClassOccurrence],
        attendanceRecords: [AttendanceRecord],
        schedules: [ClassSchedule],
        dayExceptions: [AcademicDayException] = [],
        semester: Semester?,
        target: Int = 75,
        fromDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SubjectStats {
        let nonClassDates = Set(dayExceptions.filter { $0.type == .holiday || $0.type == .cie }.map { $0.date })

        let subOccurrences = occurrences.filter { occ in
            let match = occ.subject?.id == subjectId || (occ.subject == nil && occ.id.contains(subjectId))
            if !match { return false }
            if let sem = semester, (occ.date < sem.startDate || occ.date > sem.endDate) { return false }
            return true
        }

        // Filter out classes on college holidays / CIE exam days
        let conducted = subOccurrences.filter { $0.state == .conducted && !nonClassDates.contains($0.date) }
        let cancelledCount = subOccurrences.filter { $0.state == .cancelled }.count

        let conductedIds = Set(conducted.map { $0.id })
        let subAttendance = attendanceRecords.filter { rec in
            rec.occurrence != nil && conductedIds.contains(rec.occurrence!.id)
        }

        let present = subAttendance.filter { $0.status == .present }.count
        let missed = subAttendance.filter { $0.status == .missed }.count

        var remainingScheduled = 0
        if let sem = semester {
            remainingScheduled = countRemainingScheduledClasses(
                subjectId: subjectId,
                schedules: schedules,
                occurrences: subOccurrences,
                dayExceptions: dayExceptions,
                semester: sem,
                fromDate: fromDate,
                calendar: calendar
            )
        }

        let metrics = calculateAttendanceMetrics(
            present: present,
            missed: missed,
            target: target,
            remainingScheduled: remainingScheduled
        )

        return SubjectStats(
            subjectId: subjectId,
            present: present,
            missed: missed,
            totalConducted: metrics.totalConducted,
            pct: metrics.pct,
            bunkBuffer: metrics.bunkBuffer,
            catchUpNeeded: metrics.catchUpNeeded,
            projectedPct: metrics.projectedPct,
            totalScheduled: subOccurrences.count,
            totalCancelled: cancelledCount
        )
    }

    public static func calculateOverallStats(
        subjects: [Subject],
        occurrences: [ClassOccurrence],
        attendanceRecords: [AttendanceRecord],
        schedules: [ClassSchedule],
        dayExceptions: [AcademicDayException] = [],
        semester: Semester?,
        target: Int = 75,
        fromDate: Date = Date(),
        calendar: Calendar = .current
    ) -> OverallStats {
        let nonClassDates = Set(dayExceptions.filter { $0.type == .holiday || $0.type == .cie }.map { $0.date })

        let validOccurrences = occurrences.filter { occ in
            if let sem = semester, (occ.date < sem.startDate || occ.date > sem.endDate) { return false }
            return true
        }

        let conducted = validOccurrences.filter { $0.state == .conducted && !nonClassDates.contains($0.date) }
        let cancelledCount = validOccurrences.filter { $0.state == .cancelled }.count

        let conductedIds = Set(conducted.map { $0.id })
        let validAttendance = attendanceRecords.filter { rec in
            rec.occurrence != nil && conductedIds.contains(rec.occurrence!.id)
        }

        let present = validAttendance.filter { $0.status == .present }.count
        let missed = validAttendance.filter { $0.status == .missed }.count

        var totalRemaining = 0
        if let sem = semester {
            for sub in subjects {
                totalRemaining += countRemainingScheduledClasses(
                    subjectId: sub.id,
                    schedules: schedules,
                    occurrences: validOccurrences,
                    dayExceptions: dayExceptions,
                    semester: sem,
                    fromDate: fromDate,
                    calendar: calendar
                )
            }
        }

        let metrics = calculateAttendanceMetrics(
            present: present,
            missed: missed,
            target: target,
            remainingScheduled: totalRemaining
        )

        return OverallStats(
            present: present,
            missed: missed,
            totalConducted: metrics.totalConducted,
            pct: metrics.pct,
            bunkBuffer: metrics.bunkBuffer,
            catchUpNeeded: metrics.catchUpNeeded,
            projectedPct: metrics.projectedPct,
            totalScheduled: validOccurrences.count,
            totalCancelled: cancelledCount
        )
    }

    // MARK: - Attendance by Class Day (Subject & Overall Trend)

    public static func calculateAttendanceByClassDay(
        subjectId: String?,
        subjects: [Subject],
        schedules: [ClassSchedule],
        occurrences: [ClassOccurrence],
        attendanceRecords: [AttendanceRecord],
        dayExceptions: [AcademicDayException] = [],
        semester: Semester?,
        calendar: Calendar = .current
    ) -> [WeekdayTrendItem] {
        let nonClassDates = Set(dayExceptions.filter { $0.type == .holiday || $0.type == .cie }.map { $0.date })

        let targetSubjects = subjects.filter { sub in
            if let subId = subjectId, !subId.isEmpty {
                return sub.id == subId
            }
            return true
        }
        let targetSubjectIds = Set(targetSubjects.map { $0.id })

        // 1. Identify configured weekdays where classes are scheduled
        var activeWeekdays = Set<Int>()

        // From schedules
        for sch in schedules {
            if sch.active {
                if let sub = sch.subject, targetSubjectIds.contains(sub.id) {
                    activeWeekdays.insert(sch.weekday)
                } else if targetSubjects.contains(where: { $0.schedules?.contains(where: { $0.id == sch.id }) ?? false }) {
                    activeWeekdays.insert(sch.weekday)
                }
            }
        }
        for sub in targetSubjects {
            for sch in sub.schedules ?? [] {
                if sch.active {
                    activeWeekdays.insert(sch.weekday)
                }
            }
        }

        // Also check if any occurrences exist for these subjects
        let relevantOccurrences = occurrences.filter { occ in
            let match = (occ.subject != nil && targetSubjectIds.contains(occ.subject!.id)) || (targetSubjectIds.contains(where: { occ.id.contains($0) }))
            if !match { return false }
            if let sem = semester, (occ.date < sem.startDate || occ.date > sem.endDate) { return false }
            return true
        }

        for occ in relevantOccurrences {
            let d = TimetableEngine.parseISODate(occ.date, calendar: calendar)
            let wd = TimetableEngine.weekdayIndex(for: d, calendar: calendar)
            activeWeekdays.insert(wd)
        }

        if activeWeekdays.isEmpty {
            return []
        }

        // 2. Count conducted attendance per weekday
        var presentMap = [Int: Int]()
        var missedMap = [Int: Int]()

        let attendanceMap = Dictionary(uniqueKeysWithValues: attendanceRecords.compactMap {
            $0.occurrence != nil ? ($0.occurrence!.id, $0.status) : nil
        })

        for occ in relevantOccurrences {
            // Cancelled classes or classes on holidays / CIE do NOT count as conducted/missed
            if occ.state == .cancelled || nonClassDates.contains(occ.date) { continue }
            if occ.state != .conducted { continue }

            guard let status = attendanceMap[occ.id] ?? occ.attendanceRecord?.status else { continue }
            let d = TimetableEngine.parseISODate(occ.date, calendar: calendar)
            let wd = TimetableEngine.weekdayIndex(for: d, calendar: calendar)

            if status == .present {
                presentMap[wd, default: 0] += 1
            } else if status == .missed {
                missedMap[wd, default: 0] += 1
            }
        }

        // 3. Build items only for active weekdays, sorted Monday (1) -> Sunday (0)
        let sortedWeekdays = activeWeekdays.sorted { a, b in
            let orderA = (a == 0 ? 7 : a) // Convert Sunday (0) to 7 for Monday-first sort
            let orderB = (b == 0 ? 7 : b)
            return orderA < orderB
        }

        return sortedWeekdays.map { wd in
            let p = presentMap[wd, default: 0]
            let m = missedMap[wd, default: 0]
            let tot = p + m
            let pct = tot == 0 ? 0 : Int(round((Double(p) / Double(tot)) * 100.0))
            return WeekdayTrendItem(
                weekday: wd,
                dayName: weekdayNames[wd],
                shortLabel: weekdayShort[wd],
                present: p,
                missed: m,
                totalConducted: tot,
                pct: pct
            )
        }
    }

    // Retain legacy method signature for compatibility
    public static func calculateAttendanceTrend(
        occurrences: [ClassOccurrence],
        attendanceRecords: [AttendanceRecord],
        range: TrendRange,
        semester: Semester? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TrendPoint] {
        let conducted = occurrences.filter { occ in
            if occ.state != .conducted { return false }
            if let sem = semester, (occ.date < sem.startDate || occ.date > sem.endDate) { return false }
            return true
        }
        if conducted.isEmpty { return [] }

        let days = range == .week ? 7 : range == .month ? 30 : 120
        let buckets = range == .sixMonths ? 12 : range == .month ? 10 : 7
        let step = max(1, Int(ceil(Double(days) / Double(buckets))))

        let attendanceMap = Dictionary(uniqueKeysWithValues: attendanceRecords.compactMap {
            $0.occurrence != nil ? ($0.occurrence!.id, $0.status) : nil
        })

        var out: [TrendPoint] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = range == .week ? "E" : "MMM d"

        for b in (0..<buckets).reversed() {
            guard let sliceEnd = calendar.date(byAdding: .day, value: -(b * step), to: now) else { continue }
            let sliceEndIso = TimetableEngine.formatISODate(sliceEnd, calendar: calendar)

            let sliceOccurrences = conducted.filter { $0.date <= sliceEndIso }

            var present = 0
            var total = 0

            for occ in sliceOccurrences {
                guard let status = attendanceMap[occ.id] ?? occ.attendanceRecord?.status else { continue }
                total += 1
                if status == .present {
                    present += 1
                }
            }

            let label = dateFormatter.string(from: sliceEnd)
            let pct = total == 0 ? 0 : Int(round((Double(present) / Double(total)) * 100.0))
            out.append(TrendPoint(label: label, pct: pct))
        }

        return out
    }

    public static func calculateWeeklyDistribution(
        occurrences: [ClassOccurrence],
        attendanceRecords: [AttendanceRecord],
        semester: Semester? = nil,
        calendar: Calendar = .current
    ) -> [WeeklyBucket] {
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var presentCounts = Array(repeating: 0, count: 7)
        var totalCounts = Array(repeating: 0, count: 7)

        let attendanceMap = Dictionary(uniqueKeysWithValues: attendanceRecords.compactMap {
            $0.occurrence != nil ? ($0.occurrence!.id, $0.status) : nil
        })

        for occ in occurrences {
            if occ.state != .conducted { continue }
            if let sem = semester, (occ.date < sem.startDate || occ.date > sem.endDate) { continue }
            guard let status = attendanceMap[occ.id] ?? occ.attendanceRecord?.status else { continue }

            let d = TimetableEngine.parseISODate(occ.date, calendar: calendar)
            let wd = TimetableEngine.weekdayIndex(for: d, calendar: calendar)
            if wd >= 0 && wd < 7 {
                totalCounts[wd] += 1
                if status == .present {
                    presentCounts[wd] += 1
                }
            }
        }

        return (0..<7).map { i in
            let tot = totalCounts[i]
            let pres = presentCounts[i]
            let pct = tot == 0 ? 0 : Int(round((Double(pres) / Double(tot)) * 100.0))
            return WeeklyBucket(label: dayLabels[i], present: pres, total: tot, pct: pct)
        }
    }
}
