import { useMemo } from "react";
import { motion } from "motion/react";
import { iso, type Status, type Subject } from "@/lib/attendance";

const WD = ["S", "M", "T", "W", "T", "F", "S"];

export function MonthCalendar({
  month,
  subject,
  records,
  onSelect,
  selected,
}: {
  month: Date;
  subject: Subject;
  records: Record<string, Status>;
  onSelect?: (date: Date) => void;
  selected?: string;
}) {
  const cells = useMemo(() => {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    const lead = first.getDay();
    return [
      ...Array.from({ length: lead }, () => null),
      ...Array.from({ length: days }, (_, i) => new Date(month.getFullYear(), month.getMonth(), i + 1)),
    ];
  }, [month]);

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
          const status = records[key];
          const scheduled = subject.days.includes(d.getDay());
          const isToday = key === todayIso;
          const isSel = key === selected;
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
                    background: isToday
                      ? "var(--accent-live)"
                      : "color-mix(in oklab, var(--foreground) 12%, transparent)",
                  }}
                  transition={{ type: "spring", stiffness: 420, damping: 34 }}
                />
              )}
              <span
                className={`relative z-10 text-[15px] tabular-nums ${
                  isToday
                    ? "font-semibold text-primary-foreground"
                    : scheduled
                      ? "font-medium text-foreground"
                      : "text-muted-foreground/60"
                }`}
              >
                {d.getDate()}
              </span>
              {status && (
                <span
                  className="absolute bottom-0 z-10 size-[5px] rounded-full"
                  style={{
                    background:
                      status === "present"
                        ? "var(--ios-green)"
                        : status === "missed"
                          ? "var(--ios-red)"
                          : "var(--ios-blue)",
                    boxShadow: "0 0 6px currentColor",
                  }}
                />
              )}
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}
