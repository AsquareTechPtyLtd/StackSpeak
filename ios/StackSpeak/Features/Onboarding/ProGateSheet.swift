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
    @Environment(\.modelContext) var modelContext
    @Environment(\.services) var services

    @State var selectedProductId: String?
    @State var isPurchasing = false
    @State var purchaseError: Error?
    @State var showNothingToRestore = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    headerSection
                    featureList
                    productPicker
                    devProToggle
                }
                .frame(maxWidth: 480)
                .padding(theme.spacing.xl)
            }

            footerSection
        }
        .background(theme.colors.bg.ignoresSafeArea())
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
