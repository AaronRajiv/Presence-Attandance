import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  Subject,
  ClassSchedule,
  ClassOccurrence,
  AttendanceRecord,
  AttendanceStatus,
  OccurrenceState,
  Semester,
  UserPreferences,
  SubjectStats,
  OverallStats,
  DayClassItem,
  ExportedData,
} from "./types";
import { DataRepository } from "./repository/DataRepository";
import {
  dataRepository,
  DEFAULT_PREFERENCES,
  INITIAL_SEMESTER,
} from "./repository/IndexedDBDataRepository";
import {
  formatISODate,
  getNextClassForSubject,
  getLiveDayStatus,
  getClassesForDate,
} from "./timetableEngine";
import {
  calculateSubjectStats,
  calculateOverallStats,
} from "./statsEngine";
import { notificationService } from "./notificationService";

export * from "./types";
export { formatISODate as iso, getNextClassForSubject as nextClass } from "./timetableEngine";

interface UndoStateSnapshot {
  occurrences: ClassOccurrence[];
  attendanceRecords: AttendanceRecord[];
  description: string;
}

interface AttendanceContextType {
  subjects: Subject[];
  schedules: ClassSchedule[];
  occurrences: ClassOccurrence[];
  attendanceRecords: AttendanceRecord[];
  semester: Semester;
  prefs: UserPreferences;
  loading: boolean;

  // Stats
  stats: (subjectId: string) => SubjectStats;
  overallStats: () => OverallStats;

  // Occurrence & Attendance Logging
  markOccurrenceAttendance: (
    item: DayClassItem,
    status: AttendanceStatus,
    notes?: string | undefined
  ) => Promise<void>;
  cancelOccurrence: (item: DayClassItem, reason?: string | undefined) => Promise<void>;
  uncancelOccurrence: (occurrenceId: string) => Promise<void>;
  unmarkOccurrence: (occurrenceId: string) => Promise<void>;
  addExtraClass: (
    subjectId: string,
    date: string,
    startTime: string,
    endTime?: string | undefined,
    status?: AttendanceStatus | undefined,
    notes?: string | undefined
  ) => Promise<void>;

  // Undo
  undoLastAction: () => Promise<void>;
  canUndo: boolean;
  lastActionText: string | null;

  // Subject CRUD
  addSubject: (
    subject: Omit<Subject, "id" | "createdAt" | "updatedAt">,
    newSchedules: { weekday: number; startTime: string; endTime: string; room: string }[]
  ) => Promise<void>;
  updateSubject: (
    subject: Subject,
    updatedSchedules: { id?: string | undefined; weekday: number; startTime: string; endTime: string; room: string; active?: boolean | undefined }[]
  ) => Promise<void>;
  deleteSubject: (subjectId: string) => Promise<void>;

  // Settings
  setPrefs: (p: Partial<UserPreferences>) => Promise<void>;
  setSemester: (sem: Semester) => Promise<void>;
  reset: () => Promise<void>;
  importData: (data: ExportedData) => Promise<void>;
  exportData: () => Promise<ExportedData>;
}

const AttendanceContext = createContext<AttendanceContextType | null>(null);

