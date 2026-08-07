import { motion } from "motion/react";
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
  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-0 z-40 flex justify-center px-5 pb-5">
      <div className="glass-strong glass-sheen pointer-events-auto flex w-full max-w-md items-center gap-1 rounded-full p-1.5">
        {TABS.map(({ key, label, icon: Icon }) => {
          const on = key === active;
          return (
            <motion.button
              key={key}
              whileTap={{ scale: 0.92 }}
              transition={{ type: "spring", stiffness: 500, damping: 30 }}
              onClick={() => {
                haptic();
                onChange(key);
              }}
              className="relative z-10 flex flex-1 flex-col items-center gap-1 rounded-full py-2"
            >
              {on && (
                <motion.span
                  layoutId="tab-pill"
                  className="absolute inset-0 rounded-full"
                  style={{
                    background: "color-mix(in oklab, var(--accent-live) 22%, transparent)",
                    boxShadow: "inset 0 1px 0 var(--glass-sheen)",
                  }}
                  transition={{ type: "spring", stiffness: 420, damping: 34 }}
                />
              )}
              <Icon
                className="relative z-10 size-[19px]"
                strokeWidth={on ? 2.4 : 1.9}
                style={{ color: on ? "var(--accent-live)" : "var(--color-muted-foreground)" }}
              />
              <span
                className="text-caption relative z-10 font-medium"
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
