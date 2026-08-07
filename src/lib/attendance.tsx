import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type Status = "present" | "missed" | "extra";

export type Subject = {
  id: string;
  name: string;
  short: string;
  lecturer: string;
  room: string;
  /** 0 = Sunday */
  days: number[];
  time: string;
  tint: string;
};

export type Records = Record<string, Record<string, Status>>;

export const SUBJECTS: Subject[] = [
  {
    id: "sscd",
    name: "System Software & Compiler Design",
    short: "Compiler Design",
    lecturer: "Dr. Aravind Menon",
    room: "Block C · 402",
    days: [1, 3, 5],
    time: "09:00",
    tint: "var(--ios-blue)",
  },
  {
    id: "netsec",
    name: "Network Security",
    short: "Network Security",
    lecturer: "Prof. Neha Kulkarni",
    room: "Block A · 118",
    days: [1, 2, 4],
    time: "11:00",
    tint: "var(--ios-indigo)",
  },
  {
    id: "ds",
    name: "Data Science",
    short: "Data Science",
    lecturer: "Dr. Ishaan Verma",
    room: "Lab 3 · 210",
    days: [2, 4],
    time: "14:00",
    tint: "var(--ios-teal)",
  },
  {
    id: "cloud",
    name: "Cloud Computing",
    short: "Cloud Computing",
    lecturer: "Prof. Meera Raghavan",
    room: "Block B · 305",
    days: [3, 5],
    time: "15:30",
    tint: "var(--ios-orange)",
  },
  {
    id: "ml",
    name: "Machine Learning",
    short: "Machine Learning",
    lecturer: "Dr. Kabir Sharma",
    room: "Block C · 511",
    days: [1, 4],
    time: "16:45",
    tint: "var(--ios-pink)",
  },
];

export const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

function seed(): Records {
  const out: Records = {};
  const today = new Date();
  for (const s of SUBJECTS) {
    const bucket: Record<string, Status> = {};
    out[s.id] = bucket;
    for (let i = 1; i <= 56; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() - i);
      if (!s.days.includes(d.getDay())) continue;
      // deterministic pseudo-random so SSR and client agree per date
      const h = (d.getDate() * 31 + d.getMonth() * 17 + s.id.length * 7) % 10;
      bucket[iso(d)] = h < 8 ? "present" : "missed";
    }
  }
  return out;
}

export type Prefs = {
  accent: string;
  appearance: "light" | "dark";
  icloud: boolean;
  notifications: boolean;
  target: number;
};

type Ctx = {
  records: Records;
  prefs: Prefs;
  setStatus: (subjectId: string, date: string, status: Status | null) => void;
  setPrefs: (p: Partial<Prefs>) => void;
  reset: () => void;
  importData: (r: Records) => void;
  stats: (subjectId: string) => { present: number; missed: number; total: number; pct: number };
};

const AttendanceContext = createContext<Ctx | null>(null);
const KEY = "attendance.v1";

export function AttendanceProvider({ children }: { children: ReactNode }) {
  const [records, setRecords] = useState<Records>(() => seed());
  const [prefs, setPrefsState] = useState<Prefs>({
    accent: "var(--ios-blue)",
    appearance: "dark",
    icloud: true,
    notifications: true,
    target: 75,
  });

  useEffect(() => {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed.records) setRecords(parsed.records);
        if (parsed.prefs) setPrefsState((p) => ({ ...p, ...parsed.prefs }));
      }
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify({ records, prefs }));
    } catch {
      /* ignore */
    }
  }, [records, prefs]);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", prefs.appearance === "dark");
    document.documentElement.style.setProperty("--accent-live", prefs.accent);
  }, [prefs.appearance, prefs.accent]);

  const setStatus = useCallback((subjectId: string, date: string, status: Status | null) => {
    setRecords((prev) => {
      const bucket: Record<string, Status> = { ...(prev[subjectId] ?? {}) };
      if (status === null) delete bucket[date];
      else bucket[date] = status;
      return { ...prev, [subjectId]: bucket };
    });
  }, []);

  const setPrefs = useCallback((p: Partial<Prefs>) => setPrefsState((s) => ({ ...s, ...p })), []);

  const stats = useCallback(
    (subjectId: string) => {
      const r = records[subjectId] ?? {};
      const vals = Object.values(r);
      const present = vals.filter((v) => v === "present" || v === "extra").length;
      const missed = vals.filter((v) => v === "missed").length;
      const total = present + missed;
      return { present, missed, total, pct: total ? Math.round((present / total) * 100) : 0 };
    },
    [records],
  );

  const value = useMemo<Ctx>(
    () => ({
      records,
      prefs,
      setStatus,
      setPrefs,
      reset: () => setRecords(Object.fromEntries(SUBJECTS.map((s) => [s.id, {}]))),
      importData: (r) => setRecords(r),
      stats,
    }),
    [records, prefs, setStatus, setPrefs, stats],
  );

  return <AttendanceContext.Provider value={value}>{children}</AttendanceContext.Provider>;
}

export function useAttendance() {
  const ctx = useContext(AttendanceContext);
  if (!ctx) throw new Error("useAttendance must be used inside AttendanceProvider");
  return ctx;
}

export function haptic(ms = 8) {
  if (typeof navigator !== "undefined" && "vibrate" in navigator) navigator.vibrate?.(ms);
}

const DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export function nextClass(s: Subject, from = new Date()) {
  for (let i = 0; i < 8; i++) {
    const d = new Date(from);
    d.setDate(from.getDate() + i);
    if (s.days.includes(d.getDay())) {
      const label = i === 0 ? "Today" : i === 1 ? "Tomorrow" : DAY_NAMES[d.getDay()];
      return { date: d, label: `${label} · ${s.time}` };
    }
  }
  return { date: from, label: "—" };
}
