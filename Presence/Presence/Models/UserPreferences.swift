import Foundation
import SwiftData

@Model
public final class UserPreferences {
    public var id: String = "pref-default"
    public var targetAttendance: Int = 75
    public var reminderMinutes: Int = 15
    public var notificationsEnabled: Bool = true
    public var iCloudSyncEnabled: Bool = true
    public var appearance: String = "dark"
    public var accentColor: String? = "#0A84FF"
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: String = "pref-default",
        targetAttendance: Int = 75,
        reminderMinutes: Int = 15,
        notificationsEnabled: Bool = true,
        iCloudSyncEnabled: Bool = true,
        appearance: String = "dark",
        accentColor: String? = "#0A84FF",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.targetAttendance = targetAttendance
        self.reminderMinutes = reminderMinutes
        self.notificationsEnabled = notificationsEnabled
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.appearance = appearance
        self.accentColor = accentColor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
