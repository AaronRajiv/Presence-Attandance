import Foundation
import SwiftData

@Model
public final class Semester {
    public var id: String = "sem-current"
    public var name: String = "VII Semester"
    public var startDate: String = "2026-08-01" // ISO: YYYY-MM-DD
    public var endDate: String = "2026-12-31" // ISO: YYYY-MM-DD
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: String = "sem-current",
        name: String = "VII Semester",
        startDate: String = "2026-08-01",
        endDate: String = "2026-12-31",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
