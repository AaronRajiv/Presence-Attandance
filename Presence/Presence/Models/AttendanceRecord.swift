import Foundation
import SwiftData

public enum AttendanceStatus: String, Codable, CaseIterable, Sendable {
    case present = "present"
    case missed = "missed"
}

@Model
public final class AttendanceRecord {
    public var id: String = UUID().uuidString
    public var occurrence: ClassOccurrence? = nil
    public var statusRaw: String = "present"
    public var notes: String? = nil
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var status: AttendanceStatus {
        get { AttendanceStatus(rawValue: statusRaw) ?? .present }
        set { statusRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        occurrence: ClassOccurrence? = nil,
        status: AttendanceStatus = .present,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.occurrence = occurrence
        self.statusRaw = status.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
