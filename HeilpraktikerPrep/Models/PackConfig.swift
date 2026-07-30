import Foundation

struct MockExamConfig: Codable, Equatable {
    let questionCount: Int
    let minutes: Int
    let passPercent: Int
}

struct ProductIDs: Codable, Equatable {
    let weekly: String
    let monthly: String
}

struct LegalLinks: Codable, Equatable {
    let privacyUrl: String
    let termsUrl: String
    let supportEmail: String
    let supportUrl: String?
}

/// A selectable region/jurisdiction (e.g., a country or regional exam variant). Optional —
/// niches without regional variation simply omit `regions` in pack.json.
struct Region: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let name: String
}

/// Niche-defining configuration. Swapping this file (plus questions/strings/assets)
/// turns the base into a different prep-test app — no Swift changes.
struct PackConfig: Codable, Equatable {
    let examName: String
    let examShortName: String
    let tagline: String
    /// BCP-47 code of the single language this app ships in (e.g. "en", "pt-BR").
    let language: String
    let accentHex: String
    let subjects: [Subject]
    let mockExam: MockExamConfig
    let dailyQuestionsCount: Int
    let quickQuizCount: Int
    /// How many Quick quizzes a free user gets (lifetime) before the paywall.
    let freeQuickQuizzes: Int
    /// How many Daily sessions a free user gets (lifetime) before the paywall.
    let freeDailyQuizzes: Int
    let products: ProductIDs
    let legal: LegalLinks
    /// App Store URL — set after ASC registration; share falls back to text-only.
    let appStoreUrl: String?
    /// Optional regional variation (e.g., region-specific exam content). Drives the onboarding
    /// state-picker step, the Settings row, and question-pool filtering.
    let regions: [Region]?
    /// Optional gamification badges. Omitted → no achievements UI.
    let achievements: [AchievementDef]?
}
