import {
  ClassOccurrence,
  AttendanceRecord,
  ClassSchedule,
  Semester,
  SubjectStats,
  OverallStats,
  Subject,
} from "./types";
import { parseISODate, formatISODate } from "./timetableEngine";

/**
 * Pure calculation for attendance percentage and margin buffers
 */
export function calculateAttendanceMetrics(
  present: number,
  missed: number,
  target = 75,
  remainingScheduled = 0
): {
  pct: number | null;
  totalConducted: number;
  bunkBuffer: number;
  catchUpNeeded: number;
  projectedPct: number | null;
} {
  const safePresent = Math.max(0, present);
  const safeMissed = Math.max(0, missed);
  const totalConducted = safePresent + safeMissed;

  // Empty state: No conducted classes yet
  if (totalConducted === 0) {
    return {
      pct: null,
      totalConducted: 0,
      bunkBuffer: 0,
      catchUpNeeded: 0,
      projectedPct: null,
    };
  }

  const rawPct = (safePresent / totalConducted) * 100;
  const pct = Math.round(rawPct);

  // Safe Bunk Buffer: Maximum classes that can be missed while remaining >= target
  let bunkBuffer = 0;
  if (pct >= target) {
    const targetFrac = target / 100;
    if (targetFrac > 0) {
      const maxTotal = Math.floor(safePresent / targetFrac);
      bunkBuffer = Math.max(0, maxTotal - totalConducted);
    }
  }

  // Catch-Up Needed: Minimum consecutive classes that must be attended to reach target
  let catchUpNeeded = 0;
  if (pct < target && target < 100) {
    const denom = 100 - target;
    const numerator = target * totalConducted - 100 * safePresent;
    if (denom > 0 && numerator > 0) {
      catchUpNeeded = Math.ceil(numerator / denom);
    }
  }

  // Projected Percentage if all remaining scheduled classes are attended
  let projectedPct = pct;
  const projTotal = totalConducted + remainingScheduled;
  if (projTotal > 0) {
    projectedPct = Math.round(((safePresent + remainingScheduled) / projTotal) * 100);
  }

  return {
    pct,
    totalConducted,
    bunkBuffer,
    catchUpNeeded,
    projectedPct,
  };
}

/**
 * Calculate attendance statistics for a specific subject
 */
export function calculateSubjectStats(
  subjectId: string,
  occurrences: ClassOccurrence[],
  attendanceRecords: AttendanceRecord[],
  schedules: ClassSchedule[],
  semester?: Semester,
  target = 75,
  fromDate = new Date()
): SubjectStats {
  const subOccurrences = occurrences.filter((o) => o.subjectId === subjectId);
  const conductedOccurrences = subOccurrences.filter((o) => o.state === "conducted");
  const cancelledCount = subOccurrences.filter((o) => o.state === "cancelled").length;

  const conductedIds = new Set(conductedOccurrences.map((o) => o.id));
  const subAttendance = attendanceRecords.filter((r) => conductedIds.has(r.classOccurrenceId));

  const present = subAttendance.filter((r) => r.status === "present").length;
  const missed = subAttendance.filter((r) => r.status === "missed").length;

  const remainingScheduled = semester
    ? countRemainingScheduledClasses(subjectId, schedules, occurrences, semester, fromDate)
    : 0;

  const metrics = calculateAttendanceMetrics(present, missed, target, remainingScheduled);

  return {
    subjectId,
    present,
    missed,
    totalConducted: metrics.totalConducted,
    pct: metrics.pct,
    bunkBuffer: metrics.bunkBuffer,
    catchUpNeeded: metrics.catchUpNeeded,
    projectedPct: metrics.projectedPct,
    totalScheduled: subOccurrences.length,
    totalCancelled: cancelledCount,
  };
}

/**
 * Calculate overall attendance statistics across all subjects
 */
export function calculateOverallStats(
  subjects: Subject[],
  occurrences: ClassOccurrence[],
  attendanceRecords: AttendanceRecord[],
  schedules: ClassSchedule[],
  semester?: Semester,
  target = 75,
  fromDate = new Date()
): OverallStats {
  const conductedOccurrences = occurrences.filter((o) => o.state === "conducted");
  const cancelledCount = occurrences.filter((o) => o.state === "cancelled").length;

  const conductedIds = new Set(conductedOccurrences.map((o) => o.id));
  const validAttendance = attendanceRecords.filter((r) => conductedIds.has(r.classOccurrenceId));

  const present = validAttendance.filter((r) => r.status === "present").length;
  const missed = validAttendance.filter((r) => r.status === "missed").length;

  let totalRemaining = 0;
  if (semester) {
    for (const sub of subjects) {
      totalRemaining += countRemainingScheduledClasses(sub.id, schedules, occurrences, semester, fromDate);
    }
  }

  const metrics = calculateAttendanceMetrics(present, missed, target, totalRemaining);

  return {
    present,
    missed,
    totalConducted: metrics.totalConducted,
    pct: metrics.pct,
    bunkBuffer: metrics.bunkBuffer,
    catchUpNeeded: metrics.catchUpNeeded,
    projectedPct: metrics.projectedPct,
    totalScheduled: occurrences.length,
    totalCancelled: cancelledCount,
  };
}

