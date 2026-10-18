import Foundation
import Observation
import StoreKit

/// StoreKit 2 wrapper for the two subscriptions (weekly, monthly).
/// Product IDs come from the ContentPack, so clones swap monetization
/// without touching Swift.
@MainActor
@Observable
final class IAPService {
    private(set) var weeklyProduct: Product?
    private(set) var monthlyProduct: Product?
    private(set) var quarterlyProduct: Product?
    private(set) var entitledPro = false
    private(set) var isPurchasing = false
    private(set) var lastError: String?
    /// Screenshot-only display-price overrides. StoreKit products don't load
    /// under `simctl`, so `ScreenshotMode` injects these to render a complete
    /// paywall (real prices, enabled CTA, no load-error banner). Always nil in
    /// normal use and Release.
    var debugWeeklyPrice: String?
    var debugMonthlyPrice: String?
    var debugQuarterlyPrice: String?
    var debugPerDayMonthly: String?
    var debugPerDayQuarterly: String?
    var debugSavingsPercent: Int?
    /// Real StoreKit intro-offer eligibility (the user hasn't used the trial).
    /// Defaults to `false` until StoreKit confirms eligibility: the paywall
    /// must never advertise "free trial" before we actually know an
    /// introductory offer applies to this user/territory (Apple 1.1.6 —
    /// showing a trial CTA that then charges full price is objectionable
    /// content, not just a disclaimer issue).
    private(set) var realTrialEligible = false

    #if DEBUG
    /// Debug-menu override: simulate each access state without touching
    /// StoreKit. Compiled out of Release — never ships.
    enum DebugEntitlement: String, CaseIterable, Identifiable {
        case live          // no override — use the real StoreKit state
        case premium       // active paid subscriber
        case trial         // active free trial (full access)
        case trialExpired  // trial ended, back to free, not eligible again
        case free          // never subscribed, still eligible for the trial

        var id: String { rawValue }
        var label: String {
            switch self {
            case .live: "Live (real StoreKit)"
            case .premium: "Premium (paid)"
            case .trial: "Free trial (active)"
            case .trialExpired: "Trial expired → free"
            case .free: "Free (trial available)"
            }
        }
    }
    var debugEntitlement: DebugEntitlement = .live
    #endif

    var isPro: Bool {
        #if DEBUG
        switch debugEntitlement {
        case .live: break
        case .premium, .trial: return true
        case .trialExpired, .free: return false
        }
        #endif
        return entitledPro
    }

    /// Whether the introductory free trial is still available to this user.
    /// Drives the paywall CTA: an expired-trial user sees the paid price,
    /// not "Try for $0.00".
    var isEligibleForTrial: Bool {
        #if DEBUG
        switch debugEntitlement {
        case .live: break
        case .free: return true
        case .premium, .trial, .trialExpired: return false
        }
        #endif
        return realTrialEligible
    }

    /// True while a free trial is the active entitlement (for trial-only UI).
    var isTrialActive: Bool {
        #if DEBUG
        if case .trial = debugEntitlement { return true }
        #endif
        return false
    }

    /// True only when StoreKit reports a free-trial introductory offer on this
    /// exact product AND the user can still redeem it. Every "grátis" on the
    /// paywall keys off this: Guideline 3.1.2(c) rejected 1.0.2 for showing a
    /// trial that the purchase sheet did not offer.
    func offersFreeTrial(_ product: Product?) -> Bool {
        guard isEligibleForTrial else { return false }
        guard let product else {
            #if DEBUG
            // Screenshot harness: products don't load under simctl.
            return debugEntitlement == .free
            #else
            return false
            #endif
        }
        return product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private let productIds: ProductIDs
    private var updatesTask: Task<Void, Never>?

    init(products: ProductIDs) {
        productIds = products
        updatesTask = Task { await listenForTransactions() }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    /// Clears the last surfaced error (e.g. when the user dismisses the banner).
    func clearError() { lastError = nil }

    func loadProducts() async {
        lastError = nil
        do {
            var wanted = [productIds.weekly, productIds.monthly]
            if let q = productIds.quarterly { wanted.append(q) }
            let products = try await Product.products(for: wanted)
            weeklyProduct = products.first { $0.id == productIds.weekly }
            monthlyProduct = products.first { $0.id == productIds.monthly }
            if let q = productIds.quarterly {
                quarterlyProduct = products.first { $0.id == q }
            }
            if let subscription = monthlyProduct?.subscription {
                realTrialEligible = await subscription.isEligibleForIntroOffer
            }
            // StoreKit returns success with an empty set when no product IDs
            // match (misconfigured ContentPack, or ASC products not yet
            // available) — it does NOT throw. Surface it so the paywall shows
            // its error+Retry banner instead of a silent dead end.
            if weeklyProduct == nil, monthlyProduct == nil {
                lastError = "No subscription products were returned by the App Store."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    // Trust the verified transaction directly. currentEntitlements
                    // can lag in sandbox right after purchase and would overwrite
                    // entitledPro = false before the paywall dismisses.
                    entitledPro = true
                    await transaction.finish()
                    return true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
        return false
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var owns = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productIds.weekly
                || transaction.productID == productIds.monthly
                || transaction.productID == productIds.quarterly {
                owns = true
            }
        }
        entitledPro = owns
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}
