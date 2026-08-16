import Foundation
import SwiftData

@Model
public final class ClassSchedule {
    public var id: String = UUID().uuidString
    public var subject: Subject? = nil
    public var weekday: Int = 1
    public var startTime: String = "09:00"
    public var endTime: String = "10:00"
    public var room: String? = nil
    public var active: Bool = true
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: String = UUID().uuidString,
        subject: Subject? = nil,
        weekday: Int,
        startTime: String,
        endTime: String,
        room: String? = nil,
        active: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.subject = subject
        self.weekday = weekday
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.active = active
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
