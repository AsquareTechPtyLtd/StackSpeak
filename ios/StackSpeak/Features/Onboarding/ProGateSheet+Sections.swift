import StoreKit
import SwiftUI

// Layout sections for the Pro paywall — split out per the
// <TypeName>+<Concern>.swift convention to keep the primary file under the
// size limit. All stored properties live in `ProGateSheet.swift`.
extension ProGateSheet {
    var headerSection: some View {
        VStack(spacing: theme.spacing.lg) {
            ZStack {
                Circle()
                    .fill(theme.colors.accentBg)
                    .frame(width: IconSizeTokens.avatar, height: IconSizeTokens.avatar)
                Image(systemName: "star.fill")
                    .scaledIcon(size: IconSizeTokens.avatar * 0.45, weight: .semibold)
                    .foregroundColor(theme.colors.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: theme.spacing.sm) {
                Text("pro.gate.title")
                    .font(TypographyTokens.title2)
                    .foregroundColor(theme.colors.ink)
                    .multilineTextAlignment(.center)

                Text("pro.gate.message")
                    .font(TypographyTokens.body)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    var featureList: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            featureRow("pro.gate.feature.stacks")
            featureRow("pro.gate.feature.books")
            featureRow("pro.gate.feature.future")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(theme.colors.accent)
                .accessibilityHidden(true)
            Text(key)
                .font(TypographyTokens.subheadline)
                .foregroundColor(theme.colors.ink)
        }
    }

    @ViewBuilder
    var productPicker: some View {
        if products.isEmpty {
            if services?.purchase.isLoadingProducts ?? false {
                ProgressView()
                    .padding(theme.spacing.lg)
            } else {
                Text("pro.gate.unavailable")
                    .font(TypographyTokens.footnote)
                    .foregroundColor(theme.colors.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(theme.spacing.md)
            }
        } else {
            VStack(spacing: theme.spacing.sm) {
                ForEach(products, id: \.id) { product in
                    ProProductCard(
                        title: product.displayName,
                        priceText: product.paywallPriceText,
                        trialText: product.paywallTrialText,
                        isSelected: product.id == selectedProductId,
                        isBestValue: product.id == products.last?.id && products.count > 1,
                        onSelect: { selectedProductId = product.id }
                    )
                }
            }
        }
    }

    @ViewBuilder
    var footerSection: some View {
        VStack(spacing: theme.spacing.sm) {
            ctaButton
                .disabled(selectedProduct == nil)

            HStack(spacing: theme.spacing.lg) {
                Button { restorePurchases() } label: {
                    Text("pro.gate.restore")
                        .font(TypographyTokens.footnote.weight(.medium))
                        .foregroundColor(theme.colors.accent)
                }

                Button { showRedeemSheet = true } label: {
                    Text("pro.gate.redeem")
                        .font(TypographyTokens.footnote.weight(.medium))
                        .foregroundColor(theme.colors.accent)
                }
            }
            .disabled(isPurchasing)

            Text("pro.gate.legal")
                .font(TypographyTokens.caption)
                .foregroundColor(theme.colors.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, theme.spacing.xl)
        .padding(.vertical, theme.spacing.md)
        .background(theme.colors.bg)
    }

    /// CTA copy names the trial length from the product's actual intro offer
    /// ("Start 7-day free trial") so it can never drift from App Store Connect.
    @ViewBuilder
    private var ctaButton: some View {
        if let days = selectedProduct?.paywallTrialDays {
            PrimaryCTAButton(
                verbatim: String(format: String(localized: "pro.gate.cta.trial.days.format"), days),
                isLoading: isPurchasing
            ) {
                purchaseSelected()
            }
        } else {
            PrimaryCTAButton(
                selectedProductHasTrial ? "pro.gate.cta.trial" : "pro.gate.cta.subscribe",
                isLoading: isPurchasing
            ) {
                purchaseSelected()
            }
        }
    }

    /// Dev affordance shared with `BookLockedSheet`: lets a tester unlock all
    /// Pro features without an IAP. Strings are shared (`books.dev.proToggle*`)
    /// because the copy applies equally to either gate.
    var devProToggle: some View {
        HStack(spacing: theme.spacing.sm) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text("books.dev.proToggle")
                    .font(TypographyTokens.footnote.weight(.medium))
                    .foregroundColor(theme.colors.inkMuted)
                Text("books.dev.proToggle.subtitle")
                    .font(TypographyTokens.caption)
                    .foregroundColor(theme.colors.inkFaint)
            }
            Spacer()
            #if DEBUG
            Toggle("", isOn: Binding(
                get: { userProgress?.isProActive ?? false },
                set: { on in
                    guard let progress = userProgress else { return }
                    // Capture pre-toggle state so a failed save restores BOTH
                    // fields — nil-ing the expiry on revert would strand a
                    // restored isPro=true with no expiry date.
                    let oldIsPro = progress.isPro
                    let oldExpiry = progress.proExpiryDate
                    progress.isPro = on
                    progress.proExpiryDate = on
                        ? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                        : nil
                    do {
                        try modelContext.save()
                        if on { dismiss() }
                    } catch {
                        progress.isPro = oldIsPro
                        progress.proExpiryDate = oldExpiry
                    }
                }
            ))
            .labelsHidden()
            #endif
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surfaceAlt)
        .clipShape(.rect(cornerRadius: RadiusTokens.inline))
    }
}
