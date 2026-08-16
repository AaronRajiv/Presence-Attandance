import Foundation
import SwiftData

public struct UndoSnapshot: Sendable {
    public enum ActionType: Sendable {
        case markedAttendance(occurrenceId: String, previousStatus: AttendanceStatus?, previousState: OccurrenceState, wasCreated: Bool)
        case cancelled(occurrenceId: String, previousState: OccurrenceState, wasCreated: Bool)
        case uncancelled(occurrenceId: String, previousReason: String?)
        case createdExtraClass(occurrenceId: String)
    }

    public let actionType: ActionType
    public let description: String

    public init(actionType: ActionType, description: String) {
        self.actionType = actionType
        self.description = description
    }
}

public final class AttendanceService {
    private let context: ModelContext
    public private(set) var lastUndoSnapshot: UndoSnapshot?

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Attendance Marking & Transitions

    public func markOccurrenceAttendance(
        item: DayClassItem,
        status: AttendanceStatus,
        notes: String? = nil
    ) throws {
        var occ = item.occurrence
        let wasVirtual = occ.id.hasPrefix("virt-")
        let previousState = occ.state
        let previousStatus = item.attendanceRecord?.status

        if wasVirtual {
            // Instantiate virtual slot into persistent SwiftData occurrence
            let newOcc = ClassOccurrence(
                subject: item.subject,
                scheduleId: occ.scheduleId,
                date: occ.date,
                startTime: occ.startTime,
                endTime: occ.endTime,
                room: occ.room,
                isExtra: false,
                state: .conducted
            )
            self.context.insert(newOcc)
            occ = newOcc
        } else {
            occ.state = .conducted
        }

        // Duplicate prevention: Check direct relationship, item.attendanceRecord, or context fetch
        var existingRecord = occ.attendanceRecord ?? item.attendanceRecord
        if existingRecord == nil {
            let occId = occ.id
            let recFetch = FetchDescriptor<AttendanceRecord>()
            let allRecs = (try? self.context.fetch(recFetch)) ?? []
            existingRecord = allRecs.first(where: { $0.occurrence?.id == occId })
        }

        if let existing = existingRecord {
            existing.status = status
            existing.notes = notes
            existing.updatedAt = Date()
            occ.attendanceRecord = existing
        } else {
            let record = AttendanceRecord(
                occurrence: occ,
                status: status,
                notes: notes
            )
            self.context.insert(record)
            occ.attendanceRecord = record
        }

        try self.context.save()

        let desc = "Marked \(item.subject.shortName) as \(status.rawValue.capitalized)"
        self.lastUndoSnapshot = UndoSnapshot(
            actionType: .markedAttendance(
                occurrenceId: occ.id,
                previousStatus: previousStatus,
                previousState: previousState,
                wasCreated: wasVirtual
            ),
            description: desc
        )
    }

