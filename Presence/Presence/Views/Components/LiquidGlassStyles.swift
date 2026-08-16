import SwiftUI

// MARK: - Haptic Feedback

public enum HapticFeedback {
    @MainActor
    public static func light() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    @MainActor
    public static func medium() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    @MainActor
    public static func success() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    @MainActor
    public static func warning() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }
}

// MARK: - Native Apple Liquid Glass View Modifier

public struct NativeLiquidGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                )
        } else {
            content
                .glassEffect()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

public extension View {
    func nativeLiquidGlass() -> some View {
        self.modifier(NativeLiquidGlassModifier())
    }
}
