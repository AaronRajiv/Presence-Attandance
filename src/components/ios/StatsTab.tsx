import { useMemo, useState } from "react";
import { motion, useReducedMotion } from "motion/react";
import { Area, AreaChart, Bar, BarChart, Cell, ResponsiveContainer, XAxis, YAxis } from "recharts";
import { ShieldCheck, AlertCircle, TrendingUp, Target, BarChart2 } from "lucide-react";
import { ProgressRing } from "./ProgressRing";
import { useAttendance, haptic } from "@/lib/attendance";
import {
  calculateAttendanceTrend,
  calculateWeeklyDistribution,
} from "@/lib/statsEngine";

type Range = "W" | "M" | "6M";
const TARGET_PRESETS = [75, 80, 85, 90];

export function StatsTab() {
  const { subjects, occurrences, attendanceRecords, stats, overallStats, prefs, setPrefs } = useAttendance();
  const [range, setRange] = useState<Range>("M");
  const shouldReduceMotion = useReducedMotion();

  const overall = overallStats();
  const hasAttendanceData = overall.totalConducted > 0;

  const trend = useMemo(() => {
    return calculateAttendanceTrend(occurrences, attendanceRecords, range, new Date());
  }, [occurrences, attendanceRecords, range]);

  const weekly = useMemo(() => {
    return calculateWeeklyDistribution(occurrences, attendanceRecords).slice(1, 6); // Mon - Fri
  }, [occurrences, attendanceRecords]);

  return (
    <div className="px-5 pb-40 pt-3">
      {/* Header */}
      <header className="mb-5 pt-1">
        <p className="text-footnote font-semibold uppercase tracking-[0.14em] text-primary/90">
          Analytics & Margins
        </p>
        <h1 className="text-[28px] font-bold tracking-tight text-foreground leading-none mt-1">
          Statistics
        </h1>
      </header>

      {/* Main Overall Ring & Metrics */}
      <div className="glass mb-4 rounded-[28px] px-5 py-6 shadow-sm">
        <div className="relative z-10 flex items-center gap-6">
          <ProgressRing
            value={overall.pct ?? 0}
            size={112}
            stroke={11}
            color="var(--accent-live)"
          >
            <div className="text-center">
              <p className="text-[28px] font-bold leading-none tabular-nums tracking-tight text-foreground">
                {overall.pct !== null ? `${overall.pct}%` : "—"}
              </p>
              <p className="text-caption mt-1 text-muted-foreground">
                {overall.pct !== null ? "attended" : "no data"}
              </p>
            </div>
          </ProgressRing>
          <div className="space-y-2 flex-1">
            <Stat label="Conducted" value={`${overall.totalConducted}`} />
            <Stat label="Present" value={`${overall.present}`} />
            <Stat label="Missed" value={`${overall.missed}`} />
          </div>
        </div>
      </div>

      {/* Target Goal Selector */}
      <div className="glass mb-4 rounded-[24px] p-4 shadow-sm">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Target className="size-4 text-primary" />
            <span className="text-[15px] font-semibold text-foreground">Attendance Goal</span>
          </div>
          <span className="text-footnote font-bold text-primary">{prefs.target}%</span>
        </div>
        <div className="grid grid-cols-4 gap-2">
          {TARGET_PRESETS.map((t) => {
            const isSelected = prefs.target === t;
            return (
              <motion.button
                key={t}
                whileTap={{ scale: 0.94 }}
                onClick={() => {
                  haptic();
                  setPrefs({ target: t });
                }}
                className={`py-2 rounded-[14px] text-footnote font-bold transition-all ${
                  isSelected
                    ? "bg-primary text-primary-foreground shadow-sm"
                    : "glass text-foreground shadow-none"
                }`}
              >
                {t}%
              </motion.button>
            );
          })}
        </div>
      </div>

      {/* Mathematical Projections & Margins */}
      <div className="mb-4 grid grid-cols-2 gap-3">
        {/* Bunk Buffer Card */}
        <div className="glass rounded-[22px] p-4 flex flex-col justify-between shadow-sm min-h-[120px]">
          <div>
            <div className="flex items-center gap-1.5 text-caption font-semibold uppercase tracking-wider text-muted-foreground">
              <ShieldCheck className="size-4 text-emerald-500" />
              <span>Bunk Buffer</span>
            </div>
            <p className="mt-2 text-[24px] font-bold tracking-tight text-foreground">
              {hasAttendanceData ? `${overall.bunkBuffer} ${overall.bunkBuffer === 1 ? "class" : "classes"}` : "—"}
            </p>
          </div>
          <p className="text-[11px] text-muted-foreground mt-1">
            {hasAttendanceData
              ? overall.bunkBuffer > 0
                ? `You can safely miss ${overall.bunkBuffer} classes and stay above ${prefs.target}%.`
                : `Zero margin. Do not miss upcoming classes.`
              : `No margin calculated yet.`}
          </p>
        </div>

        {/* Catch-Up Needed or Projected Card */}
        <div className="glass rounded-[22px] p-4 flex flex-col justify-between shadow-sm min-h-[120px]">
          <div>
            <div className="flex items-center gap-1.5 text-caption font-semibold uppercase tracking-wider text-muted-foreground">
              {overall.catchUpNeeded > 0 ? (
                <AlertCircle className="size-4 text-amber-500" />
              ) : (
                <TrendingUp className="size-4 text-primary" />
              )}
              <span>{overall.catchUpNeeded > 0 ? "Catch-Up" : "Semester Proj."}</span>
            </div>
            <p className="mt-2 text-[24px] font-bold tracking-tight text-foreground">
              {hasAttendanceData ? (
                overall.catchUpNeeded > 0 ? (
                  <span>+{overall.catchUpNeeded}</span>
                ) : overall.projectedPct !== null ? (
                  <span>{overall.projectedPct}%</span>
                ) : (
                  <span>—</span>
                )
              ) : (
                <span>—</span>
              )}
            </p>
          </div>
          <p className="text-[11px] text-muted-foreground mt-1">
            {hasAttendanceData
              ? overall.catchUpNeeded > 0
                ? `Attend ${overall.catchUpNeeded} consecutive classes to reach ${prefs.target}%.`
                : `Projected % if you attend all remaining classes.`
              : `No projection yet.`}
          </p>
        </div>
      </div>

      {/* Attendance Trend Chart */}
      <div className="glass mb-4 rounded-[26px] px-5 py-5 shadow-sm">
        <div className="relative z-10">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="text-title2 font-bold text-foreground">Trend</p>
              <p className="text-caption text-muted-foreground">Attendance over time</p>
            </div>
            {hasAttendanceData && (
              <div className="glass flex rounded-full p-1 shadow-none">
                {(["W", "M", "6M"] as Range[]).map((r) => {
                  const pillProps = shouldReduceMotion ? {} : { layoutId: "range-pill" };
                  return (
                    <motion.button
                      key={r}
                      whileTap={{ scale: 0.92 }}
                      onClick={() => {
                        haptic();
                        setRange(r);
                      }}
                      className="relative rounded-full px-3 py-1 text-[13px] font-medium focus:outline-none"
                    >
                      {range === r && (
                        <motion.span
                          {...pillProps}
                          className="absolute inset-0 rounded-full bg-foreground/10"
                          transition={{ type: "spring", stiffness: 380, damping: 32 }}
                        />
                      )}
                      <span className="relative z-10 text-foreground">{r}</span>
                    </motion.button>
                  );
                })}
              </div>
            )}
          </div>
          <div className="h-40 flex items-center justify-center">
            {hasAttendanceData && trend.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={trend} margin={{ left: -28, right: 4, top: 6 }}>
                  <defs>
                    <linearGradient id="trendFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="var(--accent-live)" stopOpacity={0.4} />
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
                    strokeWidth={2.5}
                    fill="url(#trendFill)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="text-center py-6">
                <BarChart2 className="size-8 mx-auto text-muted-foreground/35 mb-2" />
                <p className="text-footnote text-muted-foreground font-medium">No attendance data yet</p>
                <p className="text-caption text-muted-foreground/70 mt-0.5">Log class attendance to view trend analysis</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Weekday Distribution Bar Chart */}
      <div className="glass mb-4 rounded-[26px] px-5 py-5 shadow-sm">
        <div className="relative z-10">
          <p className="text-title2 font-bold text-foreground">Weekly</p>
          <p className="text-caption mb-3 text-muted-foreground">Attendance by weekday (Mon–Fri)</p>
          <div className="h-36 flex items-center justify-center">
            {hasAttendanceData ? (
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
                  <Bar dataKey="pct" radius={[8, 8, 8, 8]} barSize={20}>
                    {weekly.map((w, i) => (
                      <Cell
                        key={i}
                        fill={w.total === 0 ? "var(--color-muted)" : w.pct >= prefs.target ? "var(--ios-green)" : "var(--ios-orange)"}
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="text-center py-5">
                <p className="text-footnote text-muted-foreground font-medium">No attendance data yet</p>
                <p className="text-caption text-muted-foreground/70 mt-0.5">Weekday distribution appears after classes are marked</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Subject Comparison Section */}
      <div className="glass rounded-[26px] px-5 py-5 shadow-sm">
        <div className="relative z-10">
          <p className="text-title2 font-bold text-foreground">Subjects</p>
          <p className="text-caption mb-4 text-muted-foreground">Attendance & Margins Breakdown</p>

          {subjects.length === 0 ? (
            <p className="text-footnote text-muted-foreground text-center py-4">No subjects added yet.</p>
          ) : (
            <div className="space-y-4">
              {subjects.map((s) => {
                const st = stats(s.id);
                return (
                  <div key={s.id} className="space-y-1.5">
                    <div className="flex items-baseline justify-between">
                      <div className="flex items-center gap-1.5">
                        <span className="size-2 rounded-full" style={{ background: s.tint }} />
                        <span className="text-footnote font-semibold text-foreground">{s.short}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-[11px] text-muted-foreground font-medium">
                          {st.totalConducted > 0 ? (
                            st.bunkBuffer > 0 ? (
                              <span className="text-emerald-500 font-semibold">{st.bunkBuffer} safe bunks</span>
                            ) : st.catchUpNeeded > 0 ? (
                              <span className="text-amber-500 font-semibold">+{st.catchUpNeeded} to {prefs.target}%</span>
                            ) : (
                              <span>{st.present}/{st.totalConducted}</span>
                            )
                          ) : (
                            <span>No attendance yet</span>
                          )}
                        </span>
                        <span className="text-footnote font-bold tabular-nums text-foreground">
                          {st.pct !== null ? `${st.pct}%` : "—"}
                        </span>
                      </div>
                    </div>

                    <div className="h-1.5 overflow-hidden rounded-full bg-foreground/10">
                      <motion.div
                        className="h-full rounded-full"
                        initial={{ width: 0 }}
                        animate={{ width: `${st.pct ?? 0}%` }}
                        transition={{ type: "spring", stiffness: 80, damping: 20 }}
                        style={{ background: s.tint }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-caption text-muted-foreground">{label}</p>
      <p className="text-[18px] font-semibold tabular-nums tracking-tight text-foreground">{value}</p>
    </div>
  );
}
