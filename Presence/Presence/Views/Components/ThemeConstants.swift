import SwiftUI

public enum PresenceAccentOption: String, CaseIterable, Identifiable, Sendable {
    case blue = "blue"
    case indigo = "indigo"
    case cyan = "cyan"
    case green = "green"
    case orange = "orange"
    case pink = "pink"
    case purple = "purple"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .orange: return "Orange"
        case .pink: return "Pink"
        case .purple: return "Purple"
        }
    }

    public var hex: String {
        switch self {
        case .blue: return "#0A84FF"
        case .indigo: return "#5E5CE6"
        case .cyan: return "#64D2FF"
        case .green: return "#30D158"
        case .orange: return "#FF9F0A"
        case .pink: return "#FF375F"
        case .purple: return "#BF5AF2"
        }
    }

    public func color(isDark: Bool) -> Color {
        switch self {
        case .blue:
            return isDark ? Color(hex: "#0A84FF") : Color(hex: "#007AFF")
        case .indigo:
            return isDark ? Color(hex: "#5E5CE6") : Color(hex: "#5856D6")
        case .cyan:
            return isDark ? Color(hex: "#64D2FF") : Color(hex: "#00A3C4")
        case .green:
            return isDark ? Color(hex: "#30D158") : Color(hex: "#28CD41")
        case .orange:
            return isDark ? Color(hex: "#FF9F0A") : Color(hex: "#FF9500")
        case .pink:
            return isDark ? Color(hex: "#FF375F") : Color(hex: "#FF2D55")
        case .purple:
            return isDark ? Color(hex: "#BF5AF2") : Color(hex: "#AF52DE")
        }
    }

    public static func from(hexOrName: String) -> PresenceAccentOption {
        let clean = hexOrName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = PresenceAccentOption(rawValue: clean) { return match }
        switch clean {
        case "#0a84ff", "#007aff", "blue": return .blue
        case "#5e5ce6", "#5856d6", "indigo": return .indigo
        case "#64d2ff", "#00a3c4", "#30b0c7", "#32ade6", "cyan", "teal": return .cyan
        case "#30d158", "#34c759", "#28cd41", "green": return .green
        case "#ff9f0a", "#ff9500", "orange": return .orange
        case "#ff375f", "#ff2d55", "pink": return .pink
        case "#bf5af2", "#af52de", "purple": return .purple
        default: return .blue
        }
    }
}

public enum PresenceTheme {
    // Fixed Semantic Attendance Accents (Independent of user's global theme accent choice)
    public static func greenAccent(isDark: Bool = true) -> Color {
        isDark ? Color(hex: "#30D158") : Color(hex: "#28CD41")
    }
    public static func redAccent(isDark: Bool = true) -> Color {
        isDark ? Color(hex: "#FF453A") : Color(hex: "#FF3B30")
    }
    public static func orangeAccent(isDark: Bool = true) -> Color {
        isDark ? Color(hex: "#FF9F0A") : Color(hex: "#FF9500")
    }
    public static func purpleAccent(isDark: Bool = true) -> Color {
        isDark ? Color(hex: "#BF5AF2") : Color(hex: "#AF52DE")
    }
    public static func tealAccent(isDark: Bool = true) -> Color {
        isDark ? Color(hex: "#64D2FF") : Color(hex: "#00A3C4")
    }

    // Static shorthand accessors
    public static let greenAccent = Color(hex: "#30D158")
    public static let redAccent = Color(hex: "#FF453A")
    public static let orangeAccent = Color(hex: "#FF9F0A")
    public static let purpleAccent = Color(hex: "#BF5AF2")
    public static let tealAccent = Color(hex: "#64D2FF")
    public static let blueAccent = Color(hex: "#0A84FF")
    public static let pinkAccent = Color(hex: "#FF375F")
    public static let indigoAccent = Color(hex: "#5E5CE6")

    // Default static fallback references
    public static let background = Color(hex: "#000000")
    public static let cardBackground = Color(hex: "#121214")
    public static let secondaryCardBackground = Color(hex: "#1C1C1E")
    public static let cardBorder = Color(hex: "#2C2C2E").opacity(0.8)
    public static let textPrimary = Color.white
    public static let textSecondary = Color(hex: "#8E8E93")
    public static let textMuted = Color(hex: "#636366")
}

public struct DarkPresenceCardModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    public var cornerRadius: CGFloat = 24
    public var useGlass: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(appState.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(appState.cardBorder, lineWidth: 0.8)
            )
            .shadow(
                color: appState.isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.04),
                radius: appState.isDarkMode ? 8 : 6,
                x: 0,
                y: appState.isDarkMode ? 3 : 2
            )
    }
}

public extension View {
    func presenceCard(cornerRadius: CGFloat = 24, useGlass: Bool = false) -> some View {
        self.modifier(DarkPresenceCardModifier(cornerRadius: cornerRadius, useGlass: useGlass))
    }
}
