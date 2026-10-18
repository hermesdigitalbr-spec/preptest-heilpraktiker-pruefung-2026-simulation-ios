import Foundation

/// Retry policy for fetching StoreKit products.
///
/// `Product.products(for:)` succeeds with an EMPTY set when the App Store is
/// momentarily unreachable — it does not throw. A single empty response used
/// to leave the paywall dead until the user tapped Retry by hand, which is
/// what App Review saw in the Guideline 2.1(b) rejection of Sep 7, 2026; again Oct 18, 2026 on four German apps of the 2.0 base.
enum ProductLoadRetry {
    /// Attempts made before giving up, and the pauses between them (seconds).
    static let defaultAttempts = 3
    static func backoff(afterAttempt attempt: Int) -> Int { attempt * 2 }

    /// Runs `load` until it reports success or the attempts run out.
    /// `delay` is injected so tests don't actually sleep.
    @discardableResult
    static func run(attempts: Int = defaultAttempts,
                    delay: (Int) async -> Void,
                    load: () async -> Bool) async -> Bool {
        for attempt in 1...max(attempts, 1) {
            if await load() { return true }
            guard attempt < attempts else { break }
            await delay(backoff(afterAttempt: attempt))
        }
        return false
    }

    /// Production delay: plain seconds of sleep.
    static func sleep(seconds: Int) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
