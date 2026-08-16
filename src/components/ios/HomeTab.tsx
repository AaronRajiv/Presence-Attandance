import { useState, useMemo, useEffect } from "react";
import { motion, AnimatePresence, useReducedMotion } from "motion/react";
import { Plus, Undo2, Clock3, BookPlus, Check, X, CheckCircle2 } from "lucide-react";
import { ProgressRing } from "./ProgressRing";
import { SubjectWindow } from "./SubjectWindow";
import { SubjectFormSheet } from "./SubjectFormSheet";
import {
  haptic,
  iso,
  nextClass,
  useAttendance,
  Subject,
} from "@/lib/attendance";
import { getLiveDayStatus, getClassesForDate } from "@/lib/timetableEngine";

export function HomeTab() {
  const {
    subjects,
    schedules,
    occurrences,
    attendanceRecords,
    semester,
    stats,
    addSubject,
    markOccurrenceAttendance,
    undoLastAction,
    canUndo,
    lastActionText,
  } = useAttendance();

  const [openSubject, setOpenSubject] = useState<Subject | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const shouldReduceMotion = useReducedMotion();

  const today = new Date();
  const todayIso = iso(today);

  // Authoritative live timetable resolution
  const liveStatus = useMemo(
    () => getLiveDayStatus(subjects, schedules, occurrences, attendanceRecords, semester, today),
    [subjects, schedules, occurrences, attendanceRecords, semester, today]
  );

  const todayClasses = useMemo(
    () => getClassesForDate(todayIso, subjects, schedules, occurrences, attendanceRecords, semester, today),
    [todayIso, subjects, schedules, occurrences, attendanceRecords, semester, today]
  );

  // Auto-dismiss undo toast after 6 seconds
  const [showUndoToast, setShowUndoToast] = useState(false);
  useEffect(() => {
    if (canUndo && lastActionText) {
      setShowUndoToast(true);
      const timer = setTimeout(() => setShowUndoToast(false), 6000);
      return () => clearTimeout(timer);
    }
    setShowUndoToast(false);
    return undefined;
  }, [canUndo, lastActionText]);

  return (
    <div className="px-5 pb-40 pt-3">
      {/* 1. Contextual Header: Date & Add Action */}
      <header className="mb-4 flex items-end justify-between pt-1">
        <div>
          <p className="text-footnote font-semibold uppercase tracking-[0.14em] text-primary/90">
            {today.toLocaleDateString("en-US", { weekday: "long" })}
          </p>
          <h1 className="text-[28px] font-bold tracking-tight text-foreground leading-none mt-1">
            {today.toLocaleDateString("en-US", { month: "long", day: "numeric" })}
          </h1>
        </div>

        <motion.button
          whileTap={{ scale: 0.92 }}
          onClick={() => {
            haptic(10);
            setAddOpen(true);
          }}
          className="glass flex items-center gap-1.5 rounded-full px-3.5 py-2 text-footnote font-semibold text-primary shadow-sm"
          title="Add Subject"
        >
          <Plus className="size-4" strokeWidth={2.4} />
          <span>Subject</span>
        </motion.button>
      </header>

      {/* 2. Today's Contextual Chrome Bar (Floating Functional Layer) */}
      {liveStatus.ongoing ? (
        <div className="glass mb-3.5 rounded-[22px] p-3.5 px-4 border border-primary/35 bg-primary/10 shadow-sm">
          <div className="flex items-center justify-between mb-1.5">
            <div className="flex items-center gap-2">
              <span className="relative flex size-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75" />
                <span className="relative inline-flex rounded-full size-2 bg-primary" />
              </span>
              <span className="text-[12px] font-bold uppercase tracking-wider text-primary">
                Now in Session
              </span>
            </div>
            <span className="text-caption text-muted-foreground font-medium">
              {liveStatus.ongoing.occurrence.startTime}–{liveStatus.ongoing.occurrence.endTime}
            </span>
          </div>
          <div className="flex items-center justify-between gap-2">
            <div className="overflow-hidden flex-1">
              <p className="text-[16px] font-semibold text-foreground truncate">
                {liveStatus.ongoing.subject.name}
              </p>
              <p className="text-caption text-muted-foreground mt-0.5">
                {liveStatus.ongoing.occurrence.room || liveStatus.ongoing.subject.room || "Classroom"}
              </p>
            </div>
            <div className="flex items-center gap-1.5 shrink-0">
              <button
                onClick={() => {
                  haptic(10);
                  markOccurrenceAttendance(liveStatus.ongoing!, "present");
                }}
                className={`px-3 py-1.5 rounded-full text-caption font-semibold flex items-center gap-1 transition-all ${
                  liveStatus.ongoing.attendanceRecord?.status === "present"
                    ? "bg-primary text-primary-foreground shadow-sm"
                    : "glass text-foreground hover:bg-foreground/5"
                }`}
              >
                <Check className="size-3" strokeWidth={2.6} />
                Present
              </button>
              <button
                onClick={() => {
                  haptic(10);
                  markOccurrenceAttendance(liveStatus.ongoing!, "missed");
                }}
                className={`px-3 py-1.5 rounded-full text-caption font-semibold flex items-center gap-1 transition-all ${
                  liveStatus.ongoing.attendanceRecord?.status === "missed"
                    ? "bg-destructive text-destructive-foreground shadow-sm"
                    : "glass text-foreground hover:bg-foreground/5"
                }`}
              >
                <X className="size-3" strokeWidth={2.6} />
                Missed
              </button>
            </div>
          </div>
        </div>
      ) : liveStatus.nextClassToday ? (
        <div className="glass mb-3.5 flex items-center justify-between rounded-[20px] px-4 py-2.5 text-footnote shadow-sm">
          <div className="flex items-center gap-2.5 overflow-hidden">
            <Clock3 className="size-4 text-primary shrink-0" />
            <span className="truncate">
              <span className="font-semibold text-foreground">Next:</span> {liveStatus.nextClassToday.subject.short} at {liveStatus.nextClassToday.occurrence.startTime}
            </span>
          </div>
          <span className="text-caption text-muted-foreground shrink-0 ml-2">
            {liveStatus.nextClassToday.occurrence.room || liveStatus.nextClassToday.subject.room || "—"}
          </span>
        </div>
      ) : liveStatus.allConcludedToday ? (
        <div className="glass mb-3.5 flex items-center gap-2 rounded-[20px] px-4 py-2.5 text-footnote text-muted-foreground shadow-sm">
          <CheckCircle2 className="size-4 text-primary shrink-0" />
          <span>All scheduled classes concluded for today</span>
        </div>
      ) : liveStatus.nextOverall ? (
        <div className="glass mb-3.5 flex items-center justify-between rounded-[20px] px-4 py-2.5 text-footnote shadow-sm">
          <div className="flex items-center gap-2.5 overflow-hidden">
            <Clock3 className="size-4 text-muted-foreground shrink-0" />
            <span className="truncate">
              <span className="font-semibold text-foreground">Next:</span> {liveStatus.nextOverall.subject.short} · {liveStatus.nextOverall.label}
            </span>
          </div>
          <span className="text-caption text-muted-foreground shrink-0 ml-2">
            {liveStatus.nextOverall.room}
          </span>
        </div>
      ) : (
        <div className="glass mb-3.5 flex items-center gap-2 rounded-[20px] px-4 py-2.5 text-footnote text-muted-foreground shadow-sm">
          <Clock3 className="size-4 text-muted-foreground shrink-0" />
          <span>No upcoming classes scheduled</span>
        </div>
      )}

      {/* 3. Empty State or Subject Cards Grid */}
      {subjects.length === 0 ? (
        <div className="glass mt-8 flex flex-col items-center justify-center rounded-[32px] p-8 text-center">
          <BookPlus className="size-12 text-muted-foreground/40 mb-3" />
          <h3 className="text-title2 font-bold">No Subjects Added</h3>
          <p className="text-footnote text-muted-foreground mt-1 max-w-[26ch]">
            Add your subjects and weekly timetable slots to start tracking attendance.
          </p>
          <motion.button
            whileTap={{ scale: 0.95 }}
            onClick={() => setAddOpen(true)}
            className="mt-5 flex items-center gap-2 rounded-full px-5 py-2.5 font-semibold text-primary-foreground shadow-md"
            style={{ background: "var(--accent-live)" }}
          >
            <Plus className="size-4" />
            Add First Subject
          </motion.button>
        </div>
      ) : (
        /* Subject Cards Grid with Physical Symmetrical Transitions */
        <div className="grid grid-cols-2 gap-3">
          {subjects.map((s) => {
            const st = stats(s.id);
            const subSchedules = schedules.filter((sch) => sch.subjectId === s.id && sch.active);
            const scheduledToday = subSchedules.some((sch) => sch.weekday === today.getDay());
            const next = nextClass(s, schedules, semester, occurrences);

            const todayItem = todayClasses.find((c) => c.subject.id === s.id);
            const isCancelled = todayItem?.occurrence.state === "cancelled";
            const todayStatus = isCancelled
              ? "Today · Cancelled"
              : todayItem?.attendanceRecord?.status === "present"
                ? "Today · Present"
                : todayItem?.attendanceRecord?.status === "missed"
                  ? "Today · Missed"
                  : todayItem?.isOngoing
                    ? "Now in Session"
                    : todayItem?.isUpcoming
                      ? `Today · ${todayItem.occurrence.startTime}`
                      : todayItem?.isPast
                        ? "Today · Unlogged"
                        : scheduledToday
                          ? "Today"
                          : "No class today";

            const motionProps = shouldReduceMotion
              ? {}
              : { layoutId: `subject-card-${s.id}` };

            return (
              <motion.button
                key={s.id}
                {...motionProps}
                onClick={() => {
                  haptic(10);
                  setOpenSubject(s);
                }}
                whileTap={{ scale: 0.965 }}
                initial={{ borderRadius: 28, opacity: 1 }}
                animate={{ borderRadius: 28, opacity: 1 }}
                transition={{
                  type: "spring",
                  stiffness: 350,
                  damping: 32,
                  mass: 1,
                }}
                style={{
                  borderRadius: 28,
                }}
                className="glass relative min-h-[148px] overflow-hidden p-3.5 text-left shadow-sm focus:outline-none select-none flex flex-col justify-between"
              >
                <div className="relative z-10 flex h-full flex-col justify-between pointer-events-none w-full">
                  {/* Top: Tint indicator & Refined Attendance Ring */}
                  <div className="flex items-start justify-between">
                    <span
                      className="size-2.5 rounded-full mt-1.5 shrink-0"
                      style={{ background: s.tint, boxShadow: `0 0 8px ${s.tint}` }}
                    />
                    <ProgressRing
                      value={st.pct ?? 0}
                      size={40}
                      stroke={3.5}
                      color={s.tint}
                    >
                      <span className="font-bold tabular-nums text-foreground leading-none text-[11px]">
                        {st.pct !== null ? st.pct : "—"}
                      </span>
                    </ProgressRing>
                  </div>

                  {/* Middle: Subject Name is PRIMARY */}
                  <div className="py-1">
                    <p className="text-[15px] font-bold leading-snug tracking-tight text-foreground line-clamp-2">
                      {s.short}
                    </p>
                    <p className="text-caption mt-0.5 text-muted-foreground truncate">{s.lecturer}</p>
                  </div>

                  {/* Bottom: Next & Today contextual status */}
                  <div className="flex items-end justify-between gap-1 pt-1.5 border-t border-border/15">
                    <div className="overflow-hidden flex-1">
                      <p className="text-[10px] font-medium text-muted-foreground">Next</p>
                      <p className="text-caption font-semibold text-foreground truncate">{next.label}</p>
                    </div>
                    <span
                      className="text-[10px] shrink-0 rounded-full px-2 py-0.5 font-semibold"
                      style={{
                        background: isCancelled
                          ? "color-mix(in oklab, var(--foreground) 12%, transparent)"
                          : todayItem?.attendanceRecord?.status === "present"
                            ? "color-mix(in oklab, var(--ios-green) 22%, transparent)"
                            : todayItem?.attendanceRecord?.status === "missed"
                              ? "color-mix(in oklab, var(--ios-red) 22%, transparent)"
                              : scheduledToday
                                ? "color-mix(in oklab, var(--accent-live) 18%, transparent)"
                                : "color-mix(in oklab, var(--foreground) 6%, transparent)",
                        color: isCancelled
                          ? "var(--color-muted-foreground)"
                          : todayItem?.attendanceRecord?.status === "present"
                            ? "var(--ios-green)"
                            : todayItem?.attendanceRecord?.status === "missed"
                              ? "var(--ios-red)"
                              : "inherit",
                      }}
                    >
                      {todayStatus}
                    </span>
                  </div>
                </div>
              </motion.button>
            );
          })}
        </div>
      )}

      {/* 4. Transient Undo Toast (Fixed non-displacing overlay) */}
      <AnimatePresence>
        {showUndoToast && canUndo && lastActionText && (
          <motion.div
            initial={{ opacity: 0, y: 16, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 16, scale: 0.95 }}
            transition={{ type: "spring", stiffness: 380, damping: 30 }}
            className="fixed inset-x-0 bottom-24 z-30 flex justify-center px-4 pointer-events-none"
          >
            <button
              onClick={() => {
                haptic(12);
                undoLastAction();
                setShowUndoToast(false);
              }}
              className="glass-strong pointer-events-auto flex items-center gap-2.5 rounded-full px-4 py-2 text-footnote font-medium text-foreground shadow-lg border border-border/40"
            >
              <Undo2 className="size-3.5 text-primary" />
              <span>{lastActionText}</span>
              <span className="font-semibold text-primary underline ml-0.5">Undo</span>
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* 5. Subject Window Modal Expansion */}
      <AnimatePresence mode="sync">
        {openSubject && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-3 pb-24">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.25, ease: "easeOut" }}
              className="absolute inset-0 bg-background/70 backdrop-blur-md"
              onClick={() => setOpenSubject(null)}
            />
            <div className="relative w-full max-w-md z-10">
              <SubjectWindow
                subject={openSubject}
                onClose={() => setOpenSubject(null)}
              />
            </div>
          </div>
        )}
      </AnimatePresence>

      {/* 6. Add Subject Sheet */}
      <AnimatePresence>
        {addOpen && (
          <SubjectFormSheet
            onClose={() => setAddOpen(false)}
            onSave={async (newSub, newSchedules) => {
              await addSubject(newSub as Omit<Subject, "id" | "createdAt" | "updatedAt">, newSchedules);
            }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
