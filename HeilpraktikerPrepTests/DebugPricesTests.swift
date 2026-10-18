import Testing
@testable import HeilpraktikerPrep

struct DebugPricesTests {
    @Test func currencyFollowsPackLanguage() {
        #expect(DebugPrices.currencyCode(for: "pt-BR") == "BRL")
        #expect(DebugPrices.currencyCode(for: "ja") == "JPY")
        #expect(DebugPrices.currencyCode(for: "de") == "EUR")
        #expect(DebugPrices.currencyCode(for: "en") == "USD")
    }
}