export function AttendanceProvider({
  children,
  repository = dataRepository,
}: {
  children: ReactNode;
  repository?: DataRepository;
}) {
  const [loading, setLoading] = useState(true);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [schedules, setSchedules] = useState<ClassSchedule[]>([]);
  const [occurrences, setOccurrences] = useState<ClassOccurrence[]>([]);
  const [attendanceRecords, setAttendanceRecords] = useState<AttendanceRecord[]>([]);
  const [semester, setSemesterState] = useState<Semester>(INITIAL_SEMESTER);
  const [prefs, setPrefsState] = useState<UserPreferences>(DEFAULT_PREFERENCES);

  const [undoStack, setUndoStack] = useState<UndoStateSnapshot[]>([]);

  // Initialize repository and load state
  const reloadFromRepo = useCallback(async () => {
    try {
      const [subs, schs, occs, atts, sem, preferences] = await Promise.all([
        repository.getSubjects(),
        repository.getSchedules(),
        repository.getClassOccurrences(),
        repository.getAttendanceRecords(),
        repository.getSemester(),
        repository.getPreferences(),
      ]);

      setSubjects(subs);
      setSchedules(schs);
      setOccurrences(occs);
      setAttendanceRecords(atts);
      setSemesterState(sem);
      setPrefsState(preferences);
    } catch (err) {
      console.error("Failed to load from repository:", err);
    } finally {
      setLoading(false);
    }
  }, [repository]);

  useEffect(() => {
    (async () => {
      await repository.init();
      await reloadFromRepo();
    })();
  }, [repository, reloadFromRepo]);

  // Apply appearance (Dark/Light) and accent color CSS variables
  useEffect(() => {
    document.documentElement.classList.toggle("dark", prefs.appearance === "dark");
    document.documentElement.style.setProperty("--accent-live", prefs.accent);
  }, [prefs.appearance, prefs.accent]);

  // Web notifications scheduling
  useEffect(() => {
    if (prefs.notifications) {
      notificationService.scheduleDayReminders(subjects, schedules, prefs.reminderMinutes);
    } else {
      notificationService.clearAll();
    }
    return () => notificationService.clearAll();
  }, [subjects, schedules, prefs.notifications, prefs.reminderMinutes]);

  const pushUndo = useCallback((description: string) => {
    setUndoStack((prev) => [
      ...prev.slice(-9),
      {
        occurrences: [...occurrences],
        attendanceRecords: [...attendanceRecords],
        description,
      },
    ]);
  }, [occurrences, attendanceRecords]);

  // Mark occurrence attendance (Present / Missed)
  const markOccurrenceAttendance = useCallback(
    async (item: DayClassItem, status: AttendanceStatus, notes?: string | undefined) => {
      const subjectName = item.subject.short || "Class";
      pushUndo(`Marked ${subjectName} as ${status}`);

      let occId = item.occurrence.id;
      const isVirtual = occId.startsWith("virt-");

      // 1. Ensure a real ClassOccurrence exists in repository
      if (isVirtual) {
        occId = `occ-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
        const newOcc: ClassOccurrence = {
          id: occId,
          subjectId: item.occurrence.subjectId,
          date: item.occurrence.date,
          scheduleId: item.occurrence.scheduleId,
          startTime: item.occurrence.startTime,
          endTime: item.occurrence.endTime,
          room: item.occurrence.room,
          isExtra: false,
          state: "conducted",
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
        await repository.createClassOccurrence(newOcc);
      } else {
        const updatedOcc: ClassOccurrence = {
          ...item.occurrence,
          state: "conducted",
          cancellationReason: undefined,
          updatedAt: new Date().toISOString(),
        };
        await repository.updateClassOccurrence(updatedOcc);
      }

      // 2. Create or update AttendanceRecord
      const existing = attendanceRecords.find((r) => r.classOccurrenceId === (isVirtual ? occId : item.occurrence.id));
      if (existing) {
        if (existing.status === status) {
          // Toggled off: remove attendance and revert occurrence to scheduled if regular
          await repository.deleteAttendanceRecord(existing.id);
          if (!item.occurrence.isExtra) {
            await repository.updateClassOccurrence({
              ...item.occurrence,
              id: occId,
              state: "scheduled",
              updatedAt: new Date().toISOString(),
            });
          }
        } else {
          await repository.updateAttendanceRecord({
            ...existing,
            status,
            notes: notes !== undefined ? notes : existing.notes,
            updatedAt: new Date().toISOString(),
          });
        }
      } else {
        const newRec: AttendanceRecord = {
          id: `att-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
          classOccurrenceId: occId,
          status,
          notes,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
        await repository.createAttendanceRecord(newRec);
      }

      await reloadFromRepo();
    },
    [pushUndo, attendanceRecords, repository, reloadFromRepo]
  );

  // Cancel class occurrence (e.g. Holiday, Faculty absent)
  const cancelOccurrence = useCallback(
    async (item: DayClassItem, reason?: string | undefined) => {
      const subjectName = item.subject.short || "Class";
      pushUndo(`Cancelled ${subjectName}`);

      let occId = item.occurrence.id;
      const isVirtual = occId.startsWith("virt-");

      if (isVirtual) {
        occId = `occ-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
        const newOcc: ClassOccurrence = {
          id: occId,
          subjectId: item.occurrence.subjectId,
          date: item.occurrence.date,
          scheduleId: item.occurrence.scheduleId,
          startTime: item.occurrence.startTime,
          endTime: item.occurrence.endTime,
          room: item.occurrence.room,
          isExtra: false,
          state: "cancelled",
          cancellationReason: reason || "Class Cancelled",
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };
        await repository.createClassOccurrence(newOcc);
      } else {
        // If there was an attendance record, remove it
        const existingAtt = attendanceRecords.find((r) => r.classOccurrenceId === occId);
        if (existingAtt) {
          await repository.deleteAttendanceRecord(existingAtt.id);
        }
        await repository.updateClassOccurrence({
          ...item.occurrence,
          state: "cancelled",
          cancellationReason: reason || "Class Cancelled",
          updatedAt: new Date().toISOString(),
        });
      }

      await reloadFromRepo();
    },
    [pushUndo, attendanceRecords, repository, reloadFromRepo]
  );

  const uncancelOccurrence = useCallback(
    async (occurrenceId: string) => {
      const occ = occurrences.find((o) => o.id === occurrenceId);
      if (!occ) return;

      pushUndo("Restored cancelled class");
      await repository.updateClassOccurrence({
        ...occ,
        state: "scheduled",
        cancellationReason: undefined,
        updatedAt: new Date().toISOString(),
      });
      await reloadFromRepo();
    },
    [pushUndo, occurrences, repository, reloadFromRepo]
  );

  const unmarkOccurrence = useCallback(
    async (occurrenceId: string) => {
      const existing = attendanceRecords.find((r) => r.classOccurrenceId === occurrenceId);
      if (existing) {
        pushUndo("Cleared attendance");
        await repository.deleteAttendanceRecord(existing.id);

        const occ = occurrences.find((o) => o.id === occurrenceId);
        if (occ && !occ.isExtra) {
          await repository.updateClassOccurrence({
            ...occ,
            state: "scheduled",
            updatedAt: new Date().toISOString(),
          });
        }
        await reloadFromRepo();
      }
    },
    [pushUndo, attendanceRecords, occurrences, repository, reloadFromRepo]
  );

  // Add Extra Class
  const addExtraClass = useCallback(
    async (
      subjectId: string,
      date: string,
      startTime: string,
      endTime?: string | undefined,
      status: AttendanceStatus = "present",
      notes?: string | undefined
    ) => {
      const subject = subjects.find((s) => s.id === subjectId);
      const subName = subject?.short || "Extra Class";
      pushUndo(`Added extra class for ${subName}`);

      const occId = `extra-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
      const now = new Date().toISOString();

      const newOcc: ClassOccurrence = {
        id: occId,
        subjectId,
        date,
        startTime,
        endTime: endTime || startTime,
        room: subject?.room,
        isExtra: true,
        state: "conducted",
        createdAt: now,
        updatedAt: now,
      };

      const newAtt: AttendanceRecord = {
        id: `att-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
        classOccurrenceId: occId,
        status,
        notes,
        createdAt: now,
        updatedAt: now,
      };

      await repository.createClassOccurrence(newOcc);
      await repository.createAttendanceRecord(newAtt);
      await reloadFromRepo();
    },
    [pushUndo, subjects, repository, reloadFromRepo]
  );

  // Undo
  const undoLastAction = useCallback(async () => {
    if (undoStack.length === 0) return;
    const last = undoStack[undoStack.length - 1];
    if (!last) return;

    // Restore occurrences and attendance records in repository
    // 1. Clear current
    await repository.resetAllAttendance();

    // 2. Repopulate snapshot
    for (const occ of last.occurrences) {
      await repository.createClassOccurrence(occ);
    }
    for (const att of last.attendanceRecords) {
      await repository.createAttendanceRecord(att);
    }

    setUndoStack((prev) => prev.slice(0, -1));
    await reloadFromRepo();
  }, [undoStack, repository, reloadFromRepo]);

  // Subject CRUD
  const addSubject = useCallback(
    async (
      subjectData: Omit<Subject, "id" | "createdAt" | "updatedAt">,
      newSchedules: { weekday: number; startTime: string; endTime: string; room: string }[]
    ) => {
      const subjectId = `sub-${Date.now()}`;
      const now = new Date().toISOString();

      const newSubject: Subject = {
        ...subjectData,
        id: subjectId,
        createdAt: now,
        updatedAt: now,
      };

      await repository.createSubject(newSubject);

      for (let i = 0; i < newSchedules.length; i++) {
        const sch = newSchedules[i];
        if (sch) {
          await repository.createSchedule({
            id: `sch-${Date.now()}-${i}`,
            subjectId,
            weekday: sch.weekday,
            startTime: sch.startTime,
            endTime: sch.endTime,
            room: sch.room || subjectData.room || "Classroom",
            active: true,
          });
        }
      }

      await reloadFromRepo();
    },
    [repository, reloadFromRepo]
  );

  const updateSubject = useCallback(
    async (
      subject: Subject,
      updatedSchedules: { id?: string | undefined; weekday: number; startTime: string; endTime: string; room: string; active?: boolean | undefined }[]
    ) => {
      await repository.updateSubject({
        ...subject,
        updatedAt: new Date().toISOString(),
      });

      // Remove existing schedules for this subject
      const existingSchs = schedules.filter((s) => s.subjectId === subject.id);
      for (const sch of existingSchs) {
        await repository.deleteSchedule(sch.id);
      }

      // Add updated schedules (preserves historical occurrences!)
      for (let i = 0; i < updatedSchedules.length; i++) {
        const sch = updatedSchedules[i];
        if (sch) {
          await repository.createSchedule({
            id: sch.id || `sch-${Date.now()}-${i}`,
            subjectId: subject.id,
            weekday: sch.weekday,
            startTime: sch.startTime,
            endTime: sch.endTime,
            room: sch.room || subject.room || "Classroom",
            active: sch.active ?? true,
          });
        }
      }

      await reloadFromRepo();
    },
    [schedules, repository, reloadFromRepo]
  );

  const deleteSubject = useCallback(
    async (subjectId: string) => {
      await repository.deleteSubject(subjectId);
      await reloadFromRepo();
    },
    [repository, reloadFromRepo]
  );

  const setPrefs = useCallback(
    async (p: Partial<UserPreferences>) => {
      await repository.updatePreferences(p);
      await reloadFromRepo();
    },
    [repository, reloadFromRepo]
  );

  const setSemester = useCallback(
    async (sem: Semester) => {
      await repository.updateSemester(sem);
      await reloadFromRepo();
    },
    [repository, reloadFromRepo]
  );

  const reset = useCallback(async () => {
    await repository.resetAllAttendance();
    setUndoStack([]);
    await reloadFromRepo();
  }, [repository, reloadFromRepo]);

  const importData = useCallback(
    async (data: ExportedData) => {
      await repository.importData(data);
      setUndoStack([]);
      await reloadFromRepo();
    },
    [repository, reloadFromRepo]
  );

  const exportData = useCallback(async () => {
    return repository.exportData();
  }, [repository]);

  // Statistics
  const stats = useCallback(
    (subjectId: string) => {
      return calculateSubjectStats(
        subjectId,
        occurrences,
        attendanceRecords,
        schedules,
        semester,
        prefs.target
      );
    },
    [occurrences, attendanceRecords, schedules, semester, prefs.target]
  );

  const overallStats = useCallback(() => {
    return calculateOverallStats(
      subjects,
      occurrences,
      attendanceRecords,
      schedules,
      semester,
      prefs.target
    );
  }, [subjects, occurrences, attendanceRecords, schedules, semester, prefs.target]);

  const lastEntry = undoStack.length > 0 ? undoStack[undoStack.length - 1] : undefined;

  const value = useMemo<AttendanceContextType>(
    () => ({
      subjects,
      schedules,
      occurrences,
      attendanceRecords,
      semester,
      prefs,
      loading,
      stats,
      overallStats,
      markOccurrenceAttendance,
      cancelOccurrence,
      uncancelOccurrence,
      unmarkOccurrence,
      addExtraClass,
      undoLastAction,
      canUndo: undoStack.length > 0,
      lastActionText: lastEntry ? lastEntry.description : null,
      addSubject,
      updateSubject,
      deleteSubject,
      setPrefs,
      setSemester,
      reset,
      importData,
      exportData,
    }),
    [
      subjects,
      schedules,
      occurrences,
      attendanceRecords,
      semester,
      prefs,
      loading,
      stats,
      overallStats,
      markOccurrenceAttendance,
      cancelOccurrence,
      uncancelOccurrence,
      unmarkOccurrence,
      addExtraClass,
      undoLastAction,
      undoStack.length,
      lastEntry,
      addSubject,
      updateSubject,
      deleteSubject,
      setPrefs,
      setSemester,
      reset,
      importData,
      exportData,
    ]
  );

  return <AttendanceContext.Provider value={value}>{children}</AttendanceContext.Provider>;
}

export function useAttendance() {
  const ctx = useContext(AttendanceContext);
  if (!ctx) throw new Error("useAttendance must be used inside AttendanceProvider");
  return ctx;
}

export function haptic(ms = 8) {
  if (typeof navigator !== "undefined" && "vibrate" in navigator) {
    try {
      navigator.vibrate?.(ms);
    } catch {
      // ignore
    }
  }
}
