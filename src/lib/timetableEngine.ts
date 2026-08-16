import {
  Subject,
  ClassSchedule,
  ClassOccurrence,
  AttendanceRecord,
  Semester,
  DayClassItem,
} from "./types";

export const DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
export const DAY_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export function formatISODate(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function parseISODate(iso: string): Date {
  const parts = iso.split("-").map(Number);
  const y = parts[0] ?? 2026;
  const m = parts[1] ?? 1;
  const d = parts[2] ?? 1;
  return new Date(y, m - 1, d);
}

export function parseTimeInMinutes(timeStr: string): number {
  if (!timeStr) return 0;
  const parts = timeStr.split(":").map(Number);
  const hours = parts[0] ?? 0;
  const minutes = parts[1] ?? 0;
  return hours * 60 + minutes;
}

export function formatTimeFromMinutes(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

/**
 * Check if a date string is within semester boundaries
 */
export function isDateWithinSemester(dateIso: string, semester?: Semester): boolean {
  if (!semester) return true;
  return dateIso >= semester.startDate && dateIso <= semester.endDate;
}

/**
 * Get all class items for a specific date (merging stored occurrences and virtual schedule slots)
 */
export function getClassesForDate(
  dateIso: string,
  subjects: Subject[],
  schedules: ClassSchedule[],
  occurrences: ClassOccurrence[],
  attendanceRecords: AttendanceRecord[],
  semester?: Semester,
  currentTime = new Date()
): DayClassItem[] {
  const targetDate = parseISODate(dateIso);
  const weekday = targetDate.getDay();
  const subjectMap = new Map<string, Subject>(subjects.map((s) => [s.id, s]));
  const attendanceMap = new Map<string, AttendanceRecord>(
    attendanceRecords.map((r) => [r.classOccurrenceId, r])
  );

  const currentIso = formatISODate(currentTime);
  const isToday = dateIso === currentIso;
  const currentMinutes = currentTime.getHours() * 60 + currentTime.getMinutes();

  const isWithinTerm = isDateWithinSemester(dateIso, semester);
  const items: DayClassItem[] = [];

  // 1. Existing stored occurrences for this date (including extra classes, conducted, cancelled)
  const dateOccurrences = occurrences.filter((o) => o.date === dateIso);
  for (const occ of dateOccurrences) {
    const subject = subjectMap.get(occ.subjectId);
    if (!subject) continue;

    const startMin = parseTimeInMinutes(occ.startTime);
    const endMin = parseTimeInMinutes(occ.endTime || occ.startTime) || startMin + 60;

    let isOngoing = false;
    let isUpcoming = false;
    let isPast = false;

    if (isToday) {
      isOngoing = currentMinutes >= startMin && currentMinutes < endMin;
      isUpcoming = currentMinutes < startMin;
      isPast = currentMinutes >= endMin;
    } else {
      isPast = targetDate < new Date(currentTime.getFullYear(), currentTime.getMonth(), currentTime.getDate());
      isUpcoming = targetDate > new Date(currentTime.getFullYear(), currentTime.getMonth(), currentTime.getDate());
    }

    items.push({
      occurrence: occ,
      subject,
      attendanceRecord: attendanceMap.get(occ.id),
      isOngoing,
      isUpcoming,
      isPast,
    });
  }

  // 2. Regular weekly schedules if date is within semester and not already instantiated
  if (isWithinTerm) {
    const daySchedules = schedules.filter((sch) => sch.active && sch.weekday === weekday);

    for (const sch of daySchedules) {
      const subject = subjectMap.get(sch.subjectId);
      if (!subject) continue;

      // Check if already covered by an occurrence
      const alreadyHasOccurrence = dateOccurrences.some(
        (o) => o.subjectId === sch.subjectId && o.scheduleId === sch.id
      );
      if (alreadyHasOccurrence) continue;

      const startMin = parseTimeInMinutes(sch.startTime);
      const endMin = parseTimeInMinutes(sch.endTime) || startMin + 60;

      let isOngoing = false;
      let isUpcoming = false;
      let isPast = false;

      if (isToday) {
        isOngoing = currentMinutes >= startMin && currentMinutes < endMin;
        isUpcoming = currentMinutes < startMin;
        isPast = currentMinutes >= endMin;
      } else {
        isPast = targetDate < new Date(currentTime.getFullYear(), currentTime.getMonth(), currentTime.getDate());
        isUpcoming = targetDate > new Date(currentTime.getFullYear(), currentTime.getMonth(), currentTime.getDate());
      }

      // Virtual scheduled occurrence
      const virtualOccurrence: ClassOccurrence = {
        id: `virt-${sch.subjectId}-${dateIso}-${sch.id}`,
        subjectId: sch.subjectId,
        date: dateIso,
        scheduleId: sch.id,
        startTime: sch.startTime,
        endTime: sch.endTime,
        room: sch.room || subject.room,
        isExtra: false,
        state: "scheduled",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      items.push({
        occurrence: virtualOccurrence,
        subject,
        attendanceRecord: undefined,
        isOngoing,
        isUpcoming,
        isPast,
      });
    }
  }

  return items.sort((a, b) => a.occurrence.startTime.localeCompare(b.occurrence.startTime));
}

/**
 * Get next upcoming class occurrence for a specific subject
 */
export function getNextClassForSubject(
  subject: Subject,
  schedules: ClassSchedule[],
  semester?: Semester,
  occurrences: ClassOccurrence[] = [],
  from = new Date()
): { date: Date; dateIso: string; label: string; time: string; room: string } {
  const subSchedules = schedules.filter((s) => s.subjectId === subject.id && s.active);
  if (subSchedules.length === 0) {
    return { date: from, dateIso: formatISODate(from), label: "No schedule", time: "—", room: subject.room || "—" };
  }

  const currentMinutes = from.getHours() * 60 + from.getMinutes();

  for (let i = 0; i < 14; i++) {
    const d = new Date(from);
    d.setDate(from.getDate() + i);
    const dateIso = formatISODate(d);

    if (!isDateWithinSemester(dateIso, semester)) continue;

    const dayOfWeek = d.getDay();
    const matchingSchedules = subSchedules
      .filter((s) => s.weekday === dayOfWeek)
      .sort((a, b) => a.startTime.localeCompare(b.startTime));

    for (const sch of matchingSchedules) {
      // Check if cancelled
      const existingOcc = occurrences.find(
        (o) => o.subjectId === subject.id && o.date === dateIso && o.scheduleId === sch.id
      );
      if (existingOcc && existingOcc.state === "cancelled") continue;

      if (i === 0) {
        const schMin = parseTimeInMinutes(sch.startTime);
        if (schMin >= currentMinutes) {
          return {
            date: d,
            dateIso,
            label: `Today · ${sch.startTime}`,
            time: sch.startTime,
            room: sch.room || subject.room || "—",
          };
        }
      } else {
        const label = i === 1 ? `Tomorrow · ${sch.startTime}` : `${DAY_NAMES[dayOfWeek] ?? "Day"} · ${sch.startTime}`;
        return {
          date: d,
          dateIso,
          label,
          time: sch.startTime,
          room: sch.room || subject.room || "—",
        };
      }
    }
  }

  const sorted = [...subSchedules].sort((a, b) => a.weekday - b.weekday || a.startTime.localeCompare(b.startTime));
  const first = sorted[0];
  if (!first) {
    return { date: from, dateIso: formatISODate(from), label: "No schedule", time: "—", room: subject.room || "—" };
  }

  return {
    date: from,
    dateIso: formatISODate(from),
    label: `${DAY_NAMES[first.weekday] ?? "Day"} · ${first.startTime}`,
    time: first.startTime,
    room: first.room || subject.room || "—",
  };
}

/**
 * Get next upcoming class across all subjects
 */
export function getNextClassAcrossAllSubjects(
  subjects: Subject[],
  schedules: ClassSchedule[],
  semester?: Semester,
  occurrences: ClassOccurrence[] = [],
  from = new Date()
): {
  subject: Subject;
  date: Date;
  dateIso: string;
  label: string;
  time: string;
  room: string;
  isToday: boolean;
} | null {
  const subjectMap = new Map(subjects.map((s) => [s.id, s]));
  const currentMinutes = from.getHours() * 60 + from.getMinutes();

  for (let i = 0; i < 14; i++) {
    const d = new Date(from);
    d.setDate(from.getDate() + i);
    const dateIso = formatISODate(d);

    if (!isDateWithinSemester(dateIso, semester)) continue;

    const dayOfWeek = d.getDay();
    const matchingSchedules = schedules
      .filter((s) => s.active && s.weekday === dayOfWeek)
      .sort((a, b) => a.startTime.localeCompare(b.startTime));

    for (const sch of matchingSchedules) {
      const subject = subjectMap.get(sch.subjectId);
      if (!subject) continue;

      // Check if cancelled
      const existingOcc = occurrences.find(
        (o) => o.subjectId === subject.id && o.date === dateIso && o.scheduleId === sch.id
      );
      if (existingOcc && existingOcc.state === "cancelled") continue;

      if (i === 0) {
        const schMin = parseTimeInMinutes(sch.startTime);
        if (schMin >= currentMinutes) {
          return {
            subject,
            date: d,
            dateIso,
            label: `Today at ${sch.startTime}`,
            time: sch.startTime,
            room: sch.room || subject.room || "Classroom",
            isToday: true,
          };
        }
      } else {
        const label = i === 1 ? `Tomorrow at ${sch.startTime}` : `${DAY_NAMES[dayOfWeek] ?? "Day"} at ${sch.startTime}`;
        return {
          subject,
          date: d,
          dateIso,
          label,
          time: sch.startTime,
          room: sch.room || subject.room || "Classroom",
          isToday: false,
        };
      }
    }
  }

  return null;
}

/**
 * Authoritative live status for today
 */
export function getLiveDayStatus(
  subjects: Subject[],
  schedules: ClassSchedule[],
  occurrences: ClassOccurrence[],
  attendanceRecords: AttendanceRecord[],
  semester?: Semester,
  now = new Date()
) {
  const todayIso = formatISODate(now);
  const todayClasses = getClassesForDate(todayIso, subjects, schedules, occurrences, attendanceRecords, semester, now);

  const ongoing = todayClasses.find((c) => c.isOngoing && c.occurrence.state !== "cancelled") || null;
  const upcomingToday = todayClasses.filter((c) => c.isUpcoming && c.occurrence.state !== "cancelled");
  const nextClassToday = upcomingToday[0] || null;
  const unloggedPast = todayClasses.filter((c) => c.isPast && c.occurrence.state === "scheduled");

  const hasClassesToday = todayClasses.length > 0;
  const allConcludedToday = hasClassesToday && !ongoing && !nextClassToday;

  const nextOverall = getNextClassAcrossAllSubjects(subjects, schedules, semester, occurrences, now);

  return {
    todayClasses,
    ongoing,
    nextClassToday,
    upcomingToday,
    unloggedPast,
    hasClassesToday,
    allConcludedToday,
    nextOverall,
  };
}
