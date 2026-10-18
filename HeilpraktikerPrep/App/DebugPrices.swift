#if DEBUG
import Foundation

/// Stand-in prices for simulator runs, where StoreKit loads no products.
/// Formatted in the pack language's home currency so screenshots and QA of a
/// non-BR app never show reais.
enum DebugPrices {
    private static let weekly = Decimal(string: "6.99")!
    private static let monthly = Decimal(string: "17.99")!
    private static let quarterly = Decimal(string: "34.99")!
    private static let savingsPercent = 35

    @MainActor
    static func apply(to iap: IAPService, language: String) {
        let style = Decimal.FormatStyle.Currency(code: currencyCode(for: language),
                                                 locale: Locale(identifier: language))
        iap.debugWeeklyPrice = weekly.formatted(style)
        iap.debugMonthlyPrice = monthly.formatted(style)
        iap.debugQuarterlyPrice = quarterly.formatted(style)
        iap.debugPerDayMonthly = (monthly / 30).formatted(style)
        iap.debugPerDayQuarterly = (quarterly / 90).formatted(style)
        iap.debugSavingsPercent = savingsPercent
    }

    /// "ja" → JPY, "pt-BR" → BRL, "es-419" → USD (no single home currency).
    static func currencyCode(for language: String) -> String {
        let components = Locale.Language(identifier: language).maximalIdentifier
        let region = Locale.Language(identifier: components).region
        guard let region else { return "USD" }
        return Locale(languageCode: nil, languageRegion: region).currency?.identifier ?? "USD"
    }
}
#endif
