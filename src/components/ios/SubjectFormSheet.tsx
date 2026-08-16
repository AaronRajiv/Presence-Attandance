import { useState } from "react";
import { motion, useReducedMotion } from "motion/react";
import { X, Plus, Trash2, Sparkles } from "lucide-react";
import { Subject, ClassSchedule, haptic } from "@/lib/attendance";

const TINTS = [
  { name: "Blue", value: "var(--ios-blue)" },
  { name: "Indigo", value: "var(--ios-indigo)" },
  { name: "Teal", value: "var(--ios-teal)" },
  { name: "Green", value: "var(--ios-green)" },
  { name: "Orange", value: "var(--ios-orange)" },
  { name: "Pink", value: "var(--ios-pink)" },
  { name: "Purple", value: "var(--ios-purple)" },
];

const WEEKDAYS = [
  { label: "M", full: "Mon", day: 1 },
  { label: "T", full: "Tue", day: 2 },
  { label: "W", full: "Wed", day: 3 },
  { label: "T", full: "Thu", day: 4 },
  { label: "F", full: "Fri", day: 5 },
  { label: "S", full: "Sat", day: 6 },
  { label: "S", full: "Sun", day: 0 },
];

interface ScheduleInput {
  id?: string | undefined;
  weekday: number;
  startTime: string;
  endTime: string;
  room: string;
}

interface SubjectFormSheetProps {
  subject?: Subject | undefined;
  schedules?: ClassSchedule[] | undefined;
  onClose: () => void;
  onSave: (
    subject: Omit<Subject, "id" | "createdAt" | "updatedAt"> | Subject,
    schedules: ScheduleInput[]
  ) => void;
  onDelete?: ((subjectId: string) => void) | undefined;
}

