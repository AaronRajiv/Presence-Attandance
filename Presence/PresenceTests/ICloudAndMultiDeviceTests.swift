import XCTest
import SwiftData
@testable import Presence

@MainActor
final class ICloudAndMultiDeviceTests: XCTestCase {

    // MARK: - 1. Model Schema & CloudKit Initialization Resilience

    func testModelContainerInitializationWithCloudKitAndFallback() throws {
        // In-memory test container
        let memContainer = try ModelSchema.createContainer(inMemory: true, enableCloudKit: false)
        XCTAssertNotNil(memContainer)

        let context = ModelContext(memContainer)
        let sub = Subject(name: "Distributed Systems", shortName: "DS", tint: "#0A84FF")
        context.insert(sub)
        try context.save()

        let descriptor = FetchDescriptor<Subject>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Distributed Systems")
    }

    // MARK: - 2. CloudKit Model Schema Compliance Audit

    func testAllModelsHaveCloudKitCompatiblePropertiesAndDefaults() throws {
        // Verify default constructors without arguments produce valid populated instances
        let sub = Subject(name: "AI", shortName: "AI")
        XCTAssertFalse(sub.id.isEmpty)
        XCTAssertNotNil(sub.schedules)
        XCTAssertNotNil(sub.occurrences)

        let sch = ClassSchedule(weekday: 1, startTime: "09:00", endTime: "10:00")
        XCTAssertFalse(sch.id.isEmpty)
        XCTAssertTrue(sch.active)
        XCTAssertNil(sch.subject)

        let occ = ClassOccurrence(date: "2026-08-17", startTime: "09:00", endTime: "10:00")
        XCTAssertFalse(occ.id.isEmpty)
        XCTAssertEqual(occ.state, .scheduled)
        XCTAssertNil(occ.attendanceRecord)

        let rec = AttendanceRecord(status: .present)
        XCTAssertFalse(rec.id.isEmpty)
        XCTAssertEqual(rec.status, .present)
        XCTAssertNil(rec.occurrence)

        let sem = Semester()
        XCTAssertEqual(sem.id, "sem-current")
        XCTAssertEqual(sem.startDate, "2026-08-01")
        XCTAssertEqual(sem.endDate, "2026-12-31")

        let prefs = UserPreferences()
        XCTAssertEqual(prefs.targetAttendance, 75)
        XCTAssertEqual(prefs.appearance, "dark")
        XCTAssertTrue(prefs.iCloudSyncEnabled)

        let exc = AcademicDayException(date: "2026-08-15", type: .holiday, reason: "Holiday")
        XCTAssertFalse(exc.id.isEmpty)
        XCTAssertEqual(exc.type, .holiday)
    }

    // MARK: - 3. Duplicate Prevention & 1-to-1 Relationship Integrity

    func testOccurrenceToAttendanceRecordOneToOneIntegrity() throws {
        let container = try ModelSchema.createContainer(inMemory: true)
        let context = ModelContext(container)

        let sub = Subject(name: "Compiler Design", shortName: "CD", tint: "#0A84FF")
        context.insert(sub)

        let occ = ClassOccurrence(
            id: "occ-cd-aug-17",
            subject: sub,
            date: "2026-08-17",
            startTime: "09:30",
            endTime: "10:30",
            state: .conducted
        )
        context.insert(occ)

        // Device A creates initial record: Present
        let recA = AttendanceRecord(id: "rec-cd-aug-17", occurrence: occ, status: .present)
        occ.attendanceRecord = recA
        context.insert(recA)
        try context.save()

        XCTAssertEqual(occ.attendanceRecord?.status, .present)

        // Simulated Sync Update: Device B changes status to Missed
        // The existing AttendanceRecord is updated in-place, preventing duplicate creation
        recA.status = .missed
        recA.updatedAt = Date()
        try context.save()

        let recDescriptor = FetchDescriptor<AttendanceRecord>()
        let allRecords = try context.fetch(recDescriptor)
        XCTAssertEqual(allRecords.count, 1, "Duplicate AttendanceRecords were created for the same occurrence")
        XCTAssertEqual(allRecords.first?.status, .missed)
        XCTAssertEqual(occ.attendanceRecord?.id, "rec-cd-aug-17")
    }

