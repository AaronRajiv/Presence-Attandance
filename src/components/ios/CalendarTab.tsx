import { useMemo, useState } from "react";
import { motion, AnimatePresence, useReducedMotion } from "motion/react";
import {
  ChevronLeft,
  ChevronRight,
  Check,
  X,
  Ban,
  RotateCcw,
} from "lucide-react";
import {
  haptic,
  iso,
  useAttendance,
  Subject,
  DayClassItem,
} from "@/lib/attendance";
import { getClassesForDate, parseISODate } from "@/lib/timetableEngine";
import { SubjectWindow } from "./SubjectWindow";

const WD = ["S", "M", "T", "W", "T", "F", "S"];

export function CalendarTab() {
  const {
    subjects,
    schedules,
    occurrences,
    attendanceRecords,
    semester,
    markOccurrenceAttendance,
    cancelOccurrence,
    uncancelOccurrence,
  } = useAttendance();

  const [month, setMonth] = useState(() => new Date());
  const [selected, setSelected] = useState(() => iso(new Date()));
  const [inspectSubject, setInspectSubject] = useState<Subject | null>(null);
  const shouldReduceMotion = useReducedMotion();

  // Month day grid cells
  const cells = useMemo(() => {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    return [
      ...Array.from({ length: first.getDay() }, () => null),
      ...Array.from(
        { length: days },
        (_, i) => new Date(month.getFullYear(), month.getMonth(), i + 1)
      ),
    ];
  }, [month]);

  // Real class items for the selected date
  const dayClasses = useMemo(() => {
    return getClassesForDate(
      selected,
      subjects,
      schedules,
      occurrences,
      attendanceRecords,
      semester,
      new Date()
    );
  }, [selected, subjects, schedules, occurrences, attendanceRecords, semester]);

  const selDate = parseISODate(selected);
  const todayIso = iso(new Date());

  const attendanceMap = useMemo(() => {
    return new Map(attendanceRecords.map((r) => [r.classOccurrenceId, r.status]));
  }, [attendanceRecords]);

  return (
    <div className="px-5 pb-40 pt-3">
      {/* Header */}
      <header className="mb-5 flex items-end justify-between pt-1">
        <div>
          <p className="text-footnote font-semibold uppercase tracking-[0.14em] text-primary/90">
            {month.toLocaleString("en-US", { year: "numeric" })}
          </p>
          <h1 className="text-[28px] font-bold tracking-tight text-foreground leading-none mt-1">
            {month.toLocaleString("en-US", { month: "long" })}
          </h1>
        </div>

        {selected !== todayIso && (
          <button
            onClick={() => {
              haptic();
              const now = new Date();
              setMonth(new Date(now.getFullYear(), now.getMonth(), 1));
              setSelected(todayIso);
            }}
            className="glass rounded-full px-3 py-1 text-footnote font-semibold text-primary shadow-sm"
          >
            Today
          </button>
        )}
      </header>

      {/* Calendar Card */}
      <div className="glass rounded-[28px] px-4 py-5 shadow-sm">
        <div className="relative z-10">
          {/* Month Navigator */}
          <div className="mb-4 flex items-center justify-between">
            <span className="text-[15px] font-semibold pl-2 text-foreground">
              {month.toLocaleString("en-US", { month: "long", year: "numeric" })}
            </span>
            <div className="flex items-center gap-1">
              <motion.button
                whileTap={{ scale: 0.85 }}
                onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}
                className="grid size-8 place-items-center rounded-full text-muted-foreground"
              >
                <ChevronLeft className="size-4" />
              </motion.button>
              <motion.button
                whileTap={{ scale: 0.85 }}
                onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}
                className="grid size-8 place-items-center rounded-full text-muted-foreground"
              >
                <ChevronRight className="size-4" />
              </motion.button>
            </div>
          </div>

          {/* Weekday headers */}
          <div className="mb-2 grid grid-cols-7 text-center">
            {WD.map((d, i) => (
              <span key={i} className="text-caption font-semibold text-muted-foreground">
                {d}
              </span>
            ))}
          </div>

          {/* Days Grid */}
          <div className="grid grid-cols-7 gap-y-1.5">
            {cells.map((d, i) => {
              if (!d) return <span key={i} />;
              const key = iso(d);
              const isToday = key === todayIso;
              const isSel = key === selected;

              const dateOccurrences = occurrences.filter((o) => o.date === key);
              const hasPresent = dateOccurrences.some((o) => attendanceMap.get(o.id) === "present");
              const hasMissed = dateOccurrences.some((o) => attendanceMap.get(o.id) === "missed");
              const hasCancelled = dateOccurrences.some((o) => o.state === "cancelled");

              const selProps = shouldReduceMotion ? {} : { layoutId: "month-sel" };

              return (
                <motion.button
                  key={key}
                  whileTap={{ scale: 0.86 }}
                  onClick={() => {
                    haptic();
                    setSelected(key);
                  }}
                  className="relative mx-auto grid size-10 place-items-center rounded-full focus:outline-none"
                >
                  {(isToday || isSel) && (
                    <motion.span
                      {...selProps}
                      className="absolute inset-0 rounded-full"
                      style={{
                        background: isSel
                          ? "var(--accent-live)"
                          : "color-mix(in oklab, var(--foreground) 10%, transparent)",
                      }}
                      transition={{ type: "spring", stiffness: 380, damping: 32 }}
                    />
                  )}
                  <span
                    className={`relative z-10 text-[15px] tabular-nums ${
                      isSel ? "font-semibold text-primary-foreground" : "text-foreground"
                    }`}
                  >
                    {d.getDate()}
                  </span>

                  {/* Status Dots */}
                  <span className="absolute bottom-1 z-10 flex gap-[3px]">
                    {hasPresent && (
                      <span className="size-[4px] rounded-full" style={{ background: "var(--ios-green)" }} />
                    )}
                    {hasMissed && (
                      <span className="size-[4px] rounded-full" style={{ background: "var(--ios-red)" }} />
                    )}
                    {hasCancelled && (
                      <span className="size-[4px] rounded-full" style={{ background: "var(--ios-orange)" }} />
                    )}
                  </span>
                </motion.button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Selected Day Classes Section */}
      <h2 className="text-title2 mb-3 mt-6 flex items-center justify-between text-foreground">
        <span>
          {selDate.toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" })}
        </span>
        <span className="text-footnote font-normal text-muted-foreground">
          {dayClasses.length} {dayClasses.length === 1 ? "class" : "classes"}
        </span>
      </h2>

      <div className="space-y-2.5">
        {dayClasses.length === 0 ? (
          <div className="glass rounded-[20px] p-5 text-center text-muted-foreground shadow-sm">
            <p className="text-footnote">No classes scheduled or logged for this date.</p>
          </div>
        ) : (
          dayClasses.map((item, idx) => {
            const isCancelled = item.occurrence.state === "cancelled";
            const currentStatus = item.attendanceRecord?.status;

            return (
              <div
                key={`${item.subject.id}-${item.occurrence.startTime}-${idx}`}
                className="glass flex flex-col gap-2 rounded-[22px] px-4 py-3.5 shadow-sm"
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="flex items-center gap-3 flex-1 overflow-hidden">
                    <span
                      className="size-2.5 rounded-full shrink-0"
                      style={{ background: item.subject.tint }}
                    />
                    <div className="flex-1 overflow-hidden">
                      <p className="text-[15px] font-semibold leading-tight truncate text-foreground">
                        {item.subject.name}
                      </p>
                      <p className="text-caption text-muted-foreground mt-0.5">
                        {item.occurrence.startTime}–{item.occurrence.endTime} · {item.occurrence.room || item.subject.room || "Classroom"}{" "}
                        {item.occurrence.isExtra ? "· Extra Class" : ""}
                      </p>
                    </div>
                  </div>

                  {/* Status Indicator */}
                  <span
                    className="text-caption shrink-0 rounded-full px-2.5 py-1 font-semibold capitalize"
                    style={{
                      background: isCancelled
                        ? "color-mix(in oklab, var(--foreground) 12%, transparent)"
                        : currentStatus === "present"
                          ? "color-mix(in oklab, var(--ios-green) 22%, transparent)"
                          : currentStatus === "missed"
                            ? "color-mix(in oklab, var(--ios-red) 22%, transparent)"
                            : "color-mix(in oklab, var(--foreground) 6%, transparent)",
                      color: isCancelled
                        ? "var(--color-muted-foreground)"
                        : currentStatus === "present"
                          ? "var(--ios-green)"
                          : currentStatus === "missed"
                            ? "var(--ios-red)"
                            : "inherit",
                    }}
                  >
                    {isCancelled ? "Cancelled" : currentStatus ?? "Scheduled"}
                  </span>
                </div>

                {/* Actions */}
                {isCancelled ? (
                  <div className="flex items-center justify-between pt-1 border-t border-border/15">
                    <span className="text-[12px] text-muted-foreground">Class marked as cancelled</span>
                    <button
                      onClick={async () => {
                        haptic(10);
                        await uncancelOccurrence(item.occurrence.id);
                      }}
                      className="text-caption font-semibold text-primary flex items-center gap-1"
                    >
                      <RotateCcw className="size-3" />
                      Restore
                    </button>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 pt-1 border-t border-border/15">
                    <button
                      onClick={async () => {
                        haptic(10);
                        await markOccurrenceAttendance(item, "present");
                      }}
                      className={`flex-1 py-1.5 rounded-full text-caption font-semibold flex items-center justify-center gap-1 transition-all ${
                        currentStatus === "present"
                          ? "bg-primary text-primary-foreground shadow-sm"
                          : "glass text-foreground shadow-none"
                      }`}
                    >
                      <Check className="size-3" strokeWidth={2.6} />
                      Present
                    </button>

                    <button
                      onClick={async () => {
                        haptic(10);
                        await markOccurrenceAttendance(item, "missed");
                      }}
                      className={`flex-1 py-1.5 rounded-full text-caption font-semibold flex items-center justify-center gap-1 transition-all ${
                        currentStatus === "missed"
                          ? "bg-destructive text-destructive-foreground shadow-sm"
                          : "glass text-foreground shadow-none"
                      }`}
                    >
                      <X className="size-3" strokeWidth={2.6} />
                      Missed
                    </button>

                    <button
                      onClick={async () => {
                        haptic(10);
                        await cancelOccurrence(item, "Holiday / Cancelled");
                      }}
                      className="glass px-2.5 py-1.5 rounded-full text-caption font-medium text-muted-foreground hover:text-foreground shadow-none"
                      title="Mark as holiday or cancelled"
                    >
                      <Ban className="size-3" />
                    </button>

                    <button
                      onClick={() => {
                        haptic();
                        setInspectSubject(item.subject);
                      }}
                      className="glass px-3 py-1.5 rounded-full text-caption font-medium text-muted-foreground shadow-none"
                    >
                      Details
                    </button>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* Detail Window if inspected */}
      <AnimatePresence>
        {inspectSubject && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-3 pb-24">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.25 }}
              className="absolute inset-0 bg-background/70 backdrop-blur-md"
              onClick={() => setInspectSubject(null)}
            />
            <div className="relative w-full max-w-md z-10">
              <SubjectWindow
                subject={inspectSubject}
                onClose={() => setInspectSubject(null)}
              />
            </div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
