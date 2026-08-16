import Foundation
import SwiftData

public struct DayClassItem: Identifiable {
    public var id: String { occurrence.id }
    public let occurrence: ClassOccurrence
    public let subject: Subject
    public let attendanceRecord: AttendanceRecord?
    public let isOngoing: Bool
    public let isUpcoming: Bool
    public let isPast: Bool

    public init(
        occurrence: ClassOccurrence,
        subject: Subject,
        attendanceRecord: AttendanceRecord?,
        isOngoing: Bool,
        isUpcoming: Bool,
        isPast: Bool
    ) {
        self.occurrence = occurrence
        self.subject = subject
        self.attendanceRecord = attendanceRecord
        self.isOngoing = isOngoing
        self.isUpcoming = isUpcoming
        self.isPast = isPast
    }
}

public struct NextClassResult: Equatable {
    public let date: Date
    public let dateIso: String
    public let label: String
    public let time: String
    public let room: String

    public init(date: Date, dateIso: String, label: String, time: String, room: String) {
        self.date = date
        self.dateIso = dateIso
        self.label = label
        self.time = time
        self.room = room
    }
}

public struct NextOverallClassResult {
    public let subject: Subject
    public let date: Date
    public let dateIso: String
    public let label: String
    public let time: String
    public let room: String
    public let isToday: Bool

    public init(
        subject: Subject,
        date: Date,
        dateIso: String,
        label: String,
        time: String,
        room: String,
        isToday: Bool
    ) {
        self.subject = subject
        self.date = date
        self.dateIso = dateIso
        self.label = label
        self.time = time
        self.room = room
        self.isToday = isToday
    }
}

public struct LiveDayStatus {
    public let todayClasses: [DayClassItem]
    public let ongoing: DayClassItem?
    public let nextClassToday: DayClassItem?
    public let upcomingToday: [DayClassItem]
    public let unloggedPast: [DayClassItem]
    public let hasClassesToday: Bool
    public let allConcludedToday: Bool
    public let nextOverall: NextOverallClassResult?

    public init(
        todayClasses: [DayClassItem],
        ongoing: DayClassItem?,
        nextClassToday: DayClassItem?,
        upcomingToday: [DayClassItem],
        unloggedPast: [DayClassItem],
        hasClassesToday: Bool,
        allConcludedToday: Bool,
        nextOverall: NextOverallClassResult?
    ) {
        self.todayClasses = todayClasses
        self.ongoing = ongoing
        self.nextClassToday = nextClassToday
        self.upcomingToday = upcomingToday
        self.unloggedPast = unloggedPast
        self.hasClassesToday = hasClassesToday
        self.allConcludedToday = allConcludedToday
        self.nextOverall = nextOverall
    }
}

public enum TimetableEngine {
    public static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    public static let dayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    public static func formatISODate(_ date: Date, calendar: Calendar = .current) -> String {
        let y = calendar.component(.year, from: date)
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    public static func parseISODate(_ iso: String, calendar: Calendar = .current) -> Date {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 3 else { return Date() }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        comps.hour = 12
        comps.minute = 0
        return calendar.date(from: comps) ?? Date()
    }

    public static func parseTimeInMinutes(_ timeStr: String) -> Int {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        let hours = parts[0]
        let minutes = parts[1]
        return hours * 60 + minutes
    }

    public static func formatTimeFromMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    public static func isDateWithinSemester(_ dateIso: String, semester: Semester?) -> Bool {
        guard let semester else { return true }
        return dateIso >= semester.startDate && dateIso <= semester.endDate
    }

    // MARK: - Time Conversion Helpers

    public static func formatTime12Hour(from time24: String) -> String {
        let trimmed = time24.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else {
            return time24
        }
        let period = h >= 12 ? "PM" : "AM"
        let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", hour12, m, period)
    }

    public static func formatTime24Hour(from date: Date, calendar: Calendar = .current) -> String {
        let h = calendar.component(.hour, from: date)
        let m = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", h, m)
    }

    public static func dateFromTime24(_ time24: String, calendar: Calendar = .current) -> Date {
        let trimmed = time24.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":")
        let h = parts.count >= 1 ? (Int(parts[0]) ?? 9) : 9
        let m = parts.count >= 2 ? (Int(parts[1]) ?? 0) : 0
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h
        comps.minute = m
        comps.second = 0
        return calendar.date(from: comps) ?? Date()
    }

    public static func weekdayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        // Swift calendar: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let calWeekday = calendar.component(.weekday, from: date)
        return (calWeekday - 1) // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    }