export function SubjectFormSheet({
  subject,
  schedules = [],
  onClose,
  onSave,
  onDelete,
}: SubjectFormSheetProps) {
  const isEditing = Boolean(subject);
  const shouldReduceMotion = useReducedMotion();

  const [name, setName] = useState(subject?.name || "");
  const [short, setShort] = useState(subject?.short || "");
  const [courseCode, setCourseCode] = useState(subject?.courseCode || "");
  const [lecturer, setLecturer] = useState(subject?.lecturer || "");
  const [room, setRoom] = useState(subject?.room || "");
  const [tint, setTint] = useState(subject?.tint || "var(--ios-blue)");

  const [slots, setSlots] = useState<ScheduleInput[]>(() => {
    if (schedules.length > 0) {
      return schedules.map((s) => ({
        id: s.id,
        weekday: s.weekday,
        startTime: s.startTime,
        endTime: s.endTime,
        room: s.room,
      }));
    }
    return [
      { weekday: 1, startTime: "09:00", endTime: "10:00", room: subject?.room || "" },
      { weekday: 3, startTime: "09:00", endTime: "10:00", room: subject?.room || "" },
    ];
  });

  const addSlot = () => {
    haptic(10);
    setSlots((prev) => [
      ...prev,
      { weekday: 1, startTime: "10:00", endTime: "11:00", room: room || "" },
    ]);
  };

  const removeSlot = (index: number) => {
    haptic(12);
    setSlots((prev) => prev.filter((_, i) => i !== index));
  };

  const updateSlot = (index: number, updates: Partial<ScheduleInput>) => {
    setSlots((prev) =>
      prev.map((s, i) => (i === index ? { ...s, ...updates } : s))
    );
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    haptic(15);
    const shortName = short.trim() || name.trim().split(" ").slice(0, 2).join(" ");
    const trimmedCourse = courseCode.trim() || undefined;
    const trimmedRoom = room.trim() || undefined;

    if (isEditing && subject) {
      const updatedSub: Subject = {
        id: subject.id,
        name: name.trim(),
        short: shortName,
        courseCode: trimmedCourse,
        lecturer: lecturer.trim() || "Lecturer",
        room: trimmedRoom,
        tint,
        createdAt: subject.createdAt,
        updatedAt: subject.updatedAt,
      };
      onSave(updatedSub, slots);
    } else {
      const newSub: Omit<Subject, "id" | "createdAt" | "updatedAt"> = {
        name: name.trim(),
        short: shortName,
        courseCode: trimmedCourse,
        lecturer: lecturer.trim() || "Lecturer",
        room: trimmedRoom,
        tint,
      };
      onSave(newSub, slots);
    }
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center p-0 sm:p-4">
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="absolute inset-0 bg-background/60 backdrop-blur-md"
        onClick={onClose}
      />

      <motion.div
        initial={shouldReduceMotion ? { opacity: 0 } : { y: "100%" }}
        animate={shouldReduceMotion ? { opacity: 1 } : { y: 0 }}
        exit={shouldReduceMotion ? { opacity: 0 } : { y: "100%" }}
        transition={{ type: "spring", stiffness: 350, damping: 32 }}
        className="glass-window relative flex max-h-[88vh] w-full max-w-lg flex-col overflow-hidden rounded-t-[36px] sm:rounded-[36px] shadow-2xl"
      >
        {/* Header */}
        <div className="relative z-10 flex items-center justify-between border-b border-border/30 px-6 py-4">
          <div className="flex items-center gap-2">
            <span className="size-3 rounded-full" style={{ background: tint }} />
            <h2 className="text-title2 font-bold">
              {isEditing ? "Edit Subject" : "Add Subject"}
            </h2>
          </div>
          <button
            onClick={onClose}
            className="glass grid size-8 place-items-center rounded-full text-muted-foreground shadow-sm"
          >
            <X className="size-4" strokeWidth={2.4} />
          </button>
        </div>

        {/* Scrollable Form */}
        <form onSubmit={handleSave} className="relative z-10 flex-1 overflow-y-auto px-6 py-5 space-y-6 pb-28">
          {/* Basic info group */}
          <div className="space-y-4">
            <div>
              <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                Subject Name *
              </label>
              <input
                type="text"
                required
                placeholder="e.g. System Software and Compiler Design"
                value={name}
                onChange={(e) => {
                  setName(e.target.value);
                  if (!short) {
                    setShort(e.target.value.split(" ").slice(0, 2).join(" "));
                  }
                }}
                className="glass mt-1.5 w-full rounded-[16px] px-4 py-3 text-[15px] outline-none placeholder:text-muted-foreground/40 focus:ring-2 focus:ring-primary/40 shadow-sm"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                  Short Title
                </label>
                <input
                  type="text"
                  placeholder="e.g. Compiler Design"
                  value={short}
                  onChange={(e) => setShort(e.target.value)}
                  className="glass mt-1.5 w-full rounded-[16px] px-4 py-3 text-[15px] outline-none placeholder:text-muted-foreground/40 focus:ring-2 focus:ring-primary/40 shadow-sm"
                />
              </div>

              <div>
                <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                  Course Code
                </label>
                <input
                  type="text"
                  placeholder="e.g. 21CS71"
                  value={courseCode}
                  onChange={(e) => setCourseCode(e.target.value)}
                  className="glass mt-1.5 w-full rounded-[16px] px-4 py-3 text-[15px] outline-none placeholder:text-muted-foreground/40 focus:ring-2 focus:ring-primary/40 shadow-sm"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                  Lecturer Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Dr. Aravind Menon"
                  value={lecturer}
                  onChange={(e) => setLecturer(e.target.value)}
                  className="glass mt-1.5 w-full rounded-[16px] px-4 py-3 text-[15px] outline-none placeholder:text-muted-foreground/40 focus:ring-2 focus:ring-primary/40 shadow-sm"
                />
              </div>

              <div>
                <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                  Default Room
                </label>
                <input
                  type="text"
                  placeholder="e.g. Block C · 402"
                  value={room}
                  onChange={(e) => setRoom(e.target.value)}
                  className="glass mt-1.5 w-full rounded-[16px] px-4 py-3 text-[15px] outline-none placeholder:text-muted-foreground/40 focus:ring-2 focus:ring-primary/40 shadow-sm"
                />
              </div>
            </div>
          </div>

          {/* Color Tint Selector */}
          <div>
            <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
              Color Accent
            </label>
            <div className="mt-2 flex gap-3">
              {TINTS.map((t) => (
                <button
                  key={t.name}
                  type="button"
                  onClick={() => {
                    haptic();
                    setTint(t.value);
                  }}
                  className="grid size-8 place-items-center rounded-full transition-transform active:scale-90"
                  style={{
                    background: t.value,
                    boxShadow:
                      tint === t.value
                        ? `0 0 0 2px var(--color-background), 0 0 0 4px ${t.value}`
                        : "var(--shadow-glass)",
                  }}
                />
              ))}
            </div>
          </div>

          {/* Timetable Slots Group */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-caption font-semibold uppercase tracking-wider text-muted-foreground">
                Weekly Class Timetable ({slots.length} {slots.length === 1 ? "slot" : "slots"})
              </label>
              <button
                type="button"
                onClick={addSlot}
                className="text-caption glass flex items-center gap-1 rounded-full px-2.5 py-1 font-semibold text-primary shadow-sm"
              >
                <Plus className="size-3" strokeWidth={2.8} />
                Add Slot
              </button>
            </div>

            <div className="space-y-3">
              {slots.map((slot, index) => (
                <div
                  key={index}
                  className="glass rounded-[20px] p-3.5 space-y-3 relative shadow-sm"
                >
                  <div className="flex items-center justify-between">
                    <span className="text-footnote font-semibold text-muted-foreground">
                      Slot #{index + 1}
                    </span>
                    {slots.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeSlot(index)}
                        className="grid size-6 place-items-center rounded-full text-destructive/70 hover:text-destructive"
                      >
                        <Trash2 className="size-3.5" />
                      </button>
                    )}
                  </div>

                  {/* Day Picker */}
                  <div className="flex gap-1">
                    {WEEKDAYS.map((wd) => {
                      const selected = slot.weekday === wd.day;
                      return (
                        <button
                          key={wd.day}
                          type="button"
                          onClick={() => updateSlot(index, { weekday: wd.day })}
                          className={`flex-1 py-1.5 rounded-full text-caption font-semibold transition-all ${
                            selected
                              ? "bg-primary text-primary-foreground shadow-sm"
                              : "glass text-muted-foreground shadow-none"
                          }`}
                        >
                          {wd.full}
                        </button>
                      );
                    })}
                  </div>

                  {/* Time & Room */}
                  <div className="grid grid-cols-3 gap-2">
                    <div>
                      <span className="text-[10px] text-muted-foreground uppercase font-semibold">Start</span>
                      <input
                        type="time"
                        value={slot.startTime}
                        onChange={(e) => updateSlot(index, { startTime: e.target.value })}
                        className="glass mt-1 w-full rounded-[12px] px-2 py-1.5 text-[13px] outline-none font-medium shadow-sm"
                      />
                    </div>

                    <div>
                      <span className="text-[10px] text-muted-foreground uppercase font-semibold">End</span>
                      <input
                        type="time"
                        value={slot.endTime}
                        onChange={(e) => updateSlot(index, { endTime: e.target.value })}
                        className="glass mt-1 w-full rounded-[12px] px-2 py-1.5 text-[13px] outline-none font-medium shadow-sm"
                      />
                    </div>

                    <div>
                      <span className="text-[10px] text-muted-foreground uppercase font-semibold">Room</span>
                      <input
                        type="text"
                        placeholder="Room"
                        value={slot.room}
                        onChange={(e) => updateSlot(index, { room: e.target.value })}
                        className="glass mt-1 w-full rounded-[12px] px-2 py-1.5 text-[13px] outline-none font-medium shadow-sm"
                      />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Delete Action if editing */}
          {isEditing && onDelete && subject && (
            <div className="pt-2">
              <button
                type="button"
                onClick={() => {
                  if (confirm(`Are you sure you want to delete "${subject.name}" and all its attendance records? This cannot be undone.`)) {
                    haptic(25);
                    onDelete(subject.id);
                    onClose();
                  }
                }}
                className="glass text-footnote flex w-full items-center justify-center gap-2 rounded-[18px] py-3.5 font-semibold text-destructive shadow-sm"
              >
                <Trash2 className="size-4" />
                Delete Subject & Records
              </button>
            </div>
          )}
        </form>

        {/* Footer Save Button */}
        <div
          className="pointer-events-none absolute inset-x-0 bottom-0 z-20 px-6 pb-6 pt-10"
          style={{
            background:
              "linear-gradient(to top, var(--color-background) 65%, color-mix(in oklab, var(--color-background) 80%, transparent) 88%, transparent)",
          }}
        >
          <motion.button
            whileTap={{ scale: 0.97 }}
            onClick={handleSave}
            className="pointer-events-auto flex h-14 w-full items-center justify-center gap-2 rounded-[22px] text-[16px] font-semibold text-primary-foreground shadow-lg"
            style={{ background: tint || "var(--accent-live)", boxShadow: "var(--shadow-float)" }}
          >
            <Sparkles className="size-5" />
            {isEditing ? "Save Changes" : "Create Subject"}
          </motion.button>
        </div>
      </motion.div>
    </div>
  );
}
