export type OccurrenceState = "scheduled" | "conducted" | "cancelled";
export type AttendanceStatus = "present" | "missed";

export interface Subject {
  id: string;
  name: string;
  short: string;
  courseCode?: string | undefined;
  lecturer: string;
  room?: string | undefined;
  tint: string;
  createdAt: string;
  updatedAt: string;
}

export interface ClassSchedule {
  id: string;
  subjectId: string;
  /** 0 = Sunday, 1 = Monday, ..., 6 = Saturday */
  weekday: number;
  startTime: string; // "HH:mm"
  endTime: string;   // "HH:mm"
  room: string;
  active: boolean;
}

export interface ClassOccurrence {
  id: string;
  subjectId: string;
  date: string; // "YYYY-MM-DD"
  scheduleId?: string | undefined;
  startTime: string; // "HH:mm"
  endTime: string;   // "HH:mm"
  room?: string | undefined;
  isExtra: boolean;
  state: OccurrenceState;
  cancellationReason?: string | undefined;
  createdAt: string;
  updatedAt: string;
}

export interface AttendanceRecord {
  id: string;
  classOccurrenceId: string;
  status: AttendanceStatus;
  notes?: string | undefined;
  createdAt: string;
  updatedAt: string;
}

export interface Semester {
  id: string;
  name: string;
  startDate: string; // "YYYY-MM-DD"
  endDate: string;   // "YYYY-MM-DD"
}

export interface UserPreferences {
  accent: string;
  appearance: "light" | "dark";
  icloud: boolean; // Note: Phase 2 native CloudKit integration
  notifications: boolean; // Web notifications
  reminderMinutes: number; // e.g. 15
  target: number; // e.g. 75, 80, 85, 90
}

export interface SubjectStats {
  subjectId: string;
  present: number;
  missed: number;
  totalConducted: number;
  pct: number | null; // null if 0 conducted classes
  bunkBuffer: number;
  catchUpNeeded: number;
  projectedPct: number | null;
  totalScheduled: number;
  totalCancelled: number;
}

export interface OverallStats {
  present: number;
  missed: number;
  totalConducted: number;
  pct: number | null; // null if 0 conducted classes
  bunkBuffer: number;
  catchUpNeeded: number;
  projectedPct: number | null;
  totalScheduled: number;
  totalCancelled: number;
}

export interface DayClassItem {
  occurrence: ClassOccurrence;
  subject: Subject;
  attendanceRecord?: AttendanceRecord | undefined;
  isOngoing: boolean;
  isUpcoming: boolean;
  isPast: boolean;
}

export interface ExportedData {
  version: number;
  exportedAt: string;
  semester: Semester;
  subjects: Subject[];
  schedules: ClassSchedule[];
  classOccurrences: ClassOccurrence[];
  attendanceRecords: AttendanceRecord[];
  preferences: UserPreferences;
}
