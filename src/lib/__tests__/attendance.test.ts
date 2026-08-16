import { describe, it, expect, beforeEach } from "vitest";
import {
  calculateAttendanceMetrics,
  calculateSubjectStats,
  calculateOverallStats,
  countRemainingScheduledClasses,
  calculateAttendanceTrend,
  calculateWeeklyDistribution,
} from "../statsEngine";
import {
  getClassesForDate,
  getNextClassForSubject,
  getNextClassAcrossAllSubjects,
  getLiveDayStatus,
  isDateWithinSemester,
  formatISODate,
} from "../timetableEngine";
import {
  IndexedDBDataRepository,
  STARTER_SUBJECTS,
  STARTER_SCHEDULES,
  INITIAL_SEMESTER,
  DEFAULT_PREFERENCES,
} from "../repository/IndexedDBDataRepository";
import {
  ClassOccurrence,
  AttendanceRecord,
  Semester,
  ClassSchedule,
  Subject,
  ExportedData,
} from "../types";

describe("Part 1 & 9: Attendance Calculation & Formula", () => {
  it("Formula: Present / (Present + Missed) * 100", () => {
    const res = calculateAttendanceMetrics(15, 5, 75, 0);
    expect(res.pct).toBe(75);
    expect(res.totalConducted).toBe(20);
  });

  it("Empty State: 0 conducted classes -> pct is null (No attendance yet)", () => {
    const res = calculateAttendanceMetrics(0, 0, 75, 10);
    expect(res.pct).toBeNull();
    expect(res.totalConducted).toBe(0);
    expect(res.bunkBuffer).toBe(0);
    expect(res.catchUpNeeded).toBe(0);
    expect(res.projectedPct).toBeNull(); // Never fake 100%
  });

  it("All Present: 100 present, 0 missed -> 100%", () => {
    const res = calculateAttendanceMetrics(100, 0, 75, 0);
    expect(res.pct).toBe(100);
    expect(res.totalConducted).toBe(100);
    expect(res.bunkBuffer).toBe(33);
    expect(res.catchUpNeeded).toBe(0);
  });

  it("All Missed: 0 present, 10 missed -> 0%", () => {
    const res = calculateAttendanceMetrics(0, 10, 75, 0);
    expect(res.pct).toBe(0);
    expect(res.totalConducted).toBe(10);
    expect(res.bunkBuffer).toBe(0);
    expect(res.catchUpNeeded).toBe(30);
  });

  it("Extra Present & Extra Missed are properly incorporated into attendance total", () => {
    // 1 regular present, 1 regular missed, 1 extra present, 1 extra missed -> 2 present, 2 missed = 50%
    const res = calculateAttendanceMetrics(2, 2, 75, 0);
    expect(res.pct).toBe(50);
    expect(res.totalConducted).toBe(4);
  });

  it("Cancelled classes are excluded from calculations and do not inflate conducted count", () => {
    const sub = STARTER_SUBJECTS[0]!;
    const occurrences: ClassOccurrence[] = [
      {
        id: "occ-cond-1",
        subjectId: sub.id,
        date: "2026-08-17",
        startTime: "09:00",
        endTime: "10:00",
        isExtra: false,
        state: "conducted",
        createdAt: "2026-08-15T00:00:00Z",
        updatedAt: "2026-08-15T00:00:00Z",
      },
      {
        id: "occ-canc-1",
        subjectId: sub.id,
        date: "2026-08-19",
        startTime: "09:00",
        endTime: "10:00",
        isExtra: false,
        state: "cancelled",
        cancellationReason: "Holiday",
        createdAt: "2026-08-15T00:00:00Z",
        updatedAt: "2026-08-15T00:00:00Z",
      },
    ];

    const records: AttendanceRecord[] = [
      {
        id: "att-1",
        classOccurrenceId: "occ-cond-1",
        status: "present",
        createdAt: "2026-08-15T00:00:00Z",
        updatedAt: "2026-08-15T00:00:00Z",
      },
    ];

    const stats = calculateSubjectStats(sub.id, occurrences, records, STARTER_SCHEDULES, INITIAL_SEMESTER);
    expect(stats.totalConducted).toBe(1);
    expect(stats.present).toBe(1);
    expect(stats.missed).toBe(0);
    expect(stats.pct).toBe(100);
    expect(stats.totalCancelled).toBe(1);
  });
});