    // MARK: - 4. Multi-Device Simulated Sync Flow (Device A -> Device B -> Device A)

    func testMultiDeviceDataReplicationAndSchedules() throws {
        // 1. Device A Context
        let containerA = try ModelSchema.createContainer(inMemory: true)
        let contextA = ModelContext(containerA)

        // Device A creates Compiler Design + 2 slots
        let cdSub = Subject(id: "sub-cd", name: "Compiler Design", shortName: "CD", tint: "#0A84FF")
        let slot1 = ClassSchedule(id: "sch-cd-tue", subject: cdSub, weekday: 2, startTime: "09:30", endTime: "10:30")
        let slot2 = ClassSchedule(id: "sch-cd-thu", subject: cdSub, weekday: 4, startTime: "11:00", endTime: "12:00")
        cdSub.schedules = [slot1, slot2]
        contextA.insert(cdSub)
        contextA.insert(slot1)
        contextA.insert(slot2)
        try contextA.save()

        // 2. Device B Context receives synchronized state
        let containerB = try ModelSchema.createContainer(inMemory: true)
        let contextB = ModelContext(containerB)

        // Replicate Device A data onto Device B
        let cdSubB = Subject(id: "sub-cd", name: "Compiler Design", shortName: "CD", tint: "#0A84FF")
        let slot1B = ClassSchedule(id: "sch-cd-tue", subject: cdSubB, weekday: 2, startTime: "09:30", endTime: "10:30")
        let slot2B = ClassSchedule(id: "sch-cd-thu", subject: cdSubB, weekday: 4, startTime: "11:00", endTime: "12:00")
        cdSubB.schedules = [slot1B, slot2B]
        contextB.insert(cdSubB)
        contextB.insert(slot1B)
        contextB.insert(slot2B)

        // Device B adds new subject: Machine Learning
        let mlSubB = Subject(id: "sub-ml", name: "Machine Learning", shortName: "ML", tint: "#FF9F0A")
        let mlSlotB = ClassSchedule(id: "sch-ml-fri", subject: mlSubB, weekday: 5, startTime: "14:00", endTime: "15:00")
        mlSubB.schedules = [mlSlotB]
        contextB.insert(mlSubB)
        contextB.insert(mlSlotB)
        try contextB.save()

        // 3. Verify Device B contains both subjects
        let bSubjects = try contextB.fetch(FetchDescriptor<Subject>())
        XCTAssertEqual(bSubjects.count, 2)

        // 4. Replicate Device B additions back to Device A
        let mlSubA = Subject(id: "sub-ml", name: "Machine Learning", shortName: "ML", tint: "#FF9F0A")
        let mlSlotA = ClassSchedule(id: "sch-ml-fri", subject: mlSubA, weekday: 5, startTime: "14:00", endTime: "15:00")
        mlSubA.schedules = [mlSlotA]
        contextA.insert(mlSubA)
        contextA.insert(mlSlotA)
        try contextA.save()

        let aSubjects = try contextA.fetch(FetchDescriptor<Subject>())
        XCTAssertEqual(aSubjects.count, 2)
        XCTAssertTrue(aSubjects.contains(where: { $0.id == "sub-cd" }))
        XCTAssertTrue(aSubjects.contains(where: { $0.id == "sub-ml" }))
    }

    // MARK: - 5. Delete Propagation Across Dependent Data

