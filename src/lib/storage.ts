import { Subject, ClassSchedule, AttendanceRecord, Semester, UserPreferences } from "./types";

const STORAGE_KEY = "presence.attendance.v2";

export interface AppData {
  version: number;
  subjects: Subject[];
  schedules: ClassSchedule[];
  records: AttendanceRecord[];
  semester: Semester;
  preferences: UserPreferences;
}

export const DEFAULT_PREFERENCES: UserPreferences = {
  accent: "var(--ios-blue)",
  appearance: "dark",
  icloud: true,
  notifications: true,
  reminderMinutes: 15,
  target: 75,
};

export const INITIAL_SUBJECTS: Subject[] = [
  {
    id: "sub-1",
    name: "System Software & Compiler Design",
    short: "Compiler Design",
    courseCode: "CS401",
    lecturer: "Dr. Aravind Menon",
    room: "Block C · 402",
    tint: "var(--ios-blue)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-2",
    name: "Network Security",
    short: "Network Security",
    courseCode: "CS402",
    lecturer: "Prof. Neha Kulkarni",
    room: "Block A · 118",
    tint: "var(--ios-indigo)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-3",
    name: "Data Science",
    short: "Data Science",
    courseCode: "CS403",
    lecturer: "Dr. Ishaan Verma",
    room: "Lab 3 · 210",
    tint: "var(--ios-teal)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-4",
    name: "Cloud Computing",
    short: "Cloud Computing",
    courseCode: "CS404",
    lecturer: "Prof. Meera Raghavan",
    room: "Block B · 305",
    tint: "var(--ios-orange)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-5",
    name: "Machine Learning",
    short: "Machine Learning",
    courseCode: "CS405",
    lecturer: "Dr. Kabir Sharma",
    room: "Block C · 511",
    tint: "var(--ios-pink)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

export const INITIAL_SCHEDULES: ClassSchedule[] = [
  { id: "sch-1", subjectId: "sub-1", weekday: 1, startTime: "09:00", endTime: "10:00", room: "Block C · 402", active: true },
  { id: "sch-2", subjectId: "sub-1", weekday: 3, startTime: "09:00", endTime: "10:00", room: "Block C · 402", active: true },
  { id: "sch-3", subjectId: "sub-1", weekday: 5, startTime: "09:00", endTime: "10:00", room: "Block C · 402", active: true },

  { id: "sch-4", subjectId: "sub-2", weekday: 1, startTime: "11:00", endTime: "12:00", room: "Block A · 118", active: true },
  { id: "sch-5", subjectId: "sub-2", weekday: 2, startTime: "11:00", endTime: "12:00", room: "Block A · 118", active: true },
  { id: "sch-6", subjectId: "sub-2", weekday: 4, startTime: "11:00", endTime: "12:00", room: "Block A · 118", active: true },

  { id: "sch-7", subjectId: "sub-3", weekday: 2, startTime: "14:00", endTime: "15:00", room: "Lab 3 · 210", active: true },
  { id: "sch-8", subjectId: "sub-3", weekday: 4, startTime: "14:00", endTime: "15:00", room: "Lab 3 · 210", active: true },

  { id: "sch-9", subjectId: "sub-4", weekday: 3, startTime: "15:30", endTime: "16:30", room: "Block B · 305", active: true },
  { id: "sch-10", subjectId: "sub-4", weekday: 5, startTime: "15:30", endTime: "16:30", room: "Block B · 305", active: true },

  { id: "sch-11", subjectId: "sub-5", weekday: 1, startTime: "16:45", endTime: "17:45", room: "Block C · 511", active: true },
  { id: "sch-12", subjectId: "sub-5", weekday: 4, startTime: "16:45", endTime: "17:45", room: "Block C · 511", active: true },
];

export const INITIAL_SEMESTER: Semester = {
  id: "sem-current",
  name: "Current Semester",
  startDate: new Date(new Date().getFullYear(), 0, 1).toISOString().split("T")[0] ?? "2026-01-01",
  endDate: new Date(new Date().getFullYear(), 11, 31).toISOString().split("T")[0] ?? "2026-12-31",
};

export function loadStoredData(): AppData {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && Array.isArray(parsed.subjects)) {
        return {
          version: parsed.version || 2,
          subjects: parsed.subjects || [],
          schedules: parsed.schedules || [],
          records: parsed.records || [],
          semester: parsed.semester || INITIAL_SEMESTER,
          preferences: { ...DEFAULT_PREFERENCES, ...(parsed.preferences || {}) },
        };
      }
    }
  } catch (err) {
    console.error("Failed to parse stored data:", err);
  }

  return {
    version: 2,
    subjects: INITIAL_SUBJECTS,
    schedules: INITIAL_SCHEDULES,
    records: [],
    semester: INITIAL_SEMESTER,
    preferences: DEFAULT_PREFERENCES,
  };
}

export function saveStoredData(data: AppData): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  } catch (err) {
    console.error("Failed to save data:", err);
  }
}
