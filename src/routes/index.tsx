import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { AnimatePresence, motion } from "motion/react";
import { AttendanceProvider } from "@/lib/attendance";
import { TabBar, type TabKey } from "@/components/ios/TabBar";
import { HomeTab } from "@/components/ios/HomeTab";
import { CalendarTab } from "@/components/ios/CalendarTab";
import { StatsTab } from "@/components/ios/StatsTab";
import { SettingsTab } from "@/components/ios/SettingsTab";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Presence — College Attendance Tracker" },
      {
        name: "description",
        content:
          "Presence is a refined iOS-style college attendance tracker with timetable scheduling and projection analytics.",
      },
      { property: "og:title", content: "Presence — Attendance Tracker" },
      {
        property: "og:description",
        content:
          "Track college attendance, schedule recurring timetable classes, and calculate safety margins.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: App,
});

function App() {
  const [tab, setTab] = useState<TabKey>("home");

  return (
    <AttendanceProvider>
      <main className="relative min-h-screen overflow-hidden bg-background">
        <div className="ambient-mesh pointer-events-none fixed inset-0 -z-10" />
        <div className="pointer-events-none fixed inset-0 -z-10 bg-background/50" />
        <div className="mx-auto max-w-md">
          <AnimatePresence mode="wait">
            <motion.div
              key={tab}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ type: "spring", stiffness: 350, damping: 32 }}
            >
              {tab === "home" && <HomeTab />}
              {tab === "calendar" && <CalendarTab />}
              {tab === "stats" && <StatsTab />}
              {tab === "settings" && <SettingsTab />}
            </motion.div>
          </AnimatePresence>
        </div>
        <TabBar active={tab} onChange={setTab} />
      </main>
    </AttendanceProvider>
  );
}
