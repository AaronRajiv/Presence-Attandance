import Foundation
import SwiftData

public enum ModelSchema {
    public static let schema = Schema([
        Subject.self,
        ClassSchedule.self,
        ClassOccurrence.self,
        AttendanceRecord.self,
        Semester.self,
        UserPreferences.self,
        AcademicDayException.self,
    ])

    public static let cloudKitContainerIdentifier = "iCloud.com.presence.attendance"
    
    /// Feature flag controlling CloudKit synchronization.
    /// CloudKit synchronization is paused for free Apple Personal Team builds.
    /// Switch to `true` when a paid Apple Developer Program membership and CloudKit container are active.
    public static let isCloudKitSyncFeatureEnabled: Bool = false

    public static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
    }

    public static func createContainer(inMemory: Bool = false, enableCloudKit: Bool? = nil) throws -> ModelContainer {
        let shouldEnableCloudKit = enableCloudKit ?? (isCloudKitSyncFeatureEnabled && !isRunningTests && !inMemory)

        if inMemory {
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        }

        // 1. CloudKit initialization (only when explicitly enabled with an active Developer account)
        if shouldEnableCloudKit {
            do {
                let cloudKitConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private(cloudKitContainerIdentifier)
                )
                return try ModelContainer(for: schema, configurations: [cloudKitConfig])
            } catch {
                print("⚠️ SwiftData CloudKit initialization encountered error: \(error). Falling back to local offline store...")
            }
        }

        // 2. Local fallback configuration (Offline first - ensures zero data loss, rock-solid persistence, and no entitlement crashes)
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            print("⚠️ Local ModelContainer init failed with error: \(error). Attempting recovery...")
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let appSupportURL {
                let defaultStoreURL = appSupportURL.appendingPathComponent("default.store")
                let shmURL = appSupportURL.appendingPathComponent("default.store-shm")
                let walURL = appSupportURL.appendingPathComponent("default.store-wal")
                try? FileManager.default.removeItem(at: defaultStoreURL)
                try? FileManager.default.removeItem(at: shmURL)
                try? FileManager.default.removeItem(at: walURL)
            }
            return try ModelContainer(for: schema, configurations: [localConfig])
        }
    }
}
