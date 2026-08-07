import { useRef } from "react";
import { motion } from "motion/react";
import { Switch } from "@/components/ui/switch";
import { Moon, Sun, Download, Upload, RotateCcw, Cloud, Bell, CalendarClock } from "lucide-react";
import { SUBJECTS, haptic, useAttendance } from "@/lib/attendance";

const ACCENTS = [
  "var(--ios-blue)",
  "var(--ios-indigo)",
  "var(--ios-teal)",
  "var(--ios-green)",
  "var(--ios-orange)",
  "var(--ios-pink)",
  "var(--ios-purple)",
];

export function SettingsTab() {
  const { prefs, setPrefs, records, importData, reset } = useAttendance();
  const fileRef = useRef<HTMLInputElement>(null);

  const exportData = () => {
    haptic();
    const blob = new Blob([JSON.stringify({ records }, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "attendance.json";
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="px-5 pb-40 pt-4">
      <header className="mb-5">
        <p className="text-footnote font-medium uppercase tracking-[0.16em] text-muted-foreground">
          Preferences
        </p>
        <h1 className="text-largetitle mt-1">Settings</h1>
      </header>

      <Group title="Appearance">
        <Row
          icon={prefs.appearance === "dark" ? <Moon className="size-4" /> : <Sun className="size-4" />}
          label="Theme"
        >
          <div className="glass flex rounded-full p-1">
            {(["light", "dark"] as const).map((t) => (
              <motion.button
                key={t}
                whileTap={{ scale: 0.93 }}
                onClick={() => {
                  haptic();
                  setPrefs({ appearance: t });
                }}
                className="relative rounded-full px-3 py-1 text-[13px] font-medium capitalize"
              >
                {prefs.appearance === t && (
                  <motion.span
                    layoutId="theme-pill"
                    className="absolute inset-0 rounded-full bg-foreground/12"
                    transition={{ type: "spring", stiffness: 420, damping: 34 }}
                  />
                )}
                <span className="relative z-10">{t}</span>
              </motion.button>
            ))}
          </div>
        </Row>
        <Divider />
        <div className="relative z-10 px-4 py-3.5">
          <p className="text-[17px]">Accent Color</p>
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

      <Group title="Sync & Alerts">
        <Row icon={<Cloud className="size-4" />} label="iCloud Sync">
          <Switch
            checked={prefs.icloud}
            onCheckedChange={(v) => {
              haptic();
              setPrefs({ icloud: v });
            }}
          />
        </Row>
        <Divider />
        <Row icon={<Bell className="size-4" />} label="Notifications">
          <Switch
            checked={prefs.notifications}
            onCheckedChange={(v) => {
              haptic();
              setPrefs({ notifications: v });
            }}
          />
        </Row>
      </Group>

      <Group title="Timetable">
        {SUBJECTS.map((s, i) => (
          <div key={s.id}>
            {i > 0 && <Divider />}
            <div className="relative z-10 flex items-center gap-3 px-4 py-3.5">
              <CalendarClock className="size-4 text-muted-foreground" />
              <div className="flex-1">
                <p className="text-[17px] leading-tight">{s.short}</p>
                <p className="text-caption text-muted-foreground">
                  {s.days
                    .map((d) => ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d])
                    .join(" · ")}{" "}
                  at {s.time}
                </p>
              </div>
              <span className="text-footnote text-muted-foreground">{s.room}</span>
            </div>
          </div>
        ))}
      </Group>

      <Group title="Data">
        <ActionRow icon={<Download className="size-4" />} label="Export Data" onPress={exportData} />
        <Divider />
        <ActionRow
          icon={<Upload className="size-4" />}
          label="Import Data"
          onPress={() => fileRef.current?.click()}
        />
        <Divider />
        <ActionRow
          icon={<RotateCcw className="size-4" />}
          label="Reset Attendance"
          destructive
          onPress={() => {
            haptic(20);
            reset();
          }}
        />
      </Group>

      <input
        ref={fileRef}
        type="file"
        accept="application/json"
        className="hidden"
        onChange={async (e) => {
          const f = e.target.files?.[0];
          if (!f) return;
          try {
            const parsed = JSON.parse(await f.text());
            if (parsed.records) importData(parsed.records);
          } catch {
            /* ignore */
          }
        }}
      />
    </div>
  );
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-6">
      <p className="text-caption mb-2 pl-4 font-semibold uppercase tracking-[0.1em] text-muted-foreground">
        {title}
      </p>
      <div className="glass glass-sheen overflow-hidden rounded-[26px]">{children}</div>
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
      <span className="flex-1 text-[17px]">{label}</span>
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
      style={destructive ? { color: "var(--ios-red)" } : undefined}
    >
      <span className={destructive ? "" : "text-muted-foreground"}>{icon}</span>
      <span className="text-[17px]">{label}</span>
    </motion.button>
  );
}
