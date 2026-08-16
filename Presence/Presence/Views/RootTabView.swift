import SwiftUI
import SwiftData
import UIKit

public enum TabItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case calendar = "Calendar"
    case statistics = "Statistics"
    case settings = "Settings"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .home: return "house.fill"
        case .calendar: return "calendar"
        case .statistics: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Query private var userPreferences: [UserPreferences]

    @State private var selectedTab: TabItem = .home

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(TabItem.home.rawValue, systemImage: TabItem.home.icon)
                }
                .tag(TabItem.home)

            CalendarView()
                .tabItem {
                    Label(TabItem.calendar.rawValue, systemImage: TabItem.calendar.icon)
                }
                .tag(TabItem.calendar)

            StatisticsView()
                .tabItem {
                    Label(TabItem.statistics.rawValue, systemImage: TabItem.statistics.icon)
                }
                .tag(TabItem.statistics)

            SettingsView()
                .tabItem {
                    Label(TabItem.settings.rawValue, systemImage: TabItem.settings.icon)
                }
                .tag(TabItem.settings)
        }
        .tint(appState.activeAccent)
        .preferredColorScheme(appState.colorScheme)
        .onAppear {
            if let savedDark = UserDefaults.standard.object(forKey: "user_dark_mode") as? Bool {
                appState.setDarkMode(savedDark)
                if let pref = userPreferences.first {
                    pref.appearance = savedDark ? "dark" : "light"
                }
            } else if let pref = userPreferences.first {
                if pref.appearance == "light" {
                    appState.setDarkMode(false)
                } else {
                    appState.setDarkMode(true)
                }
            } else {
                appState.setDarkMode(true)
            }
            if let savedTab = UserDefaults.standard.string(forKey: "user_selected_tab"), !savedTab.isEmpty {
                appState.selectedTab = savedTab
            }
            if let pref = userPreferences.first, let acc = pref.accentColor, !acc.isEmpty {
                appState.setAccent(acc)
            }
            applyWindowAppearance(isDark: appState.isDarkMode)
        }
        .onChange(of: appState.isDarkMode) { _, isDark in
            applyWindowAppearance(isDark: isDark)
        }
    }

    private func applyWindowAppearance(isDark: Bool) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
        }
    }
}