    public static func getClassesForDate(
        dateIso: String,
        subjects: [Subject],
        schedules: [ClassSchedule],
        occurrences: [ClassOccurrence],
        attendanceRecords: [AttendanceRecord],
        semester: Semester?,
        currentTime: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayClassItem] {
        let targetDate = parseISODate(dateIso, calendar: calendar)
        let weekday = weekdayIndex(for: targetDate, calendar: calendar)
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        
        var attendanceMap: [String: AttendanceRecord] = [:]
        for rec in attendanceRecords {
            if let occId = rec.occurrence?.id {
                attendanceMap[occId] = rec
            }
        }

        let currentIso = formatISODate(currentTime, calendar: calendar)
        let isToday = dateIso == currentIso
        let currentMinutes = calendar.component(.hour, from: currentTime) * 60 + calendar.component(.minute, from: currentTime)

        let isWithinTerm = isDateWithinSemester(dateIso, semester: semester)
        var items: [DayClassItem] = []

        // Map occurrences to subjects using only in-memory lookups to avoid triggering database relationship faults on main thread
        var occurrenceSubjectMap: [String: Subject] = [:]
        for occ in occurrences {
            if let subId = occ.subject?.id, let sub = subjectMap[subId] {
                occurrenceSubjectMap[occ.id] = sub
            }
        }

        // 1. Existing stored occurrences for this date
        let dateOccurrences = occurrences.filter { $0.date == dateIso }
        for occ in dateOccurrences {
            guard let sub = occurrenceSubjectMap[occ.id] ?? (occ.subject != nil ? subjectMap[occ.subject!.id] : nil) else {
                continue
            }

            let startMin = parseTimeInMinutes(occ.startTime)
            let endMin = parseTimeInMinutes(occ.endTime) > 0 ? parseTimeInMinutes(occ.endTime) : startMin + 60

            var isOngoing = false
            var isUpcoming = false
            var isPast = false

            if isToday {
                isOngoing = currentMinutes >= startMin && currentMinutes < endMin
                isUpcoming = currentMinutes < startMin
                isPast = currentMinutes >= endMin
            } else {
                isPast = targetDate < parseISODate(currentIso, calendar: calendar)
                isUpcoming = targetDate > parseISODate(currentIso, calendar: calendar)
            }

            let attRecord = occ.attendanceRecord ?? attendanceMap[occ.id]
            items.append(DayClassItem(
                occurrence: occ,
                subject: sub,
                attendanceRecord: attRecord,
                isOngoing: isOngoing,
                isUpcoming: isUpcoming,
                isPast: isPast
            ))
        }

        // 2. Regular weekly schedules if date is within semester and not already instantiated as an occurrence
        if isWithinTerm {
            var subjectSchedulesMap: [String: [ClassSchedule]] = [:]
            for sch in schedules {
                if let subId = sch.subject?.id {
                    subjectSchedulesMap[subId, default: []].append(sch)
                }
            }

            for sub in subjects {
                let subjectActiveSchedules = (subjectSchedulesMap[sub.id] ?? []).filter { $0.active && $0.weekday == weekday }

                for sch in subjectActiveSchedules {
                    let alreadyCovered = dateOccurrences.contains { occ in
                        occ.scheduleId == sch.id || (occ.subject?.id == sub.id && occ.startTime == sch.startTime)
                    }
                    if alreadyCovered { continue }

                    let startMin = parseTimeInMinutes(sch.startTime)
                    let endMin = parseTimeInMinutes(sch.endTime) > 0 ? parseTimeInMinutes(sch.endTime) : startMin + 60

                    var isOngoing = false
                    var isUpcoming = false
                    var isPast = false

                    if isToday {
                        isOngoing = currentMinutes >= startMin && currentMinutes < endMin
                        isUpcoming = currentMinutes < startMin
                        isPast = currentMinutes >= endMin
                    } else {
                        isPast = targetDate < parseISODate(currentIso, calendar: calendar)
                        isUpcoming = targetDate > parseISODate(currentIso, calendar: calendar)
                    }

                    let virtualOcc = ClassOccurrence(
                        id: "virt-\(sub.id)-\(dateIso)-\(sch.id)",
                        subject: nil,
                        scheduleId: sch.id,
                        date: dateIso,
                        startTime: sch.startTime,
                        endTime: sch.endTime,
                        room: sch.room ?? sub.room,
                        isExtra: false,
                        state: .scheduled
                    )

                    items.append(DayClassItem(
                        occurrence: virtualOcc,
                        subject: sub,
                        attendanceRecord: nil,
                        isOngoing: isOngoing,
                        isUpcoming: isUpcoming,
                        isPast: isPast
                    ))
                }
            }
        }

        return items.sorted { $0.occurrence.startTime < $1.occurrence.startTime }
    }