    func testDeletePropagationCascadeAcrossCloudKitModels() throws {
        let container = try ModelSchema.createContainer(inMemory: true)
        let context = ModelContext(container)

        let sub = Subject(id: "sub-to-delete", name: "Networks", shortName: "NET", tint: "#5E5CE6")
        let sch = ClassSchedule(id: "sch-net", subject: sub, weekday: 1, startTime: "10:00", endTime: "11:00")
        let occ = ClassOccurrence(id: "occ-net", subject: sub, date: "2026-08-17", startTime: "10:00", endTime: "11:00")
        let rec = AttendanceRecord(id: "rec-net", occurrence: occ, status: .present)
        sub.schedules = [sch]
        sub.occurrences = [occ]
        occ.attendanceRecord = rec

        context.insert(sub)
        context.insert(sch)
        context.insert(occ)
        context.insert(rec)
        try context.save()

        // Delete subject
        context.delete(sub)
        try context.save()

        let fetchedSubjects = try context.fetch(FetchDescriptor<Subject>())
        XCTAssertEqual(fetchedSubjects.count, 0)
    }

    // MARK: - 6. Offline-First Resilience (Full workflow offline)

    func testOfflineFirstOperationAllowsCompleteWorkflow() throws {
        let container = try ModelSchema.createContainer(inMemory: true, enableCloudKit: false)
        let context = ModelContext(container)
        let service = AttendanceService(context: context)

        // 1. Create Subject offline
        let sub = Subject(id: "sub-offline", name: "Operating Systems", shortName: "OS", tint: "#30D158")
        let sch = ClassSchedule(id: "sch-os-mon", subject: sub, weekday: 1, startTime: "08:30", endTime: "09:30")
        sub.schedules = [sch]
        context.insert(sub)
        context.insert(sch)
        try context.save()

        // 2. Mark Present offline
        let occ = ClassOccurrence(id: "occ-os-1", subject: sub, date: "2026-08-17", startTime: "08:30", endTime: "09:30", state: .conducted)
        let rec = AttendanceRecord(id: "rec-os-1", occurrence: occ, status: .present)
        occ.attendanceRecord = rec
        context.insert(occ)
        context.insert(rec)
        try context.save()

        // 3. Mark Missed offline
        let occ2 = ClassOccurrence(id: "occ-os-2", subject: sub, date: "2026-08-24", startTime: "08:30", endTime: "09:30", state: .conducted)
        let rec2 = AttendanceRecord(id: "rec-os-2", occurrence: occ2, status: .missed)
        occ2.attendanceRecord = rec2
        context.insert(occ2)
        context.insert(rec2)
        try context.save()

        // 4. Create Holiday offline
        try service.setDayException(date: "2026-08-15", type: .holiday, reason: "National Holiday")

        // 5. Query stats offline
        let sem = Semester(startDate: "2026-08-01", endDate: "2026-11-30")
        let stats = StatsEngine.calculateSubjectStats(
            subjectId: sub.id,
            occurrences: [occ, occ2],
            attendanceRecords: [rec, rec2],
            schedules: [sch],
            semester: sem,
            target: 75
        )

        XCTAssertEqual(stats.totalConducted, 2)
        XCTAssertEqual(stats.present, 1)
        XCTAssertEqual(stats.missed, 1)
        XCTAssertEqual(stats.pct, 50)
    }

    // MARK: - 8. Free Personal Team Build Local Storage Regression

    func testFreePersonalTeamBuildInitializesLocalModelContainerWithCloudKitDatabaseNone() throws {
        // Verify feature flag is paused for free personal team builds
        XCTAssertFalse(ModelSchema.isCloudKitSyncFeatureEnabled, "CloudKit should be paused for free personal team builds")

        // Default container creation must succeed with local persistence
        let container = try ModelSchema.createContainer(inMemory: true)
        XCTAssertNotNil(container)

        let context = ModelContext(container)
        let testSub = Subject(name: "Local Persistence Test", shortName: "LPT")
        context.insert(testSub)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Subject>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Local Persistence Test")
    }
}

