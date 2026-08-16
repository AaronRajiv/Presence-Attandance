import Foundation
import SwiftUI

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

@Observable
public final class AppState {
    public var selectedTab: String = "home"
    public var undoActionText: String? = nil
    public var showUndoToast: Bool = false
    public var accentHex: String = "#0A84FF"
    public var isDarkMode: Bool = true

    public var activeAccentOption: PresenceAccentOption {
        PresenceAccentOption.from(hexOrName: accentHex)
    }

    public var activeAccent: Color {
        activeAccentOption.color(isDark: isDarkMode)
    }

    public var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    // Neutral true black dark mode & clean light mode
    public var background: Color {
        isDarkMode ? Color(hex: "#000000") : Color(hex: "#F2F2F7")
    }

    public var cardBackground: Color {
        isDarkMode ? Color(hex: "#121214") : Color.white
    }

    public var secondaryCardBackground: Color {
        isDarkMode ? Color(hex: "#1C1C1E") : Color(hex: "#E5E5EA")
    }

    public var cardBorder: Color {
        isDarkMode ? Color(hex: "#2C2C2E").opacity(0.8) : Color.black.opacity(0.08)
    }

    public var textPrimary: Color {
        isDarkMode ? Color(hex: "#FFFFFF") : Color(hex: "#1C1C1E")
    }

    public var textSecondary: Color {
        isDarkMode ? Color(hex: "#8E8E93") : Color(hex: "#636366")
    }

    public var textMuted: Color {
        isDarkMode ? Color(hex: "#636366") : Color(hex: "#8E8E93")
    }

    public init() {
        if let savedTab = UserDefaults.standard.string(forKey: "user_selected_tab"), !savedTab.isEmpty {
            self.selectedTab = savedTab
        }
        if let savedAccent = UserDefaults.standard.string(forKey: "user_accent_hex"), !savedAccent.isEmpty {
            self.accentHex = savedAccent
        }
        if let savedDark = UserDefaults.standard.object(forKey: "user_dark_mode") as? Bool {
            self.isDarkMode = savedDark
        }
    }

    public func setAccent(_ hex: String) {
        self.accentHex = hex
        UserDefaults.standard.set(hex, forKey: "user_accent_hex")
    }

    public func setDarkMode(_ dark: Bool) {
        self.isDarkMode = dark
        UserDefaults.standard.set(dark, forKey: "user_dark_mode")
    }

    public func showUndo(text: String) {
        self.undoActionText = text
        self.showUndoToast = true
    }

    public func clearUndo() {
        self.undoActionText = nil
        self.showUndoToast = false
    }
}