    public static func getNextClassForSubject(
        subject: Subject,
        schedules: [ClassSchedule],
        semester: Semester?,
        occurrences: [ClassOccurrence] = [],
        from: Date = Date(),
        calendar: Calendar = .current
    ) -> NextClassResult {
        let subSchedules = schedules.filter { sch in
            (sch.subject?.id == subject.id) && sch.active
        }
        if subSchedules.isEmpty {
            return NextClassResult(
                date: from,
                dateIso: formatISODate(from, calendar: calendar),
                label: "No schedule",
                time: "—",
                room: subject.room ?? "—"
            )
        }

        let currentMinutes = calendar.component(.hour, from: from) * 60 + calendar.component(.minute, from: from)

        for i in 0..<14 {
            guard let d = calendar.date(byAdding: .day, value: i, to: from) else { continue }
            let dateIso = formatISODate(d, calendar: calendar)

            if !isDateWithinSemester(dateIso, semester: semester) { continue }

            let dayOfWeek = weekdayIndex(for: d, calendar: calendar)
            let matching = subSchedules
                .filter { $0.weekday == dayOfWeek }
                .sorted { $0.startTime < $1.startTime }

            for sch in matching {
                let existingOcc = occurrences.first { occ in
                    (occ.subject?.id == subject.id) && occ.date == dateIso && (occ.scheduleId == sch.id || occ.startTime == sch.startTime)
                }
                if let occ = existingOcc, occ.state == .cancelled {
                    continue
                }

                if i == 0 {
                    let schMin = parseTimeInMinutes(sch.startTime)
                    if schMin >= currentMinutes {
                        return NextClassResult(
                            date: d,
                            dateIso: dateIso,
                            label: "Today · \(sch.startTime)",
                            time: sch.startTime,
                            room: sch.room ?? subject.room ?? "—"
                        )
                    }
                } else {
                    let label = i == 1 ? "Tomorrow · \(sch.startTime)" : "\(dayNames[dayOfWeek]) · \(sch.startTime)"
                    return NextClassResult(
                        date: d,
                        dateIso: dateIso,
                        label: label,
                        time: sch.startTime,
                        room: sch.room ?? subject.room ?? "—"
                    )
                }
            }
        }

        let sorted = subSchedules.sorted {
            if $0.weekday != $1.weekday { return $0.weekday < $1.weekday }
            return $0.startTime < $1.startTime
        }
        if let first = sorted.first {
            return NextClassResult(
                date: from,
                dateIso: formatISODate(from, calendar: calendar),
                label: "\(dayNames[first.weekday]) · \(first.startTime)",
                time: first.startTime,
                room: first.room ?? subject.room ?? "—"
            )
        }

        return NextClassResult(
            date: from,
            dateIso: formatISODate(from, calendar: calendar),
            label: "No schedule",
            time: "—",
            room: subject.room ?? "—"
        )
    }

    public static func getNextClassAcrossAllSubjects(
        subjects: [Subject],
        schedules: [ClassSchedule],
        semester: Semester?,
        occurrences: [ClassOccurrence] = [],
        from: Date = Date(),
        calendar: Calendar = .current
    ) -> NextOverallClassResult? {
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        let currentMinutes = calendar.component(.hour, from: from) * 60 + calendar.component(.minute, from: from)

        for i in 0..<14 {
            guard let d = calendar.date(byAdding: .day, value: i, to: from) else { continue }
            let dateIso = formatISODate(d, calendar: calendar)

            if !isDateWithinSemester(dateIso, semester: semester) { continue }

            let dayOfWeek = weekdayIndex(for: d, calendar: calendar)
            let matching = schedules
                .filter { $0.active && $0.weekday == dayOfWeek }
                .sorted { $0.startTime < $1.startTime }

            for sch in matching {
                guard let sub = (sch.subject != nil ? subjectMap[sch.subject!.id] : nil) ?? sch.subject else {
                    continue
                }

                let existingOcc = occurrences.first { occ in
                    (occ.subject?.id == sub.id) && occ.date == dateIso && (occ.scheduleId == sch.id || occ.startTime == sch.startTime)
                }
                if let occ = existingOcc, occ.state == .cancelled {
                    continue
                }

                if i == 0 {
                    let schMin = parseTimeInMinutes(sch.startTime)
                    if schMin >= currentMinutes {
                        return NextOverallClassResult(
                            subject: sub,
                            date: d,
                            dateIso: dateIso,
                            label: "Today at \(sch.startTime)",
                            time: sch.startTime,
                            room: sch.room ?? sub.room ?? "Classroom",
                            isToday: true
                        )
                    }
                } else {
                    let label = i == 1 ? "Tomorrow at \(sch.startTime)" : "\(dayNames[dayOfWeek]) at \(sch.startTime)"
                    return NextOverallClassResult(
                        subject: sub,
                        date: d,
                        dateIso: dateIso,
                        label: label,
                        time: sch.startTime,
                        room: sch.room ?? sub.room ?? "Classroom",
                        isToday: false
                    )
                }
            }
        }

        return nil
    }

