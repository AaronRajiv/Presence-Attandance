import Foundation
import SwiftData

@Model
public final class Subject {
    public var id: String = UUID().uuidString
    public var name: String = ""
    public var shortName: String = ""
    public var courseCode: String? = nil
    public var lecturer: String? = nil
    public var room: String? = nil
    public var tint: String = "#0A84FF"
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ClassSchedule.subject)
    public var schedules: [ClassSchedule]? = []

    @Relationship(deleteRule: .cascade, inverse: \ClassOccurrence.subject)
    public var occurrences: [ClassOccurrence]? = []

    public init(
        id: String = UUID().uuidString,
        name: String,
        shortName: String,
        courseCode: String? = nil,
        lecturer: String? = nil,
        room: String? = nil,
        tint: String = "#0A84FF",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.courseCode = courseCode
        self.lecturer = lecturer
        self.room = room
        self.tint = tint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schedules = []
        self.occurrences = []
    }
}
