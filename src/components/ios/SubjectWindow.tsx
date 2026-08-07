import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { X, Plus, Check, Clock3, MapPin, ChevronLeft, ChevronRight } from "lucide-react";
import { ProgressRing } from "./ProgressRing";
import { MonthCalendar } from "./MonthCalendar";
import { haptic, iso, nextClass, useAttendance, type Subject } from "@/lib/attendance";

export function SubjectWindow({ subject, onClose }: { subject: Subject; onClose: () => void }) {
  const { records, setStatus, stats } = useAttendance();
  const [month, setMonth] = useState(() => new Date());
  const [selected, setSelected] = useState(() => iso(new Date()));
  const [extraOpen, setExtraOpen] = useState(false);
  const [pulse, setPulse] = useState<string | null>(null);
  const s = stats(subject.id);
  const rec = records[subject.id] ?? {};
  const next = nextClass(subject);
  const todayStatus = rec[iso(new Date())];

  const mark = (status: "present" | "missed") => {
    haptic(12);
    setPulse(status);
    setTimeout(() => setPulse(null), 620);
    setStatus(subject.id, selected, rec[selected] === status ? null : status);
  };

  return (
    <motion.div
      layoutId={`card-${subject.id}`}
      className="glass-window glass-sheen squircle relative flex max-h-[80vh] w-full flex-col overflow-hidden"
      style={{ borderRadius: 40 }}
      transition={{ type: "spring", stiffness: 260, damping: 30 }}
    >
      <div className="relative z-10 flex flex-col overflow-y-auto px-6 pb-40 pt-6">
        <div className="mb-5 flex items-start justify-between gap-4">
          <motion.div layout="position">
            <p
              className="text-caption font-semibold uppercase tracking-[0.14em]"
              style={{ color: subject.tint }}
            >
              {subject.short}
            </p>
            <h2 className="text-largetitle mt-1 max-w-[16ch]">{subject.name}</h2>
            <p className="text-footnote mt-1.5 text-muted-foreground">{subject.lecturer}</p>
          </motion.div>
          <motion.button
            whileTap={{ scale: 0.88 }}
            onClick={() => {
              haptic();
              onClose();
            }}
            className="glass grid size-9 shrink-0 place-items-center rounded-full"
          >
            <X className="size-4 text-muted-foreground" strokeWidth={2.4} />
          </motion.button>
        </div>

        <div className="glass glass-sheen mb-4 flex items-center gap-5 rounded-[28px] px-5 py-4">
          <ProgressRing value={s.pct} size={78} stroke={8} color={subject.tint}>
            <span className="text-[22px] font-semibold tabular-nums tracking-tight">{s.pct}%</span>
          </ProgressRing>
          <div className="relative z-10 flex-1 space-y-1.5">
            <Row label="Attended" value={`${s.present} of ${s.total}`} />
            <Row label="Missed" value={`${s.missed}`} />
            <Row label="Next class" value={next.label} />
          </div>
        </div>

        <div className="mb-4 grid grid-cols-2 gap-3">
          <InfoTile icon={<Clock3 className="size-4" />} title="Today" value={
            todayStatus ? todayStatus[0]!.toUpperCase() + todayStatus.slice(1) : subject.days.includes(new Date().getDay()) ? `Class · ${subject.time}` : "No class"
          } />
          <InfoTile icon={<MapPin className="size-4" />} title="Room" value={subject.room} />
        </div>

        <div className="mb-3 flex items-center justify-between">
          <button
            onClick={() => setExtraOpen(true)}
            className="glass glass-sheen text-footnote relative flex items-center gap-1.5 rounded-full px-3.5 py-2 font-medium"
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

        <div className="glass glass-sheen rounded-[28px] px-4 py-4">
          <div className="relative z-10">
            <MonthCalendar
              month={month}
              subject={subject}
              records={rec}
              selected={selected}
              onSelect={(d) => {
                haptic();
                setSelected(iso(d));
              }}
            />
            <div className="text-caption mt-4 flex items-center justify-center gap-4 text-muted-foreground">
              <Legend color="var(--ios-green)" label="Present" />
              <Legend color="var(--ios-red)" label="Missed" />
              <Legend color="var(--ios-blue)" label="Extra" />
            </div>
          </div>
        </div>
      </div>

      <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 px-5 pb-6 pt-14"
        style={{
          background:
            "linear-gradient(to top, var(--color-background) 42%, color-mix(in oklab, var(--color-background) 60%, transparent) 72%, transparent)",
        }}>
        <div className="pointer-events-auto grid grid-cols-2 gap-3">
          <GlassAction
            label="Present"
            color="var(--ios-green)"
            active={rec[selected] === "present"}
            rippling={pulse === "present"}
            onPress={() => mark("present")}
          />
          <GlassAction
            label="Missed"
            color="var(--ios-red)"
            active={rec[selected] === "missed"}
            rippling={pulse === "missed"}
            onPress={() => mark("missed")}
          />
        </div>
        <p className="text-caption pointer-events-none mt-2.5 text-center text-muted-foreground">
          Marking{" "}
          {new Date(selected + "T00:00:00").toLocaleDateString("en-US", {
            weekday: "long",
            month: "short",
            day: "numeric",
          })}
        </p>
      </div>

      <AnimatePresence>
        {extraOpen && (
          <ExtraClassSheet
            subject={subject}
            onClose={() => setExtraOpen(false)}
            onAdd={(d) => {
              haptic(14);
              setStatus(subject.id, d, "extra");
              setExtraOpen(false);
            }}
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between">
      <span className="text-footnote text-muted-foreground">{label}</span>
      <span className="text-footnote font-medium tabular-nums">{value}</span>
    </div>
  );
}

function InfoTile({ icon, title, value }: { icon: React.ReactNode; title: string; value: string }) {
  return (
    <div className="glass glass-sheen rounded-[22px] px-4 py-3">
      <div className="relative z-10">
        <div className="text-caption flex items-center gap-1.5 text-muted-foreground">
          {icon}
          {title}
        </div>
        <p className="mt-1 text-[15px] font-medium">{value}</p>
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
    <span className="flex items-center gap-1.5">
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
      whileTap={{ scale: 0.94 }}
      transition={{ type: "spring", stiffness: 500, damping: 28 }}
      onClick={onPress}
      className="glass-strong glass-sheen relative h-16 overflow-hidden rounded-[26px]"
      style={{
        background: active ? `color-mix(in oklab, ${color} 32%, transparent)` : undefined,
        borderColor: active ? `color-mix(in oklab, ${color} 55%, transparent)` : undefined,
      }}
    >
      {rippling && (
        <span
          className="ripple absolute left-1/2 top-1/2 size-24 -translate-x-1/2 -translate-y-1/2 rounded-full"
          style={{ background: color }}
        />
      )}
      <span className="relative z-10 flex items-center justify-center gap-2 text-[17px] font-semibold">
        <Check className="size-[18px]" strokeWidth={2.6} style={{ color, opacity: active ? 1 : 0.6 }} />
        {label}
      </span>
    </motion.button>
  );
}

function ExtraClassSheet({
  subject,
  onClose,
  onAdd,
}: {
  subject: Subject;
  onClose: () => void;
  onAdd: (date: string) => void;
}) {
  const [date, setDate] = useState(() => iso(new Date()));
  return (
    <motion.div
      className="absolute inset-0 z-30 flex items-end"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      <div
        className="absolute inset-0 bg-foreground/10 backdrop-blur-md"
        onClick={onClose}
      />
      <motion.div
        initial={{ y: 320 }}
        animate={{ y: 0 }}
        exit={{ y: 320 }}
        transition={{ type: "spring", stiffness: 320, damping: 34 }}
        className="glass-strong glass-sheen relative w-full rounded-t-[40px] px-6 pb-8 pt-4"
      >
        <div className="mx-auto mb-5 h-1.5 w-10 rounded-full bg-foreground/15" />
        <div className="relative z-10">
          <h3 className="text-title2">Add Extra Class</h3>
          <p className="text-footnote mt-1 text-muted-foreground">{subject.name}</p>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="glass mt-5 w-full rounded-[20px] px-4 py-3.5 text-[17px] outline-none"
          />
          <motion.button
            whileTap={{ scale: 0.96 }}
            onClick={() => onAdd(date)}
            className="mt-3 h-14 w-full rounded-[22px] text-[17px] font-semibold text-primary-foreground"
            style={{ background: "var(--accent-live)", boxShadow: "var(--shadow-float)" }}
          >
            Add Class
          </motion.button>
        </div>
      </motion.div>
    </motion.div>
  );
}
