import { useMemo } from "react";
import { motion } from "motion/react";
import { iso, Subject, useAttendance } from "@/lib/attendance";
import { isDateWithinSemester } from "@/lib/timetableEngine";

const WD = ["S", "M", "T", "W", "T", "F", "S"];

export function MonthCalendar({
  month,
  subject,
  selected,
  onSelect,
}: {
  month: Date;
  subject: Subject;
  selected?: string;
  onSelect?: (date: Date) => void;
}) {
  const { schedules, occurrences, attendanceRecords, semester } = useAttendance();

  const scheduledWeekdays = useMemo(() => {
    return new Set(
      schedules
        .filter((s) => s.subjectId === subject.id && s.active)
        .map((s) => s.weekday)
    );
  }, [schedules, subject.id]);

  const cells = useMemo(() => {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    const lead = first.getDay();
    return [
      ...Array.from({ length: lead }, () => null),
      ...Array.from({ length: days }, (_, i) => new Date(month.getFullYear(), month.getMonth(), i + 1)),
    ];
  }, [month]);

  const attendanceMap = useMemo(() => {
    return new Map(attendanceRecords.map((r) => [r.classOccurrenceId, r.status]));
  }, [attendanceRecords]);

  const todayIso = iso(new Date());

  return (
    <div>
      <div className="mb-2 grid grid-cols-7 gap-y-1 text-center">
        {WD.map((d, i) => (
          <span key={i} className="text-caption font-semibold text-muted-foreground">
            {d}
          </span>
        ))}
      </div>
      <div className="grid grid-cols-7 gap-y-1.5">
        {cells.map((d, i) => {
          if (!d) return <span key={i} />;
          const key = iso(d);
          const isWithinTerm = isDateWithinSemester(key, semester);
          const scheduled = isWithinTerm && scheduledWeekdays.has(d.getDay());
          const isToday = key === todayIso;
          const isSel = key === selected;

          // Find occurrence for this subject & date
          const dayOcc = occurrences.find((o) => o.subjectId === subject.id && o.date === key);
          const isCancelled = dayOcc?.state === "cancelled";
          const status = dayOcc ? attendanceMap.get(dayOcc.id) : undefined;

          return (
            <motion.button
              key={key}
              whileTap={{ scale: 0.86 }}
              transition={{ type: "spring", stiffness: 500, damping: 30 }}
              onClick={() => onSelect?.(d)}
              className="relative mx-auto grid size-9 place-items-center rounded-full"
            >
              {(isToday || isSel) && (
                <motion.span
                  layoutId="cal-selection"
                  className="absolute inset-0 rounded-full"
                  style={{
                    background: isSel
                      ? "var(--accent-live)"
                      : "color-mix(in oklab, var(--foreground) 12%, transparent)",
                  }}
                  transition={{ type: "spring", stiffness: 420, damping: 34 }}
                />
              )}
              <span
                className={`relative z-10 text-[15px] tabular-nums ${
                  isSel
                    ? "font-semibold text-primary-foreground"
                    : isToday
                      ? "font-bold text-primary"
                      : scheduled
                        ? "font-medium text-foreground"
                        : "text-muted-foreground/55"
                }`}
              >
                {d.getDate()}
              </span>

              {/* Status Dot */}
              {isCancelled ? (
                <span
                  className="absolute bottom-0 z-10 size-[5px] rounded-full"
                  style={{
                    background: "var(--ios-orange)",
                    boxShadow: "0 0 6px currentColor",
                  }}
                />
              ) : status ? (
                <span
                  className="absolute bottom-0 z-10 size-[5px] rounded-full"
                  style={{
                    background: status === "present" ? "var(--ios-green)" : "var(--ios-red)",
                    boxShadow: "0 0 6px currentColor",
                  }}
                />
              ) : null}
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}
