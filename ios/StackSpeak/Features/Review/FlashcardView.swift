import SwiftUI

struct FlashcardView: View {
    @Environment(\.theme) private var theme

    let word: Word
    let onAgain: () -> Void
    let onGood: () -> Void

    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()

            cardContent
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .padding(theme.spacing.xxxl)
                .background(theme.colors.surface)
                .cornerRadius(16)
                .shadow(color: theme.colors.line, radius: 4, x: 0, y: 2)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            withAnimation {
                                dragOffset = .zero
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isFlipped.toggle()
                    }
                }
                .padding(.horizontal, theme.spacing.xl)

            if isFlipped {
                actionButtons
            } else {
                Text("Tap to flip")
                    .font(TypographyTokens.callout)
                    .foregroundColor(theme.colors.inkFaint)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if !isFlipped {
            frontSide
        } else {
            backSide
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }

    private var frontSide: some View {
        VStack(spacing: theme.spacing.lg) {
            Text(word.word)
                .font(TypographyTokens.title1)
                .foregroundColor(theme.colors.ink)

            Text(word.pronunciation)
                .font(TypographyTokens.mono)
                .foregroundColor(theme.colors.inkMuted)
        }
    }

    private var backSide: some View {
        VStack(alignment: .leading, spacing: theme.spacing.lg) {
            Text(word.shortDefinition)
                .font(TypographyTokens.body)
                .foregroundColor(theme.colors.ink)

            Divider()
                .background(theme.colors.line)

            Text(word.exampleSentence)
                .font(TypographyTokens.callout)
                .foregroundColor(theme.colors.inkMuted)
                .italic()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: theme.spacing.lg) {
            Button(action: {
                onAgain()
                reset()
            }) {
                Text("Again")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.warn)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.warn.opacity(0.1))
                    .cornerRadius(12)
            }

            Button(action: {
                onGood()
                reset()
            }) {
                Text("Got it")
                    .font(TypographyTokens.headline)
                    .foregroundColor(theme.colors.good)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(theme.colors.good.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, theme.spacing.xl)
    }

    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isFlipped = false
        }
    }
}