/**
 * Count remaining scheduled classes strictly between tomorrow and semester.endDate,
 * excluding any occurrences already marked as cancelled or conducted.
 */
export function countRemainingScheduledClasses(
  subjectId: string,
  schedules: ClassSchedule[],
  occurrences: ClassOccurrence[],
  semester: Semester,
  fromDate = new Date()
): number {
  const subSchedules = schedules.filter((s) => s.subjectId === subjectId && s.active);
  if (subSchedules.length === 0) return 0;

  const semesterEnd = parseISODate(semester.endDate);
  const semesterStart = parseISODate(semester.startDate);

  // If already past semester end date
  if (fromDate >= semesterEnd) return 0;

  let count = 0;
  const current = new Date(fromDate);
  current.setDate(current.getDate() + 1); // Start from tomorrow

  while (current <= semesterEnd) {
    if (current >= semesterStart) {
      const dateIso = formatISODate(current);
      const wd = current.getDay();

      const matchingSchedules = subSchedules.filter((s) => s.weekday === wd);
      for (const sch of matchingSchedules) {
        // Check if there is an explicit occurrence on this date
        const existingOcc = occurrences.find(
          (o) => o.subjectId === subjectId && o.date === dateIso && o.scheduleId === sch.id
        );

        // Do not count if cancelled or already conducted
        if (existingOcc && (existingOcc.state === "cancelled" || existingOcc.state === "conducted")) {
          continue;
        }

        count++;
      }
    }
    current.setDate(current.getDate() + 1);
  }

  return count;
}

/**
 * Calculate weekly attendance averages (Mon–Fri)
 */
export function calculateWeeklyDistribution(
  occurrences: ClassOccurrence[],
  attendanceRecords: AttendanceRecord[]
): { label: string; pct: number; present: number; total: number }[] {
  const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const buckets = dayNames.map((label) => ({ label, present: 0, total: 0 }));

  const attendanceMap = new Map(attendanceRecords.map((r) => [r.classOccurrenceId, r.status]));

  for (const occ of occurrences) {
    if (occ.state !== "conducted") continue;
    const status = attendanceMap.get(occ.id);
    if (!status) continue;

    const d = parseISODate(occ.date);
    const wd = d.getDay();
    const bucket = buckets[wd];
    if (bucket) {
      bucket.total++;
      if (status === "present") {
        bucket.present++;
      }
    }
  }

  return buckets.map((b) => ({
    label: b.label,
    present: b.present,
    total: b.total,
    pct: b.total === 0 ? 0 : Math.round((b.present / b.total) * 100),
  }));
}

/**
 * Calculate time-series trend over time
 */
export function calculateAttendanceTrend(
  occurrences: ClassOccurrence[],
  attendanceRecords: AttendanceRecord[],
  range: "W" | "M" | "6M",
  now = new Date()
): { label: string; pct: number }[] {
  const conductedOccurrences = occurrences.filter((o) => o.state === "conducted");
  if (conductedOccurrences.length === 0) {
    return [];
  }

  const days = range === "W" ? 7 : range === "M" ? 30 : 120;
  const buckets = range === "6M" ? 12 : range === "M" ? 10 : 7;
  const step = Math.ceil(days / buckets);

  const attendanceMap = new Map(attendanceRecords.map((r) => [r.classOccurrenceId, r.status]));
  const out: { label: string; pct: number }[] = [];

  for (let b = buckets - 1; b >= 0; b--) {
    const sliceEnd = new Date(now);
    sliceEnd.setDate(now.getDate() - b * step);
    const sliceEndIso = formatISODate(sliceEnd);

    const sliceOccurrences = conductedOccurrences.filter((o) => o.date <= sliceEndIso);

    let present = 0;
    let total = 0;

    for (const occ of sliceOccurrences) {
      const status = attendanceMap.get(occ.id);
      if (status) {
        total++;
        if (status === "present") present++;
      }
    }

    const label = sliceEnd.toLocaleDateString("en-US",
      range === "W" ? { weekday: "narrow" } : { month: "short", day: "numeric" }
    );

    out.push({
      label,
      pct: total === 0 ? 0 : Math.round((present / total) * 100),
    });
  }

  return out;
}
