import { useMemo, useState } from "react";
import { motion } from "motion/react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { SUBJECTS, haptic, iso, useAttendance } from "@/lib/attendance";

const WD = ["S", "M", "T", "W", "T", "F", "S"];

export function CalendarTab() {
  const { records } = useAttendance();
  const [month, setMonth] = useState(() => new Date());
  const [selected, setSelected] = useState(() => iso(new Date()));

  const cells = useMemo(() => {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    return [
      ...Array.from({ length: first.getDay() }, () => null),
      ...Array.from(
        { length: days },
        (_, i) => new Date(month.getFullYear(), month.getMonth(), i + 1),
      ),
    ];
  }, [month]);

  const selDate = new Date(selected + "T00:00:00");
  const dayClasses = SUBJECTS.filter((s) => s.days.includes(selDate.getDay())).sort((a, b) =>
    a.time.localeCompare(b.time),
  );

  return (
    <div className="px-5 pb-40 pt-4">
      <header className="mb-5">
        <p className="text-footnote font-medium uppercase tracking-[0.16em] text-muted-foreground">
          {month.toLocaleString("en-US", { year: "numeric" })}
        </p>
        <h1 className="text-largetitle mt-1">{month.toLocaleString("en-US", { month: "long" })}</h1>
      </header>

      <div className="glass glass-sheen rounded-[30px] px-4 py-5">
        <div className="relative z-10">
          <div className="mb-4 flex items-center justify-end gap-1">
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
          <div className="mb-2 grid grid-cols-7 text-center">
            {WD.map((d, i) => (
              <span key={i} className="text-caption font-semibold text-muted-foreground">
                {d}
              </span>
            ))}
          </div>
          <div className="grid grid-cols-7 gap-y-2">
            {cells.map((d, i) => {
              if (!d) return <span key={i} />;
              const key = iso(d);
              const dots = SUBJECTS.map((s) => (records[s.id] ?? {})[key]).filter(Boolean);
              const isToday = key === iso(new Date());
              const isSel = key === selected;
              return (
                <motion.button
                  key={key}
                  whileTap={{ scale: 0.86 }}
                  onClick={() => {
                    haptic();
                    setSelected(key);
                  }}
                  className="relative mx-auto grid size-10 place-items-center rounded-full"
                >
                  {(isToday || isSel) && (
                    <motion.span
                      layoutId="month-sel"
                      className="absolute inset-0 rounded-full"
                      style={{
                        background: isSel
                          ? "var(--accent-live)"
                          : "color-mix(in oklab, var(--foreground) 10%, transparent)",
                      }}
                      transition={{ type: "spring", stiffness: 420, damping: 34 }}
                    />
                  )}
                  <span
                    className={`relative z-10 text-[15px] tabular-nums ${
                      isSel ? "font-semibold text-primary-foreground" : "text-foreground"
                    }`}
                  >
                    {d.getDate()}
                  </span>
                  <span className="absolute bottom-0.5 z-10 flex gap-[2px]">
                    {dots.slice(0, 3).map((s, j) => (
                      <span
                        key={j}
                        className="size-[4px] rounded-full"
                        style={{
                          background:
                            s === "present"
                              ? "var(--ios-green)"
                              : s === "missed"
                                ? "var(--ios-red)"
                                : "var(--ios-blue)",
                        }}
                      />
                    ))}
                  </span>
                </motion.button>
              );
            })}
          </div>
        </div>
      </div>

      <h2 className="text-title2 mb-3 mt-7">
        {selDate.toLocaleDateString("en-US", { weekday: "long", month: "short", day: "numeric" })}
      </h2>
      <div className="space-y-2.5">
        {dayClasses.length === 0 && (
          <p className="text-footnote text-muted-foreground">No scheduled classes.</p>
        )}
        {dayClasses.map((s) => {
          const st = (records[s.id] ?? {})[selected];
          return (
            <div key={s.id} className="glass glass-sheen flex items-center gap-4 rounded-[24px] px-4 py-3.5">
              <span className="relative z-10 text-[15px] font-semibold tabular-nums text-muted-foreground">
                {s.time}
              </span>
              <div className="relative z-10 flex-1">
                <p className="text-[15px] font-medium leading-tight">{s.short}</p>
                <p className="text-caption text-muted-foreground">{s.room}</p>
              </div>
              <span
                className="text-caption relative z-10 rounded-full px-2.5 py-1 font-medium capitalize"
                style={{
                  background: st
                    ? `color-mix(in oklab, ${st === "missed" ? "var(--ios-red)" : st === "extra" ? "var(--ios-blue)" : "var(--ios-green)"} 25%, transparent)`
                    : "color-mix(in oklab, var(--foreground) 8%, transparent)",
                }}
              >
                {st ?? "—"}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
