import { useMemo, useState } from "react";
import { motion } from "motion/react";
import { Area, AreaChart, Bar, BarChart, Cell, ResponsiveContainer, XAxis, YAxis } from "recharts";
import { ProgressRing } from "./ProgressRing";
import { SUBJECTS, iso, useAttendance } from "@/lib/attendance";

type Range = "W" | "M" | "6M";

export function StatsTab() {
  const { records, stats, prefs } = useAttendance();
  const [range, setRange] = useState<Range>("M");

  const overall = useMemo(() => {
    const all = SUBJECTS.map((s) => stats(s.id));
    const p = all.reduce((a, b) => a + b.present, 0);
    const t = all.reduce((a, b) => a + b.total, 0);
    return { pct: t ? Math.round((p / t) * 100) : 0, present: p, total: t };
  }, [stats]);

  const trend = useMemo(() => {
    const days = range === "W" ? 7 : range === "M" ? 30 : 120;
    const buckets = range === "6M" ? 12 : range === "M" ? 10 : 7;
    const step = Math.ceil(days / buckets);
    const out: { label: string; pct: number }[] = [];
    for (let b = buckets - 1; b >= 0; b--) {
      let p = 0;
      let t = 0;
      for (let i = b * step; i < (b + 1) * step; i++) {
        const d = new Date();
        d.setDate(d.getDate() - i);
        const key = iso(d);
        for (const s of SUBJECTS) {
          const v = (records[s.id] ?? {})[key];
          if (!v) continue;
          t++;
          if (v !== "missed") p++;
        }
      }
      const d = new Date();
      d.setDate(d.getDate() - b * step);
      out.push({
        label: d.toLocaleDateString("en-US", range === "W" ? { weekday: "narrow" } : { day: "numeric" }),
        pct: t ? Math.round((p / t) * 100) : 0,
      });
    }
    return out;
  }, [records, range]);

  const weekly = useMemo(() => {
    const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const agg = names.map((n) => ({ label: n, pct: 0, p: 0, t: 0 }));
    for (const s of SUBJECTS) {
      for (const [date, v] of Object.entries(records[s.id] ?? {})) {
        const wd = new Date(date + "T00:00:00").getDay();
        const row = agg[wd]!;
        row.t++;
        if (v !== "missed") row.p++;
      }
    }
    return agg.map((r) => ({ ...r, pct: r.t ? Math.round((r.p / r.t) * 100) : 0 })).slice(1, 6);
  }, [records]);

  return (
    <div className="px-5 pb-40 pt-4">
      <header className="mb-5">
        <p className="text-footnote font-medium uppercase tracking-[0.16em] text-muted-foreground">
          Summary
        </p>
        <h1 className="text-largetitle mt-1">Statistics</h1>
      </header>

      <div className="glass glass-sheen mb-4 rounded-[30px] px-5 py-6">
        <div className="relative z-10 flex items-center gap-6">
          <ProgressRing value={overall.pct} size={116} stroke={12} color="var(--accent-live)">
            <div className="text-center">
              <p className="text-[30px] font-semibold leading-none tabular-nums tracking-tight">
                {overall.pct}%
              </p>
              <p className="text-caption mt-1 text-muted-foreground">attended</p>
            </div>
          </ProgressRing>
          <div className="space-y-2.5">
            <Stat label="Classes" value={`${overall.total}`} />
            <Stat label="Attended" value={`${overall.present}`} />
            <Stat label="Target" value={`${prefs.target}%`} />
          </div>
        </div>
      </div>

      <div className="glass glass-sheen mb-4 rounded-[30px] px-5 py-5">
        <div className="relative z-10">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="text-title2">Trend</p>
              <p className="text-caption text-muted-foreground">Attendance over time</p>
            </div>
            <div className="glass flex rounded-full p-1">
              {(["W", "M", "6M"] as Range[]).map((r) => (
                <motion.button
                  key={r}
                  whileTap={{ scale: 0.92 }}
                  onClick={() => setRange(r)}
                  className="relative rounded-full px-3 py-1 text-[13px] font-medium"
                >
                  {range === r && (
                    <motion.span
                      layoutId="range-pill"
                      className="absolute inset-0 rounded-full bg-foreground/10"
                      transition={{ type: "spring", stiffness: 420, damping: 34 }}
                    />
                  )}
                  <span className="relative z-10">{r}</span>
                </motion.button>
              ))}
            </div>
          </div>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={trend} margin={{ left: -28, right: 4, top: 6 }}>
                <defs>
                  <linearGradient id="trendFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--accent-live)" stopOpacity={0.5} />
                    <stop offset="100%" stopColor="var(--accent-live)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis
                  dataKey="label"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "var(--color-muted-foreground)" }}
                />
                <YAxis
                  domain={[0, 100]}
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "var(--color-muted-foreground)" }}
                />
                <Area
                  type="monotone"
                  dataKey="pct"
                  stroke="var(--accent-live)"
                  strokeWidth={3}
                  fill="url(#trendFill)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="glass glass-sheen mb-4 rounded-[30px] px-5 py-5">
        <div className="relative z-10">
          <p className="text-title2">Weekly</p>
          <p className="text-caption mb-3 text-muted-foreground">Average by weekday</p>
          <div className="h-36">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={weekly} margin={{ left: -28, right: 4, top: 6 }}>
                <XAxis
                  dataKey="label"
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "var(--color-muted-foreground)" }}
                />
                <YAxis
                  domain={[0, 100]}
                  tickLine={false}
                  axisLine={false}
                  tick={{ fontSize: 11, fill: "var(--color-muted-foreground)" }}
                />
                <Bar dataKey="pct" radius={[10, 10, 10, 10]} barSize={22}>
                  {weekly.map((w, i) => (
                    <Cell
                      key={i}
                      fill={w.pct >= prefs.target ? "var(--ios-green)" : "var(--ios-orange)"}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="glass glass-sheen rounded-[30px] px-5 py-5">
        <div className="relative z-10">
          <p className="text-title2">Subjects</p>
          <p className="text-caption mb-4 text-muted-foreground">Comparison</p>
          <div className="space-y-4">
            {SUBJECTS.map((s) => {
              const st = stats(s.id);
              return (
                <div key={s.id}>
                  <div className="mb-1.5 flex items-baseline justify-between">
                    <span className="text-footnote font-medium">{s.short}</span>
                    <span className="text-footnote tabular-nums text-muted-foreground">
                      {st.pct}%
                    </span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-foreground/10">
                    <motion.div
                      className="h-full rounded-full"
                      initial={{ width: 0 }}
                      animate={{ width: `${st.pct}%` }}
                      transition={{ type: "spring", stiffness: 80, damping: 20 }}
                      style={{ background: s.tint }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-caption text-muted-foreground">{label}</p>
      <p className="text-[19px] font-semibold tabular-nums tracking-tight">{value}</p>
    </div>
  );
}
