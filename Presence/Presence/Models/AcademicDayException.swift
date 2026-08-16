import Foundation
import SwiftData

public enum DayExceptionType: String, Codable, Sendable, CaseIterable {
    case holiday = "holiday"
    case leave = "leave"
    case cie = "cie"

    public var title: String {
        switch self {
        case .holiday: return "College Holiday"
        case .leave: return "Personal Leave"
        case .cie: return "CIE Exam Day"
        }
    }

    public var icon: String {
        switch self {
        case .holiday: return "sun.max.fill"
        case .leave: return "person.badge.shield.checkmark.fill"
        case .cie: return "doc.text.fill"
        }
    }
}

@Model
public final class AcademicDayException {
    public var id: String = UUID().uuidString
    public var date: String = "" // ISO "YYYY-MM-DD"
    public var typeRaw: String = "holiday"
    public var reason: String? = nil
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var type: DayExceptionType {
        get { DayExceptionType(rawValue: typeRaw) ?? .holiday }
        set { typeRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        date: String,
        type: DayExceptionType,
        reason: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.typeRaw = type.rawValue
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
