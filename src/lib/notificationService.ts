import { ClassSchedule, Subject } from "./types";
import { parseTimeInMinutes } from "./timetableEngine";

class NotificationService {
  private scheduledTimers: number[] = [];

  async requestPermission(): Promise<boolean> {
    if (typeof window === "undefined" || !("Notification" in window)) {
      return false;
    }
    try {
      const permission = await Notification.requestPermission();
      return permission === "granted";
    } catch {
      return false;
    }
  }

  isPermissionGranted(): boolean {
    if (typeof window === "undefined" || !("Notification" in window)) {
      return false;
    }
    return Notification.permission === "granted";
  }

  notifyClass(subjectName: string, room: string, time: string, minutesBefore: number) {
    if (!this.isPermissionGranted()) return;

    try {
      new Notification(`Upcoming Class: ${subjectName}`, {
        body: `Starts in ${minutesBefore} mins at ${time} (${room})`,
        icon: "/favicon.ico",
        badge: "/favicon.ico",
        tag: `class-${subjectName}-${time}`,
      });
    } catch (e) {
      console.warn("Notification error:", e);
    }
  }

  scheduleDayReminders(
    subjects: Subject[],
    schedules: ClassSchedule[],
    reminderMinutes = 15
  ) {
    // Clear previously scheduled timers
    this.clearAll();

    if (!this.isPermissionGranted()) return;

    const now = new Date();
    const todayWeekday = now.getDay();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();
    const currentSeconds = now.getSeconds();

    const subjectMap = new Map(subjects.map((s) => [s.id, s]));
    const daySchedules = schedules.filter((s) => s.active && s.weekday === todayWeekday);

    for (const sch of daySchedules) {
      const subject = subjectMap.get(sch.subjectId);
      if (!subject) continue;

      const classMin = parseTimeInMinutes(sch.startTime);
      const reminderMin = classMin - reminderMinutes;

      if (reminderMin > currentMinutes) {
        const msUntilReminder = ((reminderMin - currentMinutes) * 60 - currentSeconds) * 1000;
        const timerId = window.setTimeout(() => {
          this.notifyClass(subject.name, sch.room || subject.room || "Classroom", sch.startTime, reminderMinutes);
        }, msUntilReminder);

        this.scheduledTimers.push(timerId);
      }
    }
  }

  clearAll() {
    for (const timer of this.scheduledTimers) {
      window.clearTimeout(timer);
    }
    this.scheduledTimers = [];
  }
}

export const notificationService = new NotificationService();
