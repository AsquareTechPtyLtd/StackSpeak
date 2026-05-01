import SwiftUI

/// Quietly suggests a swipe direction with a slow, ambient chevron nudge.
/// Used at the bottom of onboarding pages and Feynman stages where the
/// primary advance gesture is a horizontal swipe.
///
/// The nudge animation is gated behind `accessibilityReduceMotion` and uses
/// `MotionTokens.nudge` for the cadence. Wrapping the hint in a button gives
/// VoiceOver users (and tap-preferring users) an explicit advance affordance.
struct SwipeNudge: View {
    enum Direction {
        case forward   // chevron points right; nudges right
        case backward  // chevron points left; nudges left
    }

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nudge = false

    let label: LocalizedStringKey
    let direction: Direction
    let onAdvance: () -> Void

    init(_ label: LocalizedStringKey, direction: Direction = .forward, onAdvance: @escaping () -> Void) {
        self.label = label
        self.direction = direction
        self.onAdvance = onAdvance
    }

    var body: some View {
        Button(action: onAdvance) {
            HStack(spacing: 6) {
                if direction == .forward {
                    Text(label)
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                    chevron
                } else {
                    chevron
                    Text(label)
                        .font(TypographyTokens.callout)
                        .foregroundColor(theme.colors.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isButton)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.nudge) { nudge = true }
        }
    }

    private var chevron: some View {
        let glyph = direction == .forward ? "chevron.right" : "chevron.left"
        let dx: CGFloat = direction == .forward ? 4 : -4
        return Image(systemName: glyph)
            .font(TypographyTokens.callout.weight(.semibold))
            .foregroundColor(theme.colors.inkMuted)
            .offset(x: nudge ? dx : 0)
    }
}
