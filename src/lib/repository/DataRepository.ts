import {
  Subject,
  ClassSchedule,
  ClassOccurrence,
  AttendanceRecord,
  Semester,
  UserPreferences,
  ExportedData,
} from "../types";

export interface DataRepository {
  init(): Promise<void>;

  // Subjects
  getSubjects(): Promise<Subject[]>;
  createSubject(subject: Subject): Promise<Subject>;
  updateSubject(subject: Subject): Promise<Subject>;
  deleteSubject(subjectId: string): Promise<void>;

  // Schedules
  getSchedules(): Promise<ClassSchedule[]>;
  createSchedule(schedule: ClassSchedule): Promise<ClassSchedule>;
  updateSchedule(schedule: ClassSchedule): Promise<ClassSchedule>;
  deleteSchedule(scheduleId: string): Promise<void>;

  // Class Occurrences
  getClassOccurrences(): Promise<ClassOccurrence[]>;
  createClassOccurrence(occurrence: ClassOccurrence): Promise<ClassOccurrence>;
  updateClassOccurrence(occurrence: ClassOccurrence): Promise<ClassOccurrence>;
  deleteClassOccurrence(occurrenceId: string): Promise<void>;

  // Attendance Records
  getAttendanceRecords(): Promise<AttendanceRecord[]>;
  createAttendanceRecord(record: AttendanceRecord): Promise<AttendanceRecord>;
  updateAttendanceRecord(record: AttendanceRecord): Promise<AttendanceRecord>;
  deleteAttendanceRecord(recordId: string): Promise<void>;

  // Semester
  getSemester(): Promise<Semester>;
  updateSemester(semester: Semester): Promise<Semester>;

  // Preferences
  getPreferences(): Promise<UserPreferences>;
  updatePreferences(preferences: Partial<UserPreferences>): Promise<UserPreferences>;

  // Import / Export / Reset
  exportData(): Promise<ExportedData>;
  importData(data: ExportedData): Promise<void>;
  resetAllAttendance(): Promise<void>;
}
