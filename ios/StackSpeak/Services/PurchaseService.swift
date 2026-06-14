import Foundation
import OSLog
import StoreKit
import SwiftData

private let logger = Logger(category: "PurchaseService")

/// StoreKit 2 implementation of the Pro subscription flow. No backend: purchases
/// are verified on-device via StoreKit's `VerificationResult` and the resulting
/// expiry is persisted onto `UserProgress` through `ProEntitlement`.
@MainActor
@Observable
final class PurchaseService: PurchaseRepository {
    private let modelContext: ModelContext

    /// Pro subscription products, sorted cheapest first (monthly before yearly).
    private(set) var proProducts: [Product] = []
    private(set) var isLoadingProducts = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Listens for transactions that arrive outside the purchase flow —
    /// renewals, Ask to Buy approvals, purchases on another device.
    func startTransactionListener() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = update else { continue }
                await self.applyEntitlement(from: transaction)
                await transaction.finish()
            }
        }
    }

    func loadProducts() async {
        guard proProducts.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            // Subscriptions first (cheapest → priciest), then the one-time
            // lifetime option last, so the paywall reads monthly → yearly → lifetime.
            proProducts = try await Product.products(for: ProEntitlement.productIds)
                .sorted { lhs, rhs in
                    let lLifetime = ProEntitlement.isLifetime(lhs.id)
                    let rLifetime = ProEntitlement.isLifetime(rhs.id)
                    if lLifetime != rLifetime { return !lLifetime }
                    return lhs.price < rhs.price
                }
        } catch {
            logger.error("Product load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Runs the App Store purchase flow for `product`.
    /// - Returns: true when the purchase completed and Pro is now active.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await applyEntitlement(from: transaction)
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Asks the App Store to replay past transactions (Settings reinstall,
    /// new device), then re-reads current entitlements.
    /// - Returns: true when Pro is active after the sync.
    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        await refreshEntitlement()
        return fetchUserProgress()?.isProActive ?? false
    }

    /// Reconciles `UserProgress` with StoreKit's current entitlements.
    /// Called at launch so renewals that happened while the app was closed
    /// extend the stored expiry.
    func refreshEntitlement() async {
        var expirations: [Date] = []
        var hasLifetime = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  ProEntitlement.productIds.contains(transaction.productID) else { continue }
            if ProEntitlement.isLifetime(transaction.productID) {
                hasLifetime = true
            } else if let expiry = transaction.expirationDate {
                expirations.append(expiry)
            }
        }
        guard let progress = fetchUserProgress() else { return }
        if hasLifetime { persistLifetime(to: progress) }
        persist(expiry: ProEntitlement.latestExpiry(from: expirations), to: progress)
    }

    // MARK: - Private helpers

    private func applyEntitlement(from transaction: Transaction) async {
        guard ProEntitlement.productIds.contains(transaction.productID),
              transaction.revocationDate == nil,
              let progress = fetchUserProgress() else { return }
        if ProEntitlement.isLifetime(transaction.productID) {
            persistLifetime(to: progress)
        } else {
            persist(expiry: transaction.expirationDate, to: progress)
        }
    }

    private func persist(expiry: Date?, to progress: UserProgress) {
        guard ProEntitlement.apply(expiry: expiry, to: progress) else { return }
        do {
            try modelContext.save()
            logger.info("Pro entitlement updated, expires \(expiry?.description ?? "never", privacy: .public)")
        } catch {
            logger.error("Failed to persist Pro entitlement: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistLifetime(to progress: UserProgress) {
        guard ProEntitlement.applyLifetime(to: progress) else { return }
        do {
            try modelContext.save()
            logger.info("Pro lifetime entitlement granted")
        } catch {
            logger.error("Failed to persist lifetime entitlement: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchUserProgress() -> UserProgress? {
        try? modelContext.fetch(FetchDescriptor<UserProgress>()).first
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
