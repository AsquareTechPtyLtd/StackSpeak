import StoreKit
import SwiftUI

/// The Pro paywall. Shown from the core-stacks "Get Pro" chips, the Profile
/// toolbar, and `BookLockedSheet`. Loads the subscription products via
/// `PurchaseService` and runs the StoreKit 2 purchase/restore flows.
/// Sections live in `ProGateSheet+Sections.swift`.
struct ProGateSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Environment(\.userProgress) var userProgress
    @Environment(\.services) var services

    @State var selectedProductId: String?
    @State var isPurchasing = false
    @State var purchaseError: Error?
    @State var showNothingToRestore = false
    @State var showRedeemSheet = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    headerSection
                    featureList
                    productPicker
                }
                .frame(maxWidth: LayoutTokens.sheetMaxWidth)
                .padding(theme.spacing.xl)
            }

            footerSection
        }
        .background(theme.colors.bg.ignoresSafeArea())
        // Close affordance + detents live here, not at the call sites, so every
        // presentation (onboarding, profile, stack management, locked books)
        // gets a dismissable, full-height sheet — including iPad, where an
        // undetented sheet renders as a clipped floating window.
        .overlay(alignment: .topTrailing) {
            SheetCloseButton { dismiss() }
                .padding(theme.spacing.md)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await loadProducts() }
        .alert(
            "pro.gate.error.title",
            isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            ),
            presenting: purchaseError
        ) { _ in
            Button("common.ok") { purchaseError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
        .alert("pro.gate.restore.none", isPresented: $showNothingToRestore) {
            Button("common.ok") { showNothingToRestore = false }
        }
        // Apple's offer-code redemption sheet. Codes are minted in App Store
        // Connect (Subscriptions → Offer Codes); the redeemed transaction also
        // arrives through PurchaseService's Transaction.updates listener, so
        // the entitlement refresh here is just for an immediate dismiss.
        .offerCodeRedemption(isPresented: $showRedeemSheet) { result in
            handleRedemption(result)
        }
    }

    var products: [Product] {
        services?.purchase.proProducts ?? []
    }

    var selectedProduct: Product? {
        products.first { $0.id == selectedProductId }
    }

    /// True when the selected product starts with a free-trial intro offer.
    var selectedProductHasTrial: Bool {
        selectedProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    // MARK: - Actions

    private func loadProducts() async {
        guard let services else { return }
        await services.purchase.loadProducts()
        // Default to the yearly (most expensive) plan; products are sorted cheapest first.
        if selectedProductId == nil {
            selectedProductId = services.purchase.proProducts.last?.id
        }
    }

    func purchaseSelected() {
        guard let services, let product = selectedProduct, !isPurchasing else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                if try await services.purchase.purchase(product) {
                    dismiss()
                }
            } catch {
                purchaseError = error
            }
        }
    }

    func handleRedemption(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            Task {
                await services?.purchase.refreshEntitlement()
                if userProgress?.isProActive == true {
                    dismiss()
                }
            }
        case .failure(let error):
            // The sheet handles its own invalid-code messaging; only surface
            // real failures, not the user backing out.
            if !isUserCancellation(error) {
                purchaseError = error
            }
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        (error as? StoreKitError).map {
            if case .userCancelled = $0 { return true }
            return false
        } ?? false
    }

    func restorePurchases() {
        guard let services, !isPurchasing else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                if try await services.purchase.restorePurchases() {
                    dismiss()
                } else {
                    showNothingToRestore = true
                }
            } catch {
                purchaseError = error
            }
        }
    }
}

// MARK: - Previews

#Preview("Pro Gate Sheet - Light") {
    ProGateSheet()
        .withTheme(ThemeManager())
        .environment(\.userProgress, UserProgress())
        .modelContainer(for: [UserProgress.self], inMemory: true)
}

#Preview("Pro Gate Sheet - Dark") {
    ProGateSheet()
        .withTheme(ThemeManager())
        .environment(\.userProgress, UserProgress())
        .modelContainer(for: [UserProgress.self], inMemory: true)
        .preferredColorScheme(.dark)
}