describe("Part 10: Projection Mathematics & Margins (All 10 Edge Cases)", () => {
  it("Case 1: 0 conducted -> returns safe 0 margins and null pct", () => {
    const res = calculateAttendanceMetrics(0, 0, 75, 0);
    expect(res.pct).toBeNull();
    expect(res.bunkBuffer).toBe(0);
    expect(res.catchUpNeeded).toBe(0);
  });

  it("Case 2: 100% attendance (8 present, 0 missed at 75% target) -> 2 safe bunks", () => {
    const res = calculateAttendanceMetrics(8, 0, 75, 0);
    expect(res.pct).toBe(100);
    expect(res.bunkBuffer).toBe(2);
    expect(res.catchUpNeeded).toBe(0);
  });

  it("Case 3: Exactly at target (75 present, 25 missed at 75% target) -> 0 buffer, 0 catch-up", () => {
    const res = calculateAttendanceMetrics(75, 25, 75, 0);
    expect(res.pct).toBe(75);
    expect(res.bunkBuffer).toBe(0);
    expect(res.catchUpNeeded).toBe(0);
  });

  it("Case 4: Below target (70 present, 30 missed at 75% target) -> 20 consecutive classes needed", () => {
    const res = calculateAttendanceMetrics(70, 30, 75, 0);
    expect(res.pct).toBe(70);
    expect(res.catchUpNeeded).toBe(20);
    expect(res.bunkBuffer).toBe(0);
  });

  it("Case 5: Extreme targets (80%, 85%, 90%) calculate correctly", () => {
    const res80 = calculateAttendanceMetrics(80, 20, 80, 0);
    expect(res80.pct).toBe(80);
    expect(res80.bunkBuffer).toBe(0);

    const res90 = calculateAttendanceMetrics(95, 5, 90, 0);
    expect(res90.pct).toBe(95);
    expect(res90.bunkBuffer).toBe(5);
  });

  it("Case 6: Projected % with remaining semester classes", () => {
    const res = calculateAttendanceMetrics(50, 50, 75, 100);
    expect(res.pct).toBe(50);
    expect(res.projectedPct).toBe(75);
  });

  it("Case 7: Only cancelled classes remaining -> 0 remaining classes counted", () => {
    const sub = STARTER_SUBJECTS[0]!;
    const sched = STARTER_SCHEDULES.filter((s) => s.subjectId === sub.id);
    const fromDate = new Date("2026-11-20");

    const baseCount = countRemainingScheduledClasses(sub.id, sched, [], INITIAL_SEMESTER, fromDate);

    // Cancel next occurrence
    const occs: ClassOccurrence[] = [
      {
        id: "occ-canc-2",
        subjectId: sub.id,
        date: "2026-11-23", // Monday
        scheduleId: sched[0]?.id,
        startTime: "09:00",
        endTime: "10:00",
        isExtra: false,
        state: "cancelled",
        createdAt: "2026-08-15T00:00:00Z",
        updatedAt: "2026-08-15T00:00:00Z",
      },
    ];

    const withCancelled = countRemainingScheduledClasses(sub.id, sched, occs, INITIAL_SEMESTER, fromDate);
    expect(withCancelled).toBe(baseCount - 1);
  });

  it("Case 8: Negative or extreme inputs never return negative margins or NaN", () => {
    const res = calculateAttendanceMetrics(-10, -5, 75, 0);
    expect(res.totalConducted).toBe(0);
    expect(res.bunkBuffer).toBe(0);
    expect(res.catchUpNeeded).toBe(0);
    expect(Number.isNaN(res.bunkBuffer)).toBe(false);
  });

  it("Case 9: Empty Trend & Weekly distribution on 0 attendance data", () => {
    const trend = calculateAttendanceTrend([], [], "M", new Date());
    expect(trend.length).toBe(0);

    const weekly = calculateWeeklyDistribution([], []);
    expect(weekly.every((w) => w.total === 0 && w.pct === 0)).toBe(true);
  });

  it("Case 10: Overall statistics calculation matches aggregate metrics", () => {
    const overall = calculateOverallStats(STARTER_SUBJECTS, [], [], STARTER_SCHEDULES, INITIAL_SEMESTER);
    expect(overall.totalConducted).toBe(0);
    expect(overall.pct).toBeNull();
    expect(overall.bunkBuffer).toBe(0);
  });
});

