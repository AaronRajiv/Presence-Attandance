import SwiftUI

public struct UndoBannerView: View {
    public let message: String
    public let onUndo: () -> Void
    public let onDismiss: () -> Void

    public init(message: String, onUndo: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onUndo = onUndo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.primary)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button("Undo") {
                HapticFeedback.medium()
                onUndo()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .nativeLiquidGlass()
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    onDismiss()
                }
            }
        }
    }
}
