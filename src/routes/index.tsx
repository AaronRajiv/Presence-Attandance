import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { AnimatePresence, motion, LayoutGroup } from "motion/react";
import { AttendanceProvider } from "@/lib/attendance";
import { TabBar, type TabKey } from "@/components/ios/TabBar";
import { HomeTab } from "@/components/ios/HomeTab";
import { CalendarTab } from "@/components/ios/CalendarTab";
import { StatsTab } from "@/components/ios/StatsTab";
import { SettingsTab } from "@/components/ios/SettingsTab";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Presence — Liquid Glass Attendance Tracker" },
      {
        name: "description",
        content:
          "Presence is a minimal iOS-style attendance tracker with Liquid Glass subject cards, calendars, and Health-style statistics.",
      },
      { property: "og:title", content: "Presence — Liquid Glass Attendance Tracker" },
      {
        property: "og:description",
        content:
          "Track class attendance with floating glass subject cards, a native-feeling calendar, and beautiful statistics.",
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
      <main className="relative min-h-screen overflow-hidden">
        <div className="ambient-mesh pointer-events-none fixed inset-0 -z-10" />
        <div className="pointer-events-none fixed inset-0 -z-10 bg-background/40" />
        <div className="mx-auto max-w-md">
          <LayoutGroup>
            <AnimatePresence mode="wait">
              <motion.div
                key={tab}
                initial={{ opacity: 0, y: 12, filter: "blur(8px)" }}
                animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                exit={{ opacity: 0, y: -8, filter: "blur(8px)" }}
                transition={{ type: "spring", stiffness: 280, damping: 32 }}
              >
                {tab === "home" && <HomeTab />}
                {tab === "calendar" && <CalendarTab />}
                {tab === "stats" && <StatsTab />}
                {tab === "settings" && <SettingsTab />}
              </motion.div>
            </AnimatePresence>
          </LayoutGroup>
        </div>
        <TabBar active={tab} onChange={setTab} />
      </main>
    </AttendanceProvider>
  );
}