    public func unmarkOccurrence(occurrenceId: String) throws {
        let occDescriptor = FetchDescriptor<ClassOccurrence>(predicate: #Predicate { $0.id == occurrenceId })
        guard let occ = try self.context.fetch(occDescriptor).first else { return }

        if let record = occ.attendanceRecord {
            self.context.delete(record)
            occ.attendanceRecord = nil
        }
        occ.state = .scheduled
        try self.context.save()
    }

    // MARK: - Class Cancellation

    public func cancelOccurrence(
        item: DayClassItem,
        reason: String? = "Class Cancelled"
    ) throws {
        var occ = item.occurrence
        let wasVirtual = occ.id.hasPrefix("virt-")
        let previousState = occ.state

        if wasVirtual {
            let newOcc = ClassOccurrence(
                subject: item.subject,
                scheduleId: occ.scheduleId,
                date: occ.date,
                startTime: occ.startTime,
                endTime: occ.endTime,
                room: occ.room,
                isExtra: false,
                state: .cancelled,
                cancellationReason: reason
            )
            self.context.insert(newOcc)
            occ = newOcc
        } else {
            occ.state = .cancelled
            occ.cancellationReason = reason
            if let record = occ.attendanceRecord {
                self.context.delete(record)
                occ.attendanceRecord = nil
            }
        }

        try self.context.save()

        let desc = "Cancelled \(item.subject.shortName) on \(occ.date)"
        self.lastUndoSnapshot = UndoSnapshot(
            actionType: .cancelled(
                occurrenceId: occ.id,
                previousState: previousState,
                wasCreated: wasVirtual
            ),
            description: desc
        )
    }

    public func uncancelOccurrence(occurrenceId: String) throws {
        let occDescriptor = FetchDescriptor<ClassOccurrence>(predicate: #Predicate { $0.id == occurrenceId })
        guard let occ = try self.context.fetch(occDescriptor).first else { return }

        let previousReason = occ.cancellationReason
        occ.state = .scheduled
        occ.cancellationReason = nil
        try self.context.save()

        let desc = "Restored class on \(occ.date)"
        self.lastUndoSnapshot = UndoSnapshot(
            actionType: .uncancelled(occurrenceId: occ.id, previousReason: previousReason),
            description: desc
        )
    }

    // MARK: - Extra Classes

    public func addExtraClass(
        subject: Subject,
        date: String,
        startTime: String,
        endTime: String,
        status: AttendanceStatus = .present,
        notes: String? = nil,
        room: String? = nil
    ) throws -> ClassOccurrence {
        let occ = ClassOccurrence(
            subject: subject,
            scheduleId: nil,
            date: date,
            startTime: startTime,
            endTime: endTime,
            room: room ?? subject.room,
            isExtra: true,
            state: .conducted
        )
        self.context.insert(occ)

        let record = AttendanceRecord(
            occurrence: occ,
            status: status,
            notes: notes
        )
        self.context.insert(record)
        occ.attendanceRecord = record

        try self.context.save()

        let desc = "Logged Extra Class for \(subject.shortName)"
        self.lastUndoSnapshot = UndoSnapshot(
            actionType: .createdExtraClass(occurrenceId: occ.id),
            description: desc
        )
        return occ
    }

    // MARK: - Academic Day Exceptions (Holiday & Leave)

    public func setDayException(
        date: String,
        type: DayExceptionType,
        reason: String? = nil
    ) throws {
        let descriptor = FetchDescriptor<AcademicDayException>(predicate: #Predicate { $0.date == date })
        let existing = try self.context.fetch(descriptor).first

        if let existing {
            existing.type = type
            existing.reason = reason
            existing.updatedAt = Date()
        } else {
            let newException = AcademicDayException(
                date: date,
                type: type,
                reason: reason
            )
            self.context.insert(newException)
        }

        try self.context.save()
    }

    public func removeDayException(date: String) throws {
        let descriptor = FetchDescriptor<AcademicDayException>(predicate: #Predicate { $0.date == date })
        let existing = try self.context.fetch(descriptor)
        for exc in existing {
            self.context.delete(exc)
        }
        try self.context.save()
    }

    // MARK: - Persistent Undo Restoration

    public func undoLastAction() throws -> Bool {
        guard let snapshot = self.lastUndoSnapshot else { return false }

        switch snapshot.actionType {
        case let .markedAttendance(occurrenceId, previousStatus, previousState, wasCreated):
            let descriptor = FetchDescriptor<ClassOccurrence>(predicate: #Predicate { $0.id == occurrenceId })
            if let occ = try self.context.fetch(descriptor).first {
                if wasCreated && previousStatus == nil {
                    // It was virtually created; remove completely
                    if let record = occ.attendanceRecord {
                        self.context.delete(record)
                    }
                    self.context.delete(occ)
                } else {
                    occ.state = previousState
                    if let prev = previousStatus {
                        if let record = occ.attendanceRecord {
                            record.status = prev
                        }
                    } else {
                        if let record = occ.attendanceRecord {
                            self.context.delete(record)
                            occ.attendanceRecord = nil
                        }
                    }
                }
            }

        case let .cancelled(occurrenceId, previousState, wasCreated):
            let descriptor = FetchDescriptor<ClassOccurrence>(predicate: #Predicate { $0.id == occurrenceId })
            if let occ = try self.context.fetch(descriptor).first {
                if wasCreated {
                    self.context.delete(occ)
                } else {
                    occ.state = previousState
                    occ.cancellationReason = nil
                }
            }

        case let .uncancelled(occurrenceId, previousReason):
            let descriptor = FetchDescriptor<ClassOccurrence>(predicate: #Predicate { $0.id == occurrenceId })
            if let occ = try self.context.fetch(descriptor).first {
                occ.state = .cancelled
                occ.cancellationReason = previousReason
            }

        case let .createdExtraClass(occurrenceId):
            let descriptor = FetchDescriptor<ClassOccurrence>(predicate: #Predicate { $0.id == occurrenceId })
            if let occ = try self.context.fetch(descriptor).first {
                if let record = occ.attendanceRecord {
                    self.context.delete(record)
                }
                self.context.delete(occ)
            }
        }

        try self.context.save()
        self.lastUndoSnapshot = nil
        return true
    }

    // MARK: - Subject Deletion with Cascade

    public func deleteSubject(subject: Subject) throws {
        // Cascade delete occurrences and attendance
        if let occurrences = subject.occurrences {
            for occ in occurrences {
                if let record = occ.attendanceRecord {
                    self.context.delete(record)
                }
                self.context.delete(occ)
            }
        }

        if let schedules = subject.schedules {
            for sch in schedules {
                self.context.delete(sch)
            }
        }

        self.context.delete(subject)
        try self.context.save()
    }

    // MARK: - Reset Attendance Records

    public func resetAllAttendanceRecords() throws {
        let recDescriptor = FetchDescriptor<AttendanceRecord>()
        let allRecords = try self.context.fetch(recDescriptor)
        for rec in allRecords {
            self.context.delete(rec)
        }

        let occDescriptor = FetchDescriptor<ClassOccurrence>()
        let allOccs = try self.context.fetch(occDescriptor)
        for occ in allOccs {
            self.context.delete(occ)
        }

        self.lastUndoSnapshot = nil
        try self.context.save()
    }
}

