import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { ProgressRing } from "./ProgressRing";
import { SubjectWindow } from "./SubjectWindow";
import { SUBJECTS, haptic, iso, nextClass, useAttendance, type Subject } from "@/lib/attendance";

export function HomeTab() {
  const { stats, records, prefs } = useAttendance();
  const [open, setOpen] = useState<Subject | null>(null);
  const today = new Date();

  const overall = (() => {
    const all = SUBJECTS.map((s) => stats(s.id));
    const p = all.reduce((a, b) => a + b.present, 0);
    const t = all.reduce((a, b) => a + b.total, 0);
    return t ? Math.round((p / t) * 100) : 0;
  })();

  return (
    <div className="px-5 pb-40 pt-4">
      <header className="mb-6">
        <p className="text-footnote font-medium uppercase tracking-[0.16em] text-muted-foreground">
          {today.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
        </p>
        <h1 className="text-largetitle mt-1">Attendance</h1>
      </header>

      <div className="glass glass-sheen mb-6 flex items-center gap-5 rounded-[30px] px-5 py-5">
        <ProgressRing value={overall} size={84} stroke={9} color="var(--accent-live)">
          <span className="text-[23px] font-semibold tabular-nums tracking-tight">{overall}%</span>
        </ProgressRing>
        <div className="relative z-10">
          <p className="text-title2">Overall</p>
          <p className="text-footnote mt-1 max-w-[22ch] text-muted-foreground">
            {overall >= prefs.target
              ? `You're ${overall - prefs.target}% above your ${prefs.target}% target.`
              : `You're ${prefs.target - overall}% below your ${prefs.target}% target.`}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3.5">
        {SUBJECTS.map((s, i) => {
          const st = stats(s.id);
          const todayStatus = (records[s.id] ?? {})[iso(today)];
          const scheduled = s.days.includes(today.getDay());
          return (
            <motion.button
              key={s.id}
              layoutId={`card-${s.id}`}
              onClick={() => {
                haptic(10);
                setOpen(s);
              }}
              whileTap={{ scale: 0.965 }}
              transition={{ type: "spring", stiffness: 320, damping: 30 }}
              className="glass glass-sheen squircle relative aspect-square overflow-hidden p-4 text-left"
              style={{ animationDelay: `${i * 0.45}s` }}
            >
              <div className="relative z-10 flex h-full flex-col">
                <div className="flex items-start justify-between">
                  <span
                    className="size-2.5 rounded-full"
                    style={{ background: s.tint, boxShadow: `0 0 10px ${s.tint}` }}
                  />
                  <ProgressRing value={st.pct} size={40} stroke={4.5} color={s.tint}>
                    <span className="text-[11px] font-semibold tabular-nums">{st.pct}</span>
                  </ProgressRing>
                </div>
                <p className="mt-3 text-[15px] font-semibold leading-tight tracking-tight">
                  {s.short}
                </p>
                <p className="text-caption mt-1 text-muted-foreground">{s.lecturer}</p>
                <div className="mt-auto flex items-end justify-between">
                  <div>
                    <p className="text-caption text-muted-foreground">Next</p>
                    <p className="text-caption font-medium">{nextClass(s).label}</p>
                  </div>
                  <span
                    className="text-caption rounded-full px-2 py-1 font-medium"
                    style={{
                      background: todayStatus
                        ? `color-mix(in oklab, ${todayStatus === "missed" ? "var(--ios-red)" : "var(--ios-green)"} 25%, transparent)`
                        : "color-mix(in oklab, var(--foreground) 8%, transparent)",
                    }}
                  >
                    {todayStatus ?? (scheduled ? "today" : "free")}
                  </span>
                </div>
              </div>
            </motion.button>
          );
        })}
      </div>

      <AnimatePresence>
        {open && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-3 pb-24">
            <motion.div
              initial={{ opacity: 0, backdropFilter: "blur(0px)" }}
              animate={{ opacity: 1, backdropFilter: "blur(22px)" }}
              exit={{ opacity: 0, backdropFilter: "blur(0px)" }}
              transition={{ duration: 0.35 }}
              className="absolute inset-0 bg-background/55"
              onClick={() => setOpen(null)}
            />
            <div className="relative w-full max-w-md">
              <SubjectWindow subject={open} onClose={() => setOpen(null)} />
            </div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
