import Testing
import Foundation
@testable import HeilpraktikerPrep

/// The 2.1(b) rejection (Sep 7, 2026) said the IAP products "could not be
/// loaded". Configuration in App Store Connect was complete, so the working
/// theory is a transient empty response — which the app surfaced as a dead
/// paywall because it never retried. These pin the retry policy.
struct ProductRetryTests {
    @Test func retriesUntilProductsArrive() async {
        var calls = 0
        let ok = await ProductLoadRetry.run(attempts: 3, delay: { _ in }) {
            calls += 1
            return calls >= 3   // first two come back empty
        }
        #expect(ok)
        #expect(calls == 3)
    }

    @Test func stopsAtFirstSuccess() async {
        var calls = 0
        let ok = await ProductLoadRetry.run(attempts: 3, delay: { _ in }) {
            calls += 1
            return true
        }
        #expect(ok)
        #expect(calls == 1)
    }

    @Test func givesUpAfterAllAttempts() async {
        var calls = 0
        let ok = await ProductLoadRetry.run(attempts: 3, delay: { _ in }) {
            calls += 1
            return false
        }
        #expect(!ok)
        #expect(calls == 3)
    }

    @Test func backsOffBetweenAttempts() async {
        var waits: [Int] = []
        _ = await ProductLoadRetry.run(attempts: 4, delay: { waits.append($0) }) { false }
        // One wait per gap between attempts, growing.
        #expect(waits.count == 3)
        #expect(waits == waits.sorted())
        #expect(waits.first! < waits.last!)
    }
}
