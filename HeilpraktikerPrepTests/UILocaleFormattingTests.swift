import Foundation
import Testing
@testable import HeilpraktikerPrep

/// UI numbers follow the pack language, not the device locale.
struct UILocaleFormattingTests {
    @Test func ratingUsesPackLocaleNotDevice() {
        #expect(OnboardingRightPlaceStep.formatRating(5, locale: Locale(identifier: "en")) == "5.0")
        #expect(OnboardingRightPlaceStep.formatRating(4.8, locale: Locale(identifier: "pt-BR")) == "4,8")
        #expect(OnboardingRightPlaceStep.formatRating(4.8, locale: Locale(identifier: "de")) == "4,8")
    }
}
