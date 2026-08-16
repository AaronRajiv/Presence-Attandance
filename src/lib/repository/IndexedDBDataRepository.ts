import {
  Subject,
  ClassSchedule,
  ClassOccurrence,
  AttendanceRecord,
  Semester,
  UserPreferences,
  ExportedData,
} from "../types";
import { DataRepository } from "./DataRepository";

const DB_NAME = "PresenceAttendanceDB";
const DB_VERSION = 1;

export const DEFAULT_PREFERENCES: UserPreferences = {
  accent: "var(--ios-blue)",
  appearance: "dark",
  icloud: false, // Phase 1: web offline IndexedDB; Phase 2: CloudKit
  notifications: true,
  reminderMinutes: 15,
  target: 75,
};

export const INITIAL_SEMESTER: Semester = {
  id: "sem-current",
  name: "VII Semester",
  startDate: new Date(new Date().getFullYear(), 7, 1).toISOString().split("T")[0] ?? "2026-08-01",
  endDate: new Date(new Date().getFullYear(), 11, 31).toISOString().split("T")[0] ?? "2026-12-31",
};

/**
 * Initial starter subjects for VII semester (stored as normal editable user data)
 */
export const STARTER_SUBJECTS: Subject[] = [
  {
    id: "sub-sscd",
    name: "System Software and Compiler Design",
    short: "Compiler Design",
    courseCode: "21CS71",
    lecturer: "Dr. Aravind Menon",
    room: "Block C · 402",
    tint: "var(--ios-blue)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-netsec",
    name: "Network Security and Cyber Law",
    short: "Network Security",
    courseCode: "21CS72",
    lecturer: "Prof. Neha Kulkarni",
    room: "Block A · 118",
    tint: "var(--ios-indigo)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-ds",
    name: "Data Science",
    short: "Data Science",
    courseCode: "21CS73",
    lecturer: "Dr. Ishaan Verma",
    room: "Lab 3 · 210",
    tint: "var(--ios-teal)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-cloud",
    name: "Cloud Computing & Big Data",
    short: "Cloud Computing",
    courseCode: "21CS74",
    lecturer: "Prof. Meera Raghavan",
    room: "Block B · 305",
    tint: "var(--ios-orange)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: "sub-proj",
    name: "Main Project Phase II",
    short: "Major Project",
    courseCode: "21CSP75",
    lecturer: "Dr. Kabir Sharma",
    room: "Project Lab",
    tint: "var(--ios-pink)",
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

export const STARTER_SCHEDULES: ClassSchedule[] = [
  // SSCD: Mon, Wed, Fri 09:00 - 10:00
  { id: "sch-1", subjectId: "sub-sscd", weekday: 1, startTime: "09:00", endTime: "10:00", room: "Block C · 402", active: true },
  { id: "sch-2", subjectId: "sub-sscd", weekday: 3, startTime: "09:00", endTime: "10:00", room: "Block C · 402", active: true },
  { id: "sch-3", subjectId: "sub-sscd", weekday: 5, startTime: "09:00", endTime: "10:00", room: "Block C · 402", active: true },

  // NetSec: Mon, Tue, Thu 11:00 - 12:00
  { id: "sch-4", subjectId: "sub-netsec", weekday: 1, startTime: "11:00", endTime: "12:00", room: "Block A · 118", active: true },
  { id: "sch-5", subjectId: "sub-netsec", weekday: 2, startTime: "11:00", endTime: "12:00", room: "Block A · 118", active: true },
  { id: "sch-6", subjectId: "sub-netsec", weekday: 4, startTime: "11:00", endTime: "12:00", room: "Block A · 118", active: true },

  // Data Science: Tue, Thu 14:00 - 15:00
  { id: "sch-7", subjectId: "sub-ds", weekday: 2, startTime: "14:00", endTime: "15:00", room: "Lab 3 · 210", active: true },
  { id: "sch-8", subjectId: "sub-ds", weekday: 4, startTime: "14:00", endTime: "15:00", room: "Lab 3 · 210", active: true },

  // Cloud Computing: Wed, Fri 15:30 - 16:30
  { id: "sch-9", subjectId: "sub-cloud", weekday: 3, startTime: "15:30", endTime: "16:30", room: "Block B · 305", active: true },
  { id: "sch-10", subjectId: "sub-cloud", weekday: 5, startTime: "15:30", endTime: "16:30", room: "Block B · 305", active: true },

  // Project: Mon, Thu 16:45 - 17:45
  { id: "sch-11", subjectId: "sub-proj", weekday: 1, startTime: "16:45", endTime: "17:45", room: "Project Lab", active: true },
  { id: "sch-12", subjectId: "sub-proj", weekday: 4, startTime: "16:45", endTime: "17:45", room: "Project Lab", active: true },
];

export class IndexedDBDataRepository implements DataRepository {
  private db: IDBDatabase | null = null;
  private memoryStore = {
    subjects: [...STARTER_SUBJECTS],
    schedules: [...STARTER_SCHEDULES],
    occurrences: [] as ClassOccurrence[],
    attendance: [] as AttendanceRecord[],
    semester: { ...INITIAL_SEMESTER },
    preferences: { ...DEFAULT_PREFERENCES },
  };

  async init(): Promise<void> {
    if (typeof window === "undefined" || !window.indexedDB) {
      // In-memory mode (SSR / Node test environment)
      return;
    }

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;

        if (!db.objectStoreNames.contains("subjects")) {
          db.createObjectStore("subjects", { keyPath: "id" });
        }
        if (!db.objectStoreNames.contains("schedules")) {
          const store = db.createObjectStore("schedules", { keyPath: "id" });
          store.createIndex("subjectId", "subjectId", { unique: false });
        }
        if (!db.objectStoreNames.contains("occurrences")) {
          const store = db.createObjectStore("occurrences", { keyPath: "id" });
          store.createIndex("subjectId", "subjectId", { unique: false });
          store.createIndex("date", "date", { unique: false });
        }
        if (!db.objectStoreNames.contains("attendance")) {
          const store = db.createObjectStore("attendance", { keyPath: "id" });
          store.createIndex("classOccurrenceId", "classOccurrenceId", { unique: true });
        }
        if (!db.objectStoreNames.contains("metadata")) {
          db.createObjectStore("metadata", { keyPath: "key" });
        }
      };

      request.onsuccess = async () => {
        this.db = request.result;
        await this.bootstrapDefaultData();
        resolve();
      };

      request.onerror = () => {
        console.warn("IndexedDB failed to open, falling back to in-memory/localStorage", request.error);
        resolve();
      };
    });
  }

  private async bootstrapDefaultData(): Promise<void> {
    const subjects = await this.getSubjects();
    if (subjects.length === 0) {
      // Check if we can migrate from localStorage
      const migrated = this.tryMigrateFromLocalStorage();
      if (migrated) {
        await this.importData(migrated);
      } else {
        // First-time setup
        for (const s of STARTER_SUBJECTS) {
          await this.createSubject(s);
        }
        for (const sch of STARTER_SCHEDULES) {
          await this.createSchedule(sch);
        }
        await this.updateSemester(INITIAL_SEMESTER);
        await this.updatePreferences(DEFAULT_PREFERENCES);
      }
    }
  }

  private tryMigrateFromLocalStorage(): ExportedData | null {
    try {
      const raw = localStorage.getItem("presence.attendance.v2") || localStorage.getItem("attendance.v1");
      if (!raw) return null;
      const parsed = JSON.parse(raw);

      if (parsed.subjects && Array.isArray(parsed.subjects)) {
        const occurrences: ClassOccurrence[] = [];
        const attendanceRecords: AttendanceRecord[] = [];

        // Migrate records from old format if any
        if (Array.isArray(parsed.records)) {
          for (const r of parsed.records) {
            if (r.id && r.subjectId && r.date) {
              const occId = `occ-mig-${r.id}`;
              occurrences.push({
                id: occId,
                subjectId: r.subjectId,
                date: r.date,
                scheduleId: r.scheduleId,
                startTime: r.scheduledStartTime || "09:00",
                endTime: "10:00",
                isExtra: r.status === "extra",
                state: "conducted",
                createdAt: r.createdAt || new Date().toISOString(),
                updatedAt: r.createdAt || new Date().toISOString(),
              });
              attendanceRecords.push({
                id: `att-mig-${r.id}`,
                classOccurrenceId: occId,
                status: r.status === "missed" ? "missed" : "present",
                notes: r.notes,
                createdAt: r.createdAt || new Date().toISOString(),
                updatedAt: r.createdAt || new Date().toISOString(),
              });
            }
          }
        }

        return {
          version: 2,
          exportedAt: new Date().toISOString(),
          semester: parsed.semester || INITIAL_SEMESTER,
          subjects: parsed.subjects,
          schedules: parsed.schedules || STARTER_SCHEDULES,
          classOccurrences: occurrences,
          attendanceRecords,
          preferences: { ...DEFAULT_PREFERENCES, ...(parsed.preferences || {}) },
        };
      }
    } catch {
      // Ignore migration errors
    }
    return null;
  }

  private async getAllFromStore<T>(storeName: string): Promise<T[]> {
    if (!this.db) {
      if (storeName === "subjects") return [...this.memoryStore.subjects] as unknown as T[];
      if (storeName === "schedules") return [...this.memoryStore.schedules] as unknown as T[];
      if (storeName === "occurrences") return [...this.memoryStore.occurrences] as unknown as T[];
      if (storeName === "attendance") return [...this.memoryStore.attendance] as unknown as T[];
      return [];
    }

    return new Promise((resolve, reject) => {
      const tx = this.db!.transaction(storeName, "readonly");
      const store = tx.objectStore(storeName);
      const req = store.getAll();
      req.onsuccess = () => resolve(req.result as T[]);
      req.onerror = () => reject(req.error);
    });
  }

  private async putInStore<T>(storeName: string, item: T): Promise<T> {
    if (!this.db) {
      const anyItem = item as any;
      if (storeName === "subjects") {
        this.memoryStore.subjects = this.memoryStore.subjects.filter((s) => s.id !== anyItem.id);
        this.memoryStore.subjects.push(anyItem);
      } else if (storeName === "schedules") {
        this.memoryStore.schedules = this.memoryStore.schedules.filter((s) => s.id !== anyItem.id);
        this.memoryStore.schedules.push(anyItem);
      } else if (storeName === "occurrences") {
        this.memoryStore.occurrences = this.memoryStore.occurrences.filter((o) => o.id !== anyItem.id);
        this.memoryStore.occurrences.push(anyItem);
      } else if (storeName === "attendance") {
        this.memoryStore.attendance = this.memoryStore.attendance.filter((a) => a.id !== anyItem.id);
        this.memoryStore.attendance.push(anyItem);
      }
      return item;
    }

    return new Promise((resolve, reject) => {
      const tx = this.db!.transaction(storeName, "readwrite");
      const store = tx.objectStore(storeName);
      const req = store.put(item);
      req.onsuccess = () => resolve(item);
      req.onerror = () => reject(req.error);
    });
  }

  private async deleteFromStore(storeName: string, id: string): Promise<void> {
    if (!this.db) {
      if (storeName === "subjects") this.memoryStore.subjects = this.memoryStore.subjects.filter((s) => s.id !== id);
      if (storeName === "schedules") this.memoryStore.schedules = this.memoryStore.schedules.filter((s) => s.id !== id);
      if (storeName === "occurrences") this.memoryStore.occurrences = this.memoryStore.occurrences.filter((o) => o.id !== id);
      if (storeName === "attendance") this.memoryStore.attendance = this.memoryStore.attendance.filter((a) => a.id !== id);
      return;
    }

    return new Promise((resolve, reject) => {
      const tx = this.db!.transaction(storeName, "readwrite");
      const store = tx.objectStore(storeName);
      const req = store.delete(id);
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  }

  // Subjects
  async getSubjects(): Promise<Subject[]> {
    return this.getAllFromStore<Subject>("subjects");
  }

  async createSubject(subject: Subject): Promise<Subject> {
    return this.putInStore<Subject>("subjects", subject);
  }

  async updateSubject(subject: Subject): Promise<Subject> {
    return this.putInStore<Subject>("subjects", subject);
  }

  async deleteSubject(subjectId: string): Promise<void> {
    // 1. Delete subject
    await this.deleteFromStore("subjects", subjectId);

    // 2. Cascade delete schedules
    const schedules = await this.getSchedules();
    const subSchedules = schedules.filter((s) => s.subjectId === subjectId);
    for (const sch of subSchedules) {
      await this.deleteSchedule(sch.id);
    }

    // 3. Cascade delete occurrences & their attendance records
    const occurrences = await this.getClassOccurrences();
    const subOccurrences = occurrences.filter((o) => o.subjectId === subjectId);
    for (const occ of subOccurrences) {
      await this.deleteClassOccurrence(occ.id);
    }
  }

  // Schedules
  async getSchedules(): Promise<ClassSchedule[]> {
    return this.getAllFromStore<ClassSchedule>("schedules");
  }

  async createSchedule(schedule: ClassSchedule): Promise<ClassSchedule> {
    return this.putInStore<ClassSchedule>("schedules", schedule);
  }

  async updateSchedule(schedule: ClassSchedule): Promise<ClassSchedule> {
    return this.putInStore<ClassSchedule>("schedules", schedule);
  }

  async deleteSchedule(scheduleId: string): Promise<void> {
    await this.deleteFromStore("schedules", scheduleId);
  }

  // Class Occurrences
  async getClassOccurrences(): Promise<ClassOccurrence[]> {
    return this.getAllFromStore<ClassOccurrence>("occurrences");
  }

  async createClassOccurrence(occurrence: ClassOccurrence): Promise<ClassOccurrence> {
    return this.putInStore<ClassOccurrence>("occurrences", occurrence);
  }

  async updateClassOccurrence(occurrence: ClassOccurrence): Promise<ClassOccurrence> {
    return this.putInStore<ClassOccurrence>("occurrences", occurrence);
  }

  async deleteClassOccurrence(occurrenceId: string): Promise<void> {
    // Delete associated attendance record
    const records = await this.getAttendanceRecords();
    const related = records.find((r) => r.classOccurrenceId === occurrenceId);
    if (related) {
      await this.deleteAttendanceRecord(related.id);
    }
    await this.deleteFromStore("occurrences", occurrenceId);
  }

  // Attendance Records
  async getAttendanceRecords(): Promise<AttendanceRecord[]> {
    return this.getAllFromStore<AttendanceRecord>("attendance");
  }

  async createAttendanceRecord(record: AttendanceRecord): Promise<AttendanceRecord> {
    return this.putInStore<AttendanceRecord>("attendance", record);
  }

  async updateAttendanceRecord(record: AttendanceRecord): Promise<AttendanceRecord> {
    return this.putInStore<AttendanceRecord>("attendance", record);
  }

  async deleteAttendanceRecord(recordId: string): Promise<void> {
    await this.deleteFromStore("attendance", recordId);
  }

  // Semester
  async getSemester(): Promise<Semester> {
    if (!this.db) return { ...this.memoryStore.semester };
    return new Promise((resolve) => {
      const tx = this.db!.transaction("metadata", "readonly");
      const store = tx.objectStore("metadata");
      const req = store.get("semester");
      req.onsuccess = () => {
        if (req.result && req.result.data) {
          resolve(req.result.data as Semester);
        } else {
          resolve(INITIAL_SEMESTER);
        }
      };
      req.onerror = () => resolve(INITIAL_SEMESTER);
    });
  }

  async updateSemester(semester: Semester): Promise<Semester> {
    if (!this.db) {
      this.memoryStore.semester = { ...semester };
      return semester;
    }
    return new Promise((resolve, reject) => {
      const tx = this.db!.transaction("metadata", "readwrite");
      const store = tx.objectStore("metadata");
      const req = store.put({ key: "semester", data: semester });
      req.onsuccess = () => resolve(semester);
      req.onerror = () => reject(req.error);
    });
  }

  // Preferences
  async getPreferences(): Promise<UserPreferences> {
    if (!this.db) return { ...this.memoryStore.preferences };
    return new Promise((resolve) => {
      const tx = this.db!.transaction("metadata", "readonly");
      const store = tx.objectStore("metadata");
      const req = store.get("preferences");
      req.onsuccess = () => {
        if (req.result && req.result.data) {
          resolve({ ...DEFAULT_PREFERENCES, ...req.result.data });
        } else {
          resolve(DEFAULT_PREFERENCES);
        }
      };
      req.onerror = () => resolve(DEFAULT_PREFERENCES);
    });
  }

  async updatePreferences(preferences: Partial<UserPreferences>): Promise<UserPreferences> {
    const current = await this.getPreferences();
    const updated = { ...current, ...preferences };
    if (!this.db) {
      this.memoryStore.preferences = updated;
      return updated;
    }
    return new Promise((resolve, reject) => {
      const tx = this.db!.transaction("metadata", "readwrite");
      const store = tx.objectStore("metadata");
      const req = store.put({ key: "preferences", data: updated });
      req.onsuccess = () => resolve(updated);
      req.onerror = () => reject(req.error);
    });
  }

  // Export / Import / Reset
  async exportData(): Promise<ExportedData> {
    const [semester, subjects, schedules, classOccurrences, attendanceRecords, preferences] = await Promise.all([
      this.getSemester(),
      this.getSubjects(),
      this.getSchedules(),
      this.getClassOccurrences(),
      this.getAttendanceRecords(),
      this.getPreferences(),
    ]);

    return {
      version: 2,
      exportedAt: new Date().toISOString(),
      semester,
      subjects,
      schedules,
      classOccurrences,
      attendanceRecords,
      preferences,
    };
  }

  async importData(data: ExportedData): Promise<void> {
    if (!data || !Array.isArray(data.subjects)) {
      throw new Error("Invalid backup data format");
    }

    // Clear all existing stores
    await this.clearStore("subjects");
    await this.clearStore("schedules");
    await this.clearStore("occurrences");
    await this.clearStore("attendance");

    for (const sub of data.subjects) {
      await this.createSubject(sub);
    }
    for (const sch of data.schedules || []) {
      await this.createSchedule(sch);
    }
    for (const occ of data.classOccurrences || []) {
      await this.createClassOccurrence(occ);
    }
    for (const att of data.attendanceRecords || []) {
      await this.createAttendanceRecord(att);
    }
    if (data.semester) {
      await this.updateSemester(data.semester);
    }
    if (data.preferences) {
      await this.updatePreferences(data.preferences);
    }
  }

  async resetAllAttendance(): Promise<void> {
    await this.clearStore("occurrences");
    await this.clearStore("attendance");
  }

  private async clearStore(storeName: string): Promise<void> {
    if (!this.db) {
      if (storeName === "subjects") this.memoryStore.subjects = [];
      if (storeName === "schedules") this.memoryStore.schedules = [];
      if (storeName === "occurrences") this.memoryStore.occurrences = [];
      if (storeName === "attendance") this.memoryStore.attendance = [];
      return;
    }
    return new Promise((resolve, reject) => {
      const tx = this.db!.transaction(storeName, "readwrite");
      const store = tx.objectStore(storeName);
      const req = store.clear();
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  }
}

export const dataRepository: DataRepository = new IndexedDBDataRepository();