    public static func getLiveDayStatus(
        subjects: [Subject],
        schedules: [ClassSchedule],
        occurrences: [ClassOccurrence],
        attendanceRecords: [AttendanceRecord],
        semester: Semester?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> LiveDayStatus {
        let todayIso = formatISODate(now, calendar: calendar)
        let todayClasses = getClassesForDate(
            dateIso: todayIso,
            subjects: subjects,
            schedules: schedules,
            occurrences: occurrences,
            attendanceRecords: attendanceRecords,
            semester: semester,
            currentTime: now,
            calendar: calendar
        )

        let ongoing = todayClasses.first { $0.isOngoing && $0.occurrence.state != .cancelled }
        let upcomingToday = todayClasses.filter { $0.isUpcoming && $0.occurrence.state != .cancelled }
        let nextClassToday = upcomingToday.first
        let unloggedPast = todayClasses.filter { $0.isPast && $0.occurrence.state == .scheduled }

        let hasClassesToday = !todayClasses.isEmpty
        let allConcludedToday = hasClassesToday && ongoing == nil && nextClassToday == nil

        let nextOverall = getNextClassAcrossAllSubjects(
            subjects: subjects,
            schedules: schedules,
            semester: semester,
            occurrences: occurrences,
            from: now,
            calendar: calendar
        )

        return LiveDayStatus(
            todayClasses: todayClasses,
            ongoing: ongoing,
            nextClassToday: nextClassToday,
            upcomingToday: upcomingToday,
            unloggedPast: unloggedPast,
            hasClassesToday: hasClassesToday,
            allConcludedToday: allConcludedToday,
            nextOverall: nextOverall
        )
    }

    // MARK: - Human Readable Date Range Formatter

    public static func formatDateRangeHuman(
        startIso: String,
        endIso: String,
        calendar: Calendar = .current
    ) -> String {
        let start = parseISODate(startIso, calendar: calendar)
        let end = parseISODate(endIso, calendar: calendar)

        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar

        if startYear == endYear {
            // Same year: "3 August – 16 December"
            dayFormatter.dateFormat = "d MMMM"
            let startStr = dayFormatter.string(from: start)
            let endStr = dayFormatter.string(from: end)
            return "\(startStr) – \(endStr)"
        } else {
            // Crosses years: "3 August 2026 – 16 January 2027"
            dayFormatter.dateFormat = "d MMMM yyyy"
            let startStr = dayFormatter.string(from: start)
            let endStr = dayFormatter.string(from: end)
            return "\(startStr) – \(endStr)"
        }
    }

    // MARK: - Calendar Month Grid Generator

    public static func generateMonthGrid(for monthDate: Date, calendar: Calendar = .current) -> [CalendarDayModel] {
        var cal = calendar
        cal.timeZone = TimeZone.current

        let comps = cal.dateComponents([.year, .month], from: monthDate)
        guard let monthFirstDay = cal.date(from: comps),
              let year = comps.year,
              let month = comps.month else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: monthFirstDay) - 1 // 0 = Sunday, 6 = Saturday
        let numberOfDays = cal.range(of: .day, in: .month, for: monthFirstDay)?.count ?? 0

        var grid: [CalendarDayModel] = []
        grid.reserveCapacity(42)

        // 1. Leading empty cells with UNIQUE deterministic IDs
        for leadIdx in 0..<firstWeekday {
            grid.append(CalendarDayModel(
                id: "empty-lead-\(year)-\(month)-\(leadIdx)",
                date: nil,
                dateIso: nil,
                dayNumber: nil
            ))
        }

        // 2. Days in month
        for day in 1...numberOfDays {
            if let dayDate = cal.date(byAdding: .day, value: day - 1, to: monthFirstDay) {
                let dayIso = String(format: "%04d-%02d-%02d", year, month, day)
                grid.append(CalendarDayModel(
                    id: dayIso,
                    date: dayDate,
                    dateIso: dayIso,
                    dayNumber: day
                ))
            }
        }

        // 3. Trailing empty cells to complete the grid row
        let remainder = grid.count % 7
        if remainder != 0 {
            let trailCount = 7 - remainder
            for trailIdx in 0..<trailCount {
                grid.append(CalendarDayModel(
                    id: "empty-trail-\(year)-\(month)-\(trailIdx)",
                    date: nil,
                    dateIso: nil,
                    dayNumber: nil
                ))
            }
        }

        return grid
    }
}

public struct CalendarDayModel: Identifiable, Hashable, Sendable {
    public let id: String
    public let date: Date?
    public let dateIso: String?
    public let dayNumber: Int?

    public init(id: String, date: Date? = nil, dateIso: String? = nil, dayNumber: Int? = nil) {
        self.id = id
        self.date = date
        self.dateIso = dateIso
        self.dayNumber = dayNumber
    }
}


