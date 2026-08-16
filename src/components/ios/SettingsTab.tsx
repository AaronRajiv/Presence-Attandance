import { useRef, useState } from "react";
import { motion, AnimatePresence, useReducedMotion } from "motion/react";
import { Switch } from "@/components/ui/switch";
import {
  Moon,
  Sun,
  Download,
  Upload,
  RotateCcw,
  Cloud,
  Bell,
  Plus,
  Edit2,
  Calendar,
} from "lucide-react";
import {
  haptic,
  useAttendance,
  Subject,
} from "@/lib/attendance";
import { DAY_SHORT } from "@/lib/timetableEngine";
import { SubjectFormSheet } from "./SubjectFormSheet";
import { notificationService } from "@/lib/notificationService";

const ACCENTS = [
  "var(--ios-blue)",
  "var(--ios-indigo)",
  "var(--ios-teal)",
  "var(--ios-green)",
  "var(--ios-orange)",
  "var(--ios-pink)",
  "var(--ios-purple)",
];

const REMINDER_OPTIONS = [5, 10, 15, 30];

export function SettingsTab() {
  const {
    prefs,
    setPrefs,
    subjects,
    schedules,
    semester,
    setSemester,
    addSubject,
    updateSubject,
    deleteSubject,
    importData,
    exportData,
    reset,
  } = useAttendance();

  const fileRef = useRef<HTMLInputElement>(null);
  const [editingSubject, setEditingSubject] = useState<Subject | null>(null);
  const [addSubjectOpen, setAddSubjectOpen] = useState(false);
  const [semesterEditOpen, setSemesterEditOpen] = useState(false);
  const shouldReduceMotion = useReducedMotion();

  const [semName, setSemName] = useState(semester.name);
  const [semStart, setSemStart] = useState(semester.startDate);
  const [semEnd, setSemEnd] = useState(semester.endDate);

  const handleExport = async () => {
    haptic();
    const data = await exportData();
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `presence-attendance-backup-${new Date().toISOString().split("T")[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleNotificationToggle = async (enabled: boolean) => {
    haptic();
    if (enabled) {
      const granted = await notificationService.requestPermission();
      await setPrefs({ notifications: granted });
    } else {
      await setPrefs({ notifications: false });
    }
  };

  return (
    <div className="px-5 pb-40 pt-3">
      {/* Header */}
      <header className="mb-5 pt-1">
        <p className="text-footnote font-semibold uppercase tracking-[0.14em] text-primary/90">
          Preferences & Data
        </p>
        <h1 className="text-[28px] font-bold tracking-tight text-foreground leading-none mt-1">
          Settings
        </h1>
      </header>

      {/* Appearance */}
      <Group title="Appearance">
        <Row
          icon={prefs.appearance === "dark" ? <Moon className="size-4" /> : <Sun className="size-4" />}
          label="Theme"
        >
          <div className="glass flex rounded-full p-1 shadow-none">
            {(["light", "dark"] as const).map((t) => {
              const pillProps = shouldReduceMotion ? {} : { layoutId: "theme-pill" };
              return (
                <motion.button
                  key={t}
                  whileTap={{ scale: 0.93 }}
                  onClick={() => {
                    haptic();
                    setPrefs({ appearance: t });
                  }}
                  className="relative rounded-full px-3 py-1 text-[13px] font-medium capitalize focus:outline-none"
                >
                  {prefs.appearance === t && (
                    <motion.span
                      {...pillProps}
                      className="absolute inset-0 rounded-full bg-foreground/12"
                      transition={{ type: "spring", stiffness: 380, damping: 32 }}
                    />
                  )}
                  <span className="relative z-10 text-foreground">{t}</span>
                </motion.button>
              );
            })}
          </div>
        </Row>
        <Divider />
        <div className="relative z-10 px-4 py-3.5">
          <p className="text-[16px] font-medium text-foreground">Accent Color</p>
          <div className="mt-3 flex gap-3">
            {ACCENTS.map((c) => (
              <motion.button
                key={c}
                whileTap={{ scale: 0.85 }}
                onClick={() => {
                  haptic();
                  setPrefs({ accent: c });
                }}
                className="grid size-8 place-items-center rounded-full"
                style={{
                  background: c,
                  boxShadow:
                    prefs.accent === c
                      ? `0 0 0 2px var(--color-background), 0 0 0 4px ${c}`
                      : "var(--shadow-glass)",
                }}
              />
            ))}
          </div>
        </div>
      </Group>

      {/* Sync & Alerts */}
      <Group title="Sync & Reminders">
        <Row icon={<Cloud className="size-4 text-muted-foreground" />} label="iCloud Sync">
          <span className="text-caption font-semibold rounded-full bg-foreground/10 px-2.5 py-1 text-muted-foreground">
            Phase 2 · SwiftData
          </span>
        </Row>
        <Divider />
        <Row icon={<Bell className="size-4 text-primary" />} label="Web Notifications">
          <Switch
            checked={prefs.notifications}
            onCheckedChange={handleNotificationToggle}
          />
        </Row>
        {prefs.notifications && (
          <>
            <Divider />
            <div className="relative z-10 px-4 py-3.5 flex items-center justify-between">
              <span className="text-[15px] font-medium text-foreground">Reminder Time</span>
              <div className="glass flex rounded-full p-1 shadow-none">
                {REMINDER_OPTIONS.map((m) => (
                  <button
                    key={m}
                    onClick={() => {
                      haptic();
                      setPrefs({ reminderMinutes: m });
                    }}
                    className={`px-2.5 py-1 rounded-full text-caption font-semibold transition-all ${
                      prefs.reminderMinutes === m
                        ? "bg-primary text-primary-foreground shadow-sm"
                        : "text-muted-foreground"
                    }`}
                  >
                    {m}m
                  </button>
                ))}
              </div>
            </div>
          </>
        )}
      </Group>

      {/* Academic Semester Information */}
      <Group title="Academic Term & Boundaries">
        <div className="relative z-10 px-4 py-3.5 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Calendar className="size-4 text-muted-foreground" />
              <div>
                <p className="text-[15px] font-semibold text-foreground">{semester.name}</p>
                <p className="text-caption text-muted-foreground">
                  {semester.startDate} to {semester.endDate}
                </p>
              </div>
            </div>
            <button
              onClick={() => setSemesterEditOpen(!semesterEditOpen)}
              className="glass rounded-full px-3 py-1 text-footnote font-semibold text-primary shadow-sm"
            >
              {semesterEditOpen ? "Done" : "Edit"}
            </button>
          </div>

          {semesterEditOpen && (
            <div className="pt-2 space-y-3 border-t border-border/20">
              <div>
                <label className="text-caption font-semibold uppercase text-muted-foreground">Term Name</label>
                <input
                  type="text"
                  value={semName}
                  onChange={(e) => setSemName(e.target.value)}
                  className="glass mt-1 w-full rounded-[14px] px-3 py-2 text-[14px] outline-none shadow-sm"
                />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-caption font-semibold uppercase text-muted-foreground">Start Date</label>
                  <input
                    type="date"
                    value={semStart}
                    onChange={(e) => setSemStart(e.target.value)}
                    className="glass mt-1 w-full rounded-[14px] px-3 py-2 text-[14px] outline-none shadow-sm"
                  />
                </div>
                <div>
                  <label className="text-caption font-semibold uppercase text-muted-foreground">End Date</label>
                  <input
                    type="date"
                    value={semEnd}
                    onChange={(e) => setSemEnd(e.target.value)}
                    className="glass mt-1 w-full rounded-[14px] px-3 py-2 text-[14px] outline-none shadow-sm"
                  />
                </div>
              </div>
              <button
                onClick={async () => {
                  haptic(10);
                  await setSemester({
                    ...semester,
                    name: semName,
                    startDate: semStart,
                    endDate: semEnd,
                  });
                  setSemesterEditOpen(false);
                }}
                className="w-full py-2.5 rounded-[16px] bg-primary text-primary-foreground font-semibold text-footnote shadow-sm"
              >
                Save Term Dates
              </button>
            </div>
          )}
        </div>
      </Group>

      {/* Timetable & Subject Management */}
      <Group title="Subjects & Timetable">
        <div className="relative z-10 flex items-center justify-between px-4 py-3 border-b border-border/20">
          <span className="text-footnote font-semibold text-muted-foreground">
            {subjects.length} {subjects.length === 1 ? "Subject" : "Subjects"} Configured
          </span>
          <button
            onClick={() => {
              haptic(10);
              setAddSubjectOpen(true);
            }}
            className="glass flex items-center gap-1 rounded-full px-3 py-1.5 text-footnote font-semibold text-primary shadow-sm"
          >
            <Plus className="size-3.5" strokeWidth={2.6} />
            <span>Add Subject</span>
          </button>
        </div>

        {subjects.map((s, i) => {
          const subSchedules = schedules.filter((sch) => sch.subjectId === s.id && sch.active);

          return (
            <div key={s.id}>
              {i > 0 && <Divider />}
              <button
                onClick={() => {
                  haptic(8);
                  setEditingSubject(s);
                }}
                className="relative z-10 flex w-full items-center gap-3 px-4 py-3 text-left transition-colors active:bg-foreground/5"
              >
                <span className="size-2.5 rounded-full shrink-0" style={{ background: s.tint }} />
                <div className="flex-1 overflow-hidden">
                  <div className="flex items-center gap-2">
                    <p className="text-[15px] font-semibold leading-tight text-foreground">{s.short}</p>
                    {s.courseCode && (
                      <span className="text-[11px] rounded-full bg-foreground/10 px-1.5 py-0.5 text-muted-foreground font-medium">
                        {s.courseCode}
                      </span>
                    )}
                  </div>
                  <p className="text-caption text-muted-foreground mt-0.5">
                    {subSchedules.length > 0
                      ? subSchedules
                          .map((sch) => `${DAY_SHORT[sch.weekday]} ${sch.startTime}`)
                          .join(" · ")
                      : "No timetable slots"}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-footnote text-muted-foreground truncate max-w-[80px]">
                    {s.room || subSchedules[0]?.room || "—"}
                  </span>
                  <Edit2 className="size-3.5 text-muted-foreground" />
                </div>
              </button>
            </div>
          );
        })}
      </Group>

      {/* Data Backup & Reset */}
      <Group title="Data & Privacy (IndexedDB)">
        <ActionRow icon={<Download className="size-4" />} label="Export Full Backup (JSON)" onPress={handleExport} />
        <Divider />
        <ActionRow
          icon={<Upload className="size-4" />}
          label="Import Backup (JSON)"
          onPress={() => fileRef.current?.click()}
        />
        <Divider />
        <ActionRow
          icon={<RotateCcw className="size-4" />}
          label="Reset All Attendance Records"
          destructive
          onPress={async () => {
            if (confirm("Are you sure you want to reset all logged attendance records? Subjects and schedules will remain.")) {
              haptic(25);
              await reset();
            }
          }}
        />
      </Group>

      {/* Hidden File Input for JSON restore */}
      <input
        ref={fileRef}
        type="file"
        accept="application/json"
        className="hidden"
        onChange={async (e) => {
          const f = e.target.files?.[0];
          if (!f) return;
          try {
            const text = await f.text();
            const parsed = JSON.parse(text);
            if (parsed.subjects && Array.isArray(parsed.subjects)) {
              await importData(parsed);
              alert("Data restored successfully!");
            } else {
              alert("Invalid backup file format.");
            }
          } catch (err) {
            alert("Failed to parse backup file.");
          }
        }}
      />

      {/* Add Subject Sheet */}
      <AnimatePresence>
        {addSubjectOpen && (
          <SubjectFormSheet
            onClose={() => setAddSubjectOpen(false)}
            onSave={async (newSub, newSchedules) => {
              await addSubject(newSub as Omit<Subject, "id" | "createdAt" | "updatedAt">, newSchedules);
            }}
          />
        )}
      </AnimatePresence>

      {/* Edit Subject Sheet */}
      <AnimatePresence>
        {editingSubject && (
          <SubjectFormSheet
            subject={editingSubject}
            schedules={schedules.filter((sch) => sch.subjectId === editingSubject.id)}
            onClose={() => setEditingSubject(null)}
            onSave={async (updatedSub, updatedSchedules) => {
              await updateSubject(updatedSub as Subject, updatedSchedules);
            }}
            onDelete={async (id) => {
              await deleteSubject(id);
            }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-6">
      <p className="text-caption mb-2 pl-4 font-semibold uppercase tracking-[0.1em] text-muted-foreground">
        {title}
      </p>
      <div className="glass overflow-hidden rounded-[24px] shadow-sm">{children}</div>
    </section>
  );
}

function Divider() {
  return <div className="relative z-10 ml-12 h-px bg-separator" />;
}

function Row({
  icon,
  label,
  children,
}: {
  icon: React.ReactNode;
  label: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="relative z-10 flex items-center gap-3 px-4 py-3.5">
      <span className="text-muted-foreground">{icon}</span>
      <span className="flex-1 text-[16px] text-foreground font-normal">{label}</span>
      {children}
    </div>
  );
}

function ActionRow({
  icon,
  label,
  onPress,
  destructive,
}: {
  icon: React.ReactNode;
  label: string;
  onPress: () => void;
  destructive?: boolean;
}) {
  return (
    <motion.button
      whileTap={{ scale: 0.985, opacity: 0.7 }}
      onClick={onPress}
      className="relative z-10 flex w-full items-center gap-3 px-4 py-3.5 text-left"
      style={{ color: destructive ? "var(--ios-red)" : "var(--color-foreground)" }}
    >
      <span className={destructive ? "" : "text-muted-foreground"}>{icon}</span>
      <span className="text-[16px] font-normal">{label}</span>
    </motion.button>
  );
}
