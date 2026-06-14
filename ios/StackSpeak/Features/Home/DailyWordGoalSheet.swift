import SwiftUI

/// Pro-only editor for how many vocab words land each day. Free numeric entry
/// with a minimum of `minGoal` and no upper cap — the daily set naturally tops
/// out at however many words currently qualify. Applies immediately on Done.
struct DailyWordGoalSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    let current: Int
    let onApply: (Int) -> Void

    @State private var text: String
    @FocusState private var fieldFocused: Bool

    private static let minGoal = 3

    init(current: Int, onApply: @escaping (Int) -> Void) {
        self.current = current
        self.onApply = onApply
        _text = State(initialValue: "\(max(Self.minGoal, current))")
    }

    /// Parsed value when valid (an integer ≥ minGoal), else nil.
    private var parsedGoal: Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)),
              value >= Self.minGoal else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacing.lg) {
                Text("home.wordGoal.description")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                stepperRow

                if parsedGoal == nil {
                    Text(String(format: String(localized: "home.wordGoal.min.format"), Self.minGoal))
                        .font(TypographyTokens.caption)
                        .foregroundColor(theme.colors.warn)
                }

                Spacer()
            }
            .padding(theme.spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.bg.ignoresSafeArea())
            .navigationTitle("home.wordGoal.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        if let goal = parsedGoal { onApply(goal) }
                        dismiss()
                    }
                    .disabled(parsedGoal == nil)
                }
            }
            .task { fieldFocused = true }
        }
    }

    private var stepperRow: some View {
        HStack(spacing: theme.spacing.md) {
            adjustButton(systemImage: "minus", delta: -1)
                .disabled((parsedGoal ?? Self.minGoal) <= Self.minGoal)

            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(TypographyTokens.title1)
                .foregroundColor(theme.colors.ink)
                .focused($fieldFocused)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.sm)
                .background(theme.colors.surfaceAlt)
                .clipShape(.rect(cornerRadius: RadiusTokens.inline))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.inline)
                        .strokeBorder(
                            fieldFocused ? theme.colors.accent : theme.colors.lineStrong,
                            lineWidth: fieldFocused ? BorderTokens.focus : BorderTokens.regular
                        )
                )
                .animation(MotionTokens.standard, value: fieldFocused)
                .accessibilityLabel(String(localized: "home.wordGoal.title"))

            adjustButton(systemImage: "plus", delta: 1)
        }
    }

    private func adjustButton(systemImage: String, delta: Int) -> some View {
        Button {
            text = "\(max(Self.minGoal, (parsedGoal ?? current) + delta))"
        } label: {
            Image(systemName: systemImage)
                .font(.system(.title3, weight: .semibold))
                .foregroundColor(theme.colors.accent)
                .frame(width: 44, height: 44)
                .background(theme.colors.surfaceAlt)
                .clipShape(.rect(cornerRadius: RadiusTokens.inline))
        }
        .accessibilityLabel(String(localized: delta > 0
            ? "home.wordGoal.stepper.increment"
            : "home.wordGoal.stepper.decrement"))
    }
}

#Preview("Daily Word Goal — Light") {
    DailyWordGoalSheet(current: 5, onApply: { _ in })
        .withTheme(ThemeManager())
}

#Preview("Daily Word Goal — Dark") {
    DailyWordGoalSheet(current: 8, onApply: { _ in })
        .withTheme(ThemeManager())
        .preferredColorScheme(.dark)
}
