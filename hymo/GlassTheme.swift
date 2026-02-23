import SwiftUI

// MARK: - Design Constants

enum GlassTheme {
    static let cardCornerRadius: CGFloat = 12
    static let innerCornerRadius: CGFloat = 8
    static let cardPadding: CGFloat = 10
    static let cardSpacing: CGFloat = 10

    static let shadowColor = Color.black.opacity(0.08)
    static let shadowRadius: CGFloat = 8
    static let shadowY: CGFloat = 2

    static let innerStrokeWidth: CGFloat = 0.5
}

// MARK: - GlassCard ViewModifier

struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(GlassTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white.opacity(0.08), .white.opacity(0.02), .white.opacity(0)]
                                : [.white.opacity(0.15), .white.opacity(0.05), .white.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white.opacity(0.15), .white.opacity(0.05)]
                                : [.white.opacity(0.40), .white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: GlassTheme.innerStrokeWidth
                    )
                    .allowsHitTesting(false)
            )
            .shadow(
                color: GlassTheme.shadowColor,
                radius: GlassTheme.shadowRadius,
                y: GlassTheme.shadowY
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}

// MARK: - GlassButtonStyle

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - GlassTextEditor ViewModifier

struct GlassTextEditorModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.03))
            )
    }
}

extension View {
    func glassTextEditor() -> some View {
        modifier(GlassTextEditorModifier())
    }
}