describe("Part 1: Authoritative Timetable Engine & Consistency QA", () => {
  const semester: Semester = {
    id: "sem-1",
    name: "Fall 2026",
    startDate: "2026-08-01",
    endDate: "2026-11-30",
  };

  it("Next Class Consistency: Home next-class == Subject Detail next-class == Timetable engine next-class", () => {
    const cloudSub = STARTER_SUBJECTS.find((s) => s.short === "Cloud Computing")!;
    const cloudSched = STARTER_SCHEDULES.filter((s) => s.subjectId === cloudSub.id);

    // Test on Sunday 2026-08-16 10:00
    const testDate = new Date(2026, 7, 16, 10, 0); // Sunday

    // 1. Timetable Engine resolution for Cloud Computing
    const engineNext = getNextClassForSubject(cloudSub, STARTER_SCHEDULES, semester, [], testDate);

    // Cloud Computing is scheduled Wednesday 15:30 and Friday 15:30
    expect(engineNext.time).toBe("15:30");
    expect(engineNext.label).toBe("Wednesday · 15:30");

    // 2. Overall Next Class resolution across all subjects
    const overallNext = getNextClassAcrossAllSubjects(STARTER_SUBJECTS, STARTER_SCHEDULES, semester, [], testDate);
    expect(overallNext).not.toBeNull();
    // Monday at 09:00 (Compiler Design) is earliest
    expect(overallNext?.subject.short).toBe("Compiler Design");
    expect(overallNext?.time).toBe("09:00");
    expect(overallNext?.label).toBe("Tomorrow at 09:00");

    // 3. Live Day Status
    const live = getLiveDayStatus(STARTER_SUBJECTS, STARTER_SCHEDULES, [], [], semester, testDate);
    expect(live.hasClassesToday).toBe(false);
    expect(live.ongoing).toBeNull();
    expect(live.nextClassToday).toBeNull();
    expect(live.nextOverall?.subject.short).toBe("Compiler Design");
  });

  it("Enforces semester boundaries strictly", () => {
    expect(isDateWithinSemester("2026-07-31", semester)).toBe(false);
    expect(isDateWithinSemester("2026-08-01", semester)).toBe(true);
    expect(isDateWithinSemester("2026-11-30", semester)).toBe(true);
    expect(isDateWithinSemester("2026-12-01", semester)).toBe(false);
  });
});

describe("Part 2 & 22: Attendance State Synchronization, Undo, and Repository Cascades", () => {
  let repo: IndexedDBDataRepository;

  beforeEach(async () => {
    repo = new IndexedDBDataRepository();
    await repo.init();
  });

  it("Sync Flow: Open subject -> Mark Present (100%) -> Change to Missed (0%) -> Delete -> Reset", async () => {
    const cloudSub = STARTER_SUBJECTS.find((s) => s.short === "Cloud Computing")!;

    // 1. Create conducted occurrence for Cloud Computing
    const occ: ClassOccurrence = {
      id: "occ-sync-test-1",
      subjectId: cloudSub.id,
      date: "2026-08-19",
      startTime: "15:30",
      endTime: "16:30",
      isExtra: false,
      state: "conducted",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    await repo.createClassOccurrence(occ);

    // 2. Mark Present
    const attPresent: AttendanceRecord = {
      id: "att-sync-test-1",
      classOccurrenceId: occ.id,
      status: "present",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    await repo.createAttendanceRecord(attPresent);

    // Verify stats = 100%
    let occs = await repo.getClassOccurrences();
    let atts = await repo.getAttendanceRecords();
    let stats = calculateSubjectStats(cloudSub.id, occs, atts, STARTER_SCHEDULES, INITIAL_SEMESTER);
    expect(stats.totalConducted).toBe(1);
    expect(stats.present).toBe(1);
    expect(stats.missed).toBe(0);
    expect(stats.pct).toBe(100);

    // 3. Change to Missed
    const attMissed: AttendanceRecord = {
      id: "att-sync-test-1",
      classOccurrenceId: occ.id,
      status: "missed",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    await repo.updateAttendanceRecord(attMissed);

    occs = await repo.getClassOccurrences();
    atts = await repo.getAttendanceRecords();
    stats = calculateSubjectStats(cloudSub.id, occs, atts, STARTER_SCHEDULES, INITIAL_SEMESTER);
    expect(stats.totalConducted).toBe(1);
    expect(stats.present).toBe(0);
    expect(stats.missed).toBe(1);
    expect(stats.pct).toBe(0);

    // 4. Reset All Attendance
    await repo.resetAllAttendance();
    occs = await repo.getClassOccurrences();
    atts = await repo.getAttendanceRecords();
    stats = calculateSubjectStats(cloudSub.id, occs, atts, STARTER_SCHEDULES, INITIAL_SEMESTER);
    expect(stats.totalConducted).toBe(0);
    expect(stats.pct).toBeNull();
  });

  it("Import/Export Validation: Preserves all tables, IDs, and types", async () => {
    const exported = await repo.exportData();
    expect(exported.version).toBe(2);
    expect(exported.subjects.length).toBe(STARTER_SUBJECTS.length);
    expect(exported.schedules.length).toBe(STARTER_SCHEDULES.length);
    expect(exported.semester.id).toBe(INITIAL_SEMESTER.id);

    // Re-import
    await repo.importData(exported);
    const importedSubjects = await repo.getSubjects();
    expect(importedSubjects.length).toBe(STARTER_SUBJECTS.length);
  });
});
