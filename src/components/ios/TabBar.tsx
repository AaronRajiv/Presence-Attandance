import { motion, useReducedMotion } from "motion/react";
import { House, CalendarDays, ChartNoAxesColumn, Settings2 } from "lucide-react";
import { haptic } from "@/lib/attendance";

export type TabKey = "home" | "calendar" | "stats" | "settings";

const TABS: { key: TabKey; label: string; icon: typeof House }[] = [
  { key: "home", label: "Home", icon: House },
  { key: "calendar", label: "Calendar", icon: CalendarDays },
  { key: "stats", label: "Statistics", icon: ChartNoAxesColumn },
  { key: "settings", label: "Settings", icon: Settings2 },
];

export function TabBar({ active, onChange }: { active: TabKey; onChange: (k: TabKey) => void }) {
  const shouldReduceMotion = useReducedMotion();

  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-0 z-40 flex justify-center px-5 pb-5">
      <div className="glass-strong pointer-events-auto flex w-full max-w-md items-center gap-1 rounded-full p-1.5 shadow-xl border border-border/40">
        {TABS.map(({ key, label, icon: Icon }) => {
          const on = key === active;
          const pillProps = shouldReduceMotion ? {} : { layoutId: "tab-pill" };

          return (
            <motion.button
              key={key}
              whileTap={{ scale: 0.92 }}
              onClick={() => {
                haptic();
                onChange(key);
              }}
              className="relative z-10 flex flex-1 flex-col items-center gap-1 rounded-full py-2 focus:outline-none select-none"
            >
              {on && (
                <motion.span
                  {...pillProps}
                  className="absolute inset-0 rounded-full"
                  style={{
                    background: "color-mix(in oklab, var(--accent-live) 18%, transparent)",
                  }}
                  transition={{ type: "spring", stiffness: 380, damping: 32 }}
                />
              )}
              <Icon
                className="relative z-10 size-[19px]"
                strokeWidth={on ? 2.3 : 1.8}
                style={{ color: on ? "var(--accent-live)" : "var(--color-muted-foreground)" }}
              />
              <span
                className="text-caption relative z-10 font-semibold"
                style={{ color: on ? "var(--accent-live)" : "var(--color-muted-foreground)" }}
              >
                {label}
              </span>
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}
