import Foundation
import SwiftData

public enum OccurrenceState: String, Codable, CaseIterable, Sendable {
    case scheduled = "scheduled"
    case conducted = "conducted"
    case cancelled = "cancelled"
}

@Model
public final class ClassOccurrence {
    public var id: String = UUID().uuidString
    public var subject: Subject? = nil
    public var scheduleId: String? = nil
    public var date: String = "" // ISO: YYYY-MM-DD
    public var startTime: String = "" // HH:mm
    public var endTime: String = "" // HH:mm
    public var room: String? = nil
    public var isExtra: Bool = false
    public var stateRaw: String = "scheduled"
    public var cancellationReason: String? = nil
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \AttendanceRecord.occurrence)
    public var attendanceRecord: AttendanceRecord? = nil

    public var state: OccurrenceState {
        get { OccurrenceState(rawValue: stateRaw) ?? .scheduled }
        set { stateRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        subject: Subject? = nil,
        scheduleId: String? = nil,
        date: String,
        startTime: String,
        endTime: String,
        room: String? = nil,
        isExtra: Bool = false,
        state: OccurrenceState = .scheduled,
        cancellationReason: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.subject = subject
        self.scheduleId = scheduleId
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.isExtra = isExtra
        self.stateRaw = state.rawValue
        self.cancellationReason = cancellationReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
