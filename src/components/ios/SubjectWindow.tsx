import { useState, useMemo } from "react";
import { motion, AnimatePresence, useReducedMotion } from "motion/react";
import {
  X,
  Plus,
  Check,
  Clock3,
  MapPin,
  ChevronLeft,
  ChevronRight,
  Edit3,
  Calendar,
  Ban,
  RotateCcw,
} from "lucide-react";
import { ProgressRing } from "./ProgressRing";
import { MonthCalendar } from "./MonthCalendar";
import { SubjectFormSheet } from "./SubjectFormSheet";
import {
  haptic,
  iso,
  nextClass,
  useAttendance,
  Subject,
  AttendanceStatus,
  DayClassItem,
} from "@/lib/attendance";
import { DAY_SHORT, getClassesForDate, parseISODate } from "@/lib/timetableEngine";

export function SubjectWindow({ subject, onClose }: { subject: Subject; onClose: () => void }) {
  const {
    schedules,
    occurrences,
    attendanceRecords,
    semester,
    markOccurrenceAttendance,
    cancelOccurrence,
    uncancelOccurrence,
    unmarkOccurrence,
    addExtraClass,
    stats,
    updateSubject,
    deleteSubject,
  } = useAttendance();

  const [month, setMonth] = useState(() => new Date());
  const [selected, setSelected] = useState(() => iso(new Date()));
  const [extraOpen, setExtraOpen] = useState(false);
  const [extraDefaultStatus, setExtraDefaultStatus] = useState<AttendanceStatus>("present");
  const [editOpen, setEditOpen] = useState(false);
  const [pulse, setPulse] = useState<string | null>(null);
  const shouldReduceMotion = useReducedMotion();

  const subSchedules = useMemo(
    () => schedules.filter((s) => s.subjectId === subject.id && s.active),
    [schedules, subject.id]
  );

  const subStats = stats(subject.id);
  const next = nextClass(subject, schedules, semester, occurrences);
  const todayIso = iso(new Date());

  // Classes on selected date for this subject
  const selectedDayItems = useMemo(() => {
    const all = getClassesForDate(
      selected,
      [subject],
      schedules,
      occurrences,
      attendanceRecords,
      semester,
      new Date()
    );
    return all.filter((c) => c.subject.id === subject.id);
  }, [selected, subject, schedules, occurrences, attendanceRecords, semester]);

  const activeItem: DayClassItem | undefined = selectedDayItems[0];
  const isCancelled = activeItem?.occurrence.state === "cancelled";
  const currentStatus = activeItem?.attendanceRecord?.status;

  const mark = async (status: "present" | "missed") => {
    haptic(12);
    setPulse(status);
    setTimeout(() => setPulse(null), 550);

    if (activeItem) {
      await markOccurrenceAttendance(activeItem, status);
    } else {
      // Prompt extra class sheet with prefilled status and date
      setExtraDefaultStatus(status);
      setExtraOpen(true);
    }
  };

  const dayOfWeekToday = new Date().getDay();
  const scheduledToday = subSchedules.some((s) => s.weekday === dayOfWeekToday);
  const todayItem = getClassesForDate(
    todayIso,
    [subject],
    schedules,
    occurrences,
    attendanceRecords,
    semester,
    new Date()
  )[0];

  const motionProps = shouldReduceMotion
    ? {
        initial: { opacity: 0, scale: 0.95 },
        animate: { opacity: 1, scale: 1 },
        exit: { opacity: 0, scale: 0.95 },
      }
    : {
        layoutId: `subject-card-${subject.id}`,
      };

  return (
    <>
      <motion.div
        {...motionProps}
        className="glass-window relative flex max-h-[84vh] w-full flex-col overflow-hidden shadow-2xl focus:outline-none"
        style={{ borderRadius: 36 }}
        transition={{
          type: "spring",
          stiffness: 350,
          damping: 32,
          mass: 1,
        }}
      >
        <div className="relative z-10 flex flex-col overflow-y-auto px-6 pb-48 pt-6">
          {/* Header Bar */}
          <div className="mb-5 flex items-start justify-between gap-4">
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <p
                  className="text-caption font-semibold uppercase tracking-[0.14em]"
                  style={{ color: subject.tint }}
                >
                  {subject.short}
                </p>
                {subject.courseCode && (
                  <span className="text-caption rounded-full bg-foreground/10 px-2 py-0.5 font-medium text-muted-foreground">
                    {subject.courseCode}
                  </span>
                )}
              </div>
              <h2 className="text-largetitle mt-1 max-w-[18ch]">{subject.name}</h2>
              <p className="text-footnote mt-1 text-muted-foreground">{subject.lecturer}</p>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              <motion.button
                whileTap={{ scale: 0.88 }}
                onClick={() => {
                  haptic();
                  setEditOpen(true);
                }}
                className="glass grid size-9 place-items-center rounded-full text-muted-foreground shadow-sm"
                title="Edit Subject"
              >
                <Edit3 className="size-4" />
              </motion.button>

              <motion.button
                whileTap={{ scale: 0.88 }}
                onClick={() => {
                  haptic();
                  onClose();
                }}
                className="glass grid size-9 place-items-center rounded-full text-muted-foreground shadow-sm"
              >
                <X className="size-4" strokeWidth={2.4} />
              </motion.button>
            </div>
          </div>

          {/* Stats Ring Card */}
          <div className="glass mb-4 flex items-center gap-5 rounded-[26px] px-5 py-4 shadow-sm">
            <ProgressRing
              value={subStats.pct ?? 0}
              size={76}
              stroke={7.5}
              color={subject.tint}
            >
              <span className="text-[21px] font-semibold tabular-nums tracking-tight">
                {subStats.pct !== null ? `${subStats.pct}%` : "—"}
              </span>
            </ProgressRing>
            <div className="relative z-10 flex-1 space-y-1.5">
              <Row
                label="Attended"
                value={
                  subStats.totalConducted > 0
                    ? `${subStats.present} of ${subStats.totalConducted}`
                    : "0 conducted"
                }
              />
              <Row label="Missed" value={`${subStats.missed}`} />
              {subStats.bunkBuffer > 0 && (
                <Row label="Safe bunks" value={`${subStats.bunkBuffer} classes`} />
              )}
              {subStats.catchUpNeeded > 0 && (
                <Row label="Needed to target" value={`+${subStats.catchUpNeeded}`} />
              )}
              <Row label="Next class" value={next.label} />
            </div>
          </div>

          {/* Timetable schedule info tile */}
          <div className="mb-4 grid grid-cols-2 gap-3">
            <InfoTile
              icon={<Clock3 className="size-4" />}
              title="Today"
              value={
                todayItem?.occurrence.state === "cancelled"
                  ? "Cancelled"
                  : todayItem?.attendanceRecord?.status
                    ? (todayItem.attendanceRecord.status[0]?.toUpperCase() ?? "") + todayItem.attendanceRecord.status.slice(1)
                    : scheduledToday
                      ? `Class · ${subSchedules.find((s) => s.weekday === dayOfWeekToday)?.startTime || ""}`
                      : "No class"
              }
            />
            <InfoTile
              icon={<MapPin className="size-4" />}
              title="Room"
              value={subject.room || subSchedules[0]?.room || "—"}
            />
          </div>

          {/* Weekly recurring schedule badge row */}
          {subSchedules.length > 0 && (
            <div className="glass mb-4 rounded-[22px] p-3.5 shadow-sm">
              <div className="flex items-center gap-2 mb-2">
                <Calendar className="size-3.5 text-muted-foreground" />
                <span className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                  Weekly Schedule
                </span>
              </div>
              <div className="flex flex-wrap gap-2">
                {subSchedules.map((sch, i) => (
                  <div
                    key={sch.id || i}
                    className="glass flex items-center gap-1.5 rounded-full px-3 py-1 text-footnote font-medium shadow-none"
                  >
                    <span className="font-semibold text-primary">{DAY_SHORT[sch.weekday]}</span>
                    <span className="text-muted-foreground">{sch.startTime}–{sch.endTime}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Extra class and Month navigation header */}
          <div className="mb-3 flex items-center justify-between">
            <button
              onClick={() => {
                setExtraDefaultStatus("present");
                setExtraOpen(true);
              }}
              className="glass text-footnote relative flex items-center gap-1.5 rounded-full px-3.5 py-2 font-medium shadow-sm"
            >
              <Plus className="relative z-10 size-3.5" strokeWidth={2.6} />
              <span className="relative z-10">Add Extra Class</span>
            </button>
            <div className="flex items-center gap-1">
              <NavBtn onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}>
                <ChevronLeft className="size-4" />
              </NavBtn>
              <span className="w-28 text-center text-[15px] font-semibold">
                {month.toLocaleString("en-US", { month: "long", year: "numeric" })}
              </span>
              <NavBtn onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}>
                <ChevronRight className="size-4" />
              </NavBtn>
            </div>
          </div>

          {/* Subject Month Calendar */}
          <div className="glass rounded-[26px] px-4 py-4 shadow-sm mb-4">
            <div className="relative z-10">
              <MonthCalendar
                month={month}
                subject={subject}
                selected={selected}
                onSelect={(d) => {
                  haptic();
                  setSelected(iso(d));
                }}
              />
              <div className="text-caption mt-4 flex items-center justify-center gap-4 text-muted-foreground">
                <Legend color="var(--ios-green)" label="Present" />
                <Legend color="var(--ios-red)" label="Missed" />
                <Legend color="var(--ios-orange)" label="Cancelled" />
              </div>
            </div>
          </div>
        </div>

        {/* Bottom Floating Action Bar (Functional Glass Layer) */}
        <div
          className="pointer-events-none absolute inset-x-0 bottom-0 z-20 px-5 pb-5 pt-12"
          style={{
            background:
              "linear-gradient(to top, var(--color-background) 65%, color-mix(in oklab, var(--color-background) 80%, transparent) 88%, transparent)",
          }}
        >
          {isCancelled ? (
            <div className="pointer-events-auto flex items-center justify-between glass rounded-[22px] p-3 px-4 shadow-sm">
              <div>
                <p className="text-[15px] font-semibold text-amber-500">Class Cancelled / Holiday</p>
                <p className="text-caption text-muted-foreground">Excluded from attendance calculations</p>
              </div>
              <button
                onClick={() => {
                  haptic(10);
                  if (activeItem) uncancelOccurrence(activeItem.occurrence.id);
                }}
                className="glass rounded-full px-3 py-1.5 text-caption font-semibold text-primary flex items-center gap-1 shadow-sm"
              >
                <RotateCcw className="size-3" />
                Restore
              </button>
            </div>
          ) : (
            <div className="pointer-events-auto space-y-2">
              <div className="grid grid-cols-2 gap-3">
                <GlassAction
                  label="Present"
                  color="var(--ios-green)"
                  active={currentStatus === "present"}
                  rippling={pulse === "present"}
                  onPress={() => mark("present")}
                />
                <GlassAction
                  label="Missed"
                  color="var(--ios-red)"
                  active={currentStatus === "missed"}
                  rippling={pulse === "missed"}
                  onPress={() => mark("missed")}
                />
              </div>

              {activeItem && (
                <div className="flex items-center justify-center gap-4 pt-0.5">
                  <button
                    onClick={() => {
                      haptic(10);
                      cancelOccurrence(activeItem, "College Holiday / Class Cancelled");
                    }}
                    className="text-[12px] font-medium text-muted-foreground hover:text-foreground flex items-center gap-1"
                  >
                    <Ban className="size-3" />
                    Cancel Class / Holiday
                  </button>
                  {currentStatus && (
                    <button
                      onClick={() => {
                        haptic(10);
                        unmarkOccurrence(activeItem.occurrence.id);
                      }}
                      className="text-[12px] font-medium text-muted-foreground hover:text-foreground"
                    >
                      Clear Record
                    </button>
                  )}
                </div>
              )}
            </div>
          )}

          <p className="text-caption pointer-events-none mt-1.5 text-center text-muted-foreground">
            {currentStatus ? (
              <span className="font-semibold capitalize text-foreground">
                Currently {currentStatus} · Tap again to toggle off
              </span>
            ) : isCancelled ? (
              <span>Class marked as cancelled for this date</span>
            ) : (
              <span>
                Marking{" "}
                {parseISODate(selected).toLocaleDateString("en-US", {
                  weekday: "long",
                  month: "short",
                  day: "numeric",
                })}
              </span>
            )}
          </p>
        </div>

        {/* Extra Class Sheet */}
        <AnimatePresence>
          {extraOpen && (
            <ExtraClassSheet
              subject={subject}
              initialDate={selected}
              initialStatus={extraDefaultStatus}
              onClose={() => setExtraOpen(false)}
              onAdd={async (date, startTime, endTime, status, notes) => {
                haptic(14);
                await addExtraClass(subject.id, date, startTime, endTime, status, notes);
                setExtraOpen(false);
              }}
            />
          )}
        </AnimatePresence>
      </motion.div>

      {/* Edit Subject Sheet */}
      <AnimatePresence>
        {editOpen && (
          <SubjectFormSheet
            subject={subject}
            schedules={subSchedules}
            onClose={() => setEditOpen(false)}
            onSave={async (updatedSub, updatedSchedules) => {
              await updateSubject(updatedSub as Subject, updatedSchedules);
            }}
            onDelete={async (id) => {
              await deleteSubject(id);
              onClose();
            }}
          />
        )}
      </AnimatePresence>
    </>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between">
      <span className="text-footnote text-muted-foreground">{label}</span>
      <span className="text-footnote font-medium tabular-nums text-foreground">{value}</span>
    </div>
  );
}

function InfoTile({ icon, title, value }: { icon: React.ReactNode; title: string; value: string }) {
  return (
    <div className="glass rounded-[20px] px-4 py-3 shadow-sm">
      <div className="relative z-10">
        <div className="text-caption flex items-center gap-1.5 text-muted-foreground">
          {icon}
          {title}
        </div>
        <p className="mt-1 text-[15px] font-semibold leading-tight text-foreground">{value}</p>
      </div>
    </div>
  );
}

function NavBtn({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <motion.button
      whileTap={{ scale: 0.85 }}
      onClick={onClick}
      className="grid size-8 place-items-center rounded-full text-muted-foreground"
    >
      {children}
    </motion.button>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span className="flex items-center gap-1.5 text-[11px]">
      <span className="size-[6px] rounded-full" style={{ background: color }} />
      {label}
    </span>
  );
}

function GlassAction({
  label,
  color,
  active,
  rippling,
  onPress,
}: {
  label: string;
  color: string;
  active: boolean;
  rippling: boolean;
  onPress: () => void;
}) {
  return (
    <motion.button
      whileTap={{ scale: 0.95 }}
      transition={{ type: "spring", stiffness: 450, damping: 30 }}
      onClick={onPress}
      className="glass-strong relative h-14 overflow-hidden rounded-[22px] shadow-sm"
      style={{
        background: active ? `color-mix(in oklab, ${color} 26%, transparent)` : undefined,
        borderColor: active ? `color-mix(in oklab, ${color} 45%, transparent)` : undefined,
      }}
    >
      {rippling && (
        <span
          className="ripple absolute left-1/2 top-1/2 size-20 -translate-x-1/2 -translate-y-1/2 rounded-full"
          style={{ background: color }}
        />
      )}
      <span className="relative z-10 flex items-center justify-center gap-2 text-[16px] font-semibold text-foreground">
        <Check className="size-[17px]" strokeWidth={2.6} style={{ color, opacity: active ? 1 : 0.6 }} />
        {label}
      </span>
    </motion.button>
  );
}

function ExtraClassSheet({
  subject,
  initialDate,
  initialStatus = "present",
  onClose,
  onAdd,
}: {
  subject: Subject;
  initialDate?: string;
  initialStatus?: AttendanceStatus;
  onClose: () => void;
  onAdd: (
    date: string,
    startTime: string,
    endTime: string,
    status: AttendanceStatus,
    notes?: string | undefined
  ) => Promise<void>;
}) {
  const [date, setDate] = useState(() => initialDate || iso(new Date()));
  const [startTime, setStartTime] = useState(() => {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  });
  const [endTime, setEndTime] = useState(() => {
    const now = new Date();
    return `${String(now.getHours() + 1).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
  });
  const [status, setStatus] = useState<AttendanceStatus>(initialStatus);
  const [notes, setNotes] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!date) return;
    await onAdd(date, startTime, endTime, status, notes.trim() || undefined);
  };

  return (
    <motion.div
      className="absolute inset-0 z-30 flex items-end"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      <div className="absolute inset-0 bg-background/50 backdrop-blur-md" onClick={onClose} />
      <motion.form
        onSubmit={handleSubmit}
        initial={{ y: 380 }}
        animate={{ y: 0 }}
        exit={{ y: 380 }}
        transition={{ type: "spring", stiffness: 350, damping: 32 }}
        className="glass-window relative w-full rounded-t-[36px] px-6 pb-8 pt-4 shadow-2xl"
      >
        <div className="mx-auto mb-5 h-1.5 w-10 rounded-full bg-foreground/15" />
        <div className="relative z-10 space-y-4">
          <div>
            <h3 className="text-title2 font-bold">Add Extra Class</h3>
            <p className="text-footnote mt-1 text-muted-foreground">{subject.name}</p>
          </div>

          <div className="grid grid-cols-3 gap-2">
            <div>
              <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                Date
              </label>
              <input
                type="date"
                required
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="glass mt-1 w-full rounded-[14px] px-2.5 py-2 text-[14px] outline-none font-medium"
              />
            </div>
            <div>
              <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                Start Time
              </label>
              <input
                type="time"
                required
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                className="glass mt-1 w-full rounded-[14px] px-2.5 py-2 text-[14px] outline-none font-medium"
              />
            </div>
            <div>
              <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                End Time
              </label>
              <input
                type="time"
                required
                value={endTime}
                onChange={(e) => setEndTime(e.target.value)}
                className="glass mt-1 w-full rounded-[14px] px-2.5 py-2 text-[14px] outline-none font-medium"
              />
            </div>
          </div>

          <div>
            <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
              Attendance Result
            </label>
            <div className="grid grid-cols-2 gap-2 mt-1">
              <button
                type="button"
                onClick={() => setStatus("present")}
                className={`py-2 rounded-[14px] text-footnote font-semibold transition-all ${
                  status === "present"
                    ? "bg-primary text-primary-foreground shadow-sm"
                    : "glass text-foreground"
                }`}
              >
                Attended (Present)
              </button>
              <button
                type="button"
                onClick={() => setStatus("missed")}
                className={`py-2 rounded-[14px] text-footnote font-semibold transition-all ${
                  status === "missed"
                    ? "bg-destructive text-destructive-foreground shadow-sm"
                    : "glass text-foreground"
                }`}
              >
                Missed (Absent)
              </button>
            </div>
          </div>

          <div>
            <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
              Notes (Optional)
            </label>
            <input
              type="text"
              placeholder="e.g. Extra revision lecture or lab session"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              className="glass mt-1 w-full rounded-[16px] px-3.5 py-2 text-[14px] outline-none placeholder:text-muted-foreground/50"
            />
          </div>

          <motion.button
            whileTap={{ scale: 0.96 }}
            type="submit"
            className="mt-2 h-13 w-full rounded-[20px] text-[16px] font-semibold text-primary-foreground shadow-lg"
            style={{ background: "var(--accent-live)", boxShadow: "var(--shadow-float)" }}
          >
            Log Extra Class
          </motion.button>
        </div>
      </motion.form>
    </motion.div>
  );
}
