import Foundation

/// Every user-visible UI string in the app, loaded from `ContentPack/strings.json`.
/// All fields are required — a translation missing any key fails at decode time,
/// which is caught at launch in DEBUG. Views must never contain visible string literals.
struct UIStrings: Codable, Equatable {
    let tabs: Tabs
    let common: Common
    let home: Home
    let quiz: Quiz
    let results: Results
    let study: Study
    let review: Review
    let stats: Stats
    let settings: Settings
    let paywall: Paywall
    let empty: Empty
    let onboarding: Onboarding

    struct Tabs: Codable, Equatable {
        let home: String
        let study: String
        let review: String
        let stats: String
        let settings: String
    }

    struct Common: Codable, Equatable {
        let continueButton: String
        let cancel: String
        let save: String
        let done: String
        let skip: String
        let close: String
        let ok: String
        let retry: String
        let pro: String
        let questionsUnit: String
    }

    struct Home: Codable, Equatable {
        let greetingMorning: String
        let greetingAfternoon: String
        let greetingEvening: String
        let dailyQuestionsTitle: String
        let dailyQuestionsSubtitle: String
        let dailyQuestionsDone: String
        let dailyUnlockCta: String
        let startButton: String
        let unlockBannerFormat: String
        let modesSectionTitle: String
        let daysLeftFormat: String
        let modeQuick10Title: String
        let modeQuick10Subtitle: String
        let modeQuick10Info: String
        let quick10FreeLeftFormat: String
        let modeTimedTitle: String
        let modeTimedSubtitle: String
        let modeTimedInfo: String
        let modeMissedTitle: String
        let modeMissedSubtitle: String
        let modeMissedInfo: String
        let modeCollectedTitle: String
        let modeCollectedSubtitle: String
        let modeCollectedInfo: String
        let modeMockTitle: String
        let modeMockSubtitle: String
        let modeMockInfo: String
        let modeCustomTitle: String
        let modeCustomSubtitle: String
        let modeCustomInfo: String
        let modeReviewTitle: String
        let modeReviewDueFormat: String
        let modeReviewEmpty: String
        let modeReviewInfo: String
        let modeInfoTitle: String
        let modeInfoDismiss: String
        let dailyCountFormat: String
        let dailyPlanFormat: String
        let dailyFreeLeftFormat: String
        let timedQuestionsLabel: String
        let timedMinutesLabel: String
    }

    struct Quiz: Codable, Equatable {
        let questionCounterFormat: String
        let showExplanation: String
        let hideExplanation: String
        let next: String
        let finish: String
        let quitTitle: String
        let quitMessageFormat: String
        let quitButton: String
        let viewResults: String
        let keepGoing: String
        let timeUpTitle: String
        let timeUpMessage: String
        let correctLabel: String
        let wrongLabel: String
        let a11yBookmark: String
        let a11yFontSize: String
    }

    struct Results: Codable, Equatable {
        let headlineGreat: String
        let headlineGood: String
        let headlineKeepTrying: String
        let scoreLabel: String
        let streakLabel: String
        let timeLabel: String
        let retakeQuiz: String
        let reviewQuiz: String
        let subjectsSection: String
        let answerCardSection: String
        let questionsSection: String
        let correct: String
        let wrong: String
        let flagged: String
        let shareButton: String
        let shareFormat: String
        let shareChallengeFormat: String
    }

    struct Study: Codable, Equatable {
        let title: String
        let overallProgress: String
        let continueQuiz: String
        let answeredFormat: String
        let accuracyFormat: String
        let filterNew: String
        let filterAll: String
        let emptyNew: String
    }

    struct Review: Codable, Equatable {
        let title: String
        let filterAll: String
        let filterCorrect: String
        let filterWrong: String
        let filterBookmarked: String
        let yourAnswer: String
        let correctAnswer: String
    }

    struct Stats: Codable, Equatable {
        let title: String
        let upcomingExam: String
        let daysFormat: String
        let dayStreak: String
        let quizAccuracy: String
        let week: String
        let month: String
        let quarter: String
        let subjectAnalysis: String
        let questionsAnswered: String
        let correctAnswers: String
        let totalTime: String
        let onAverage: String
        let inTotal: String
        let averageScore: String
        let answeredFormat: String
        let achievements: String
        let passProbabilityTitle: String
        let passProbabilitySubtitle: String
        let passProbabilityPending: String
        let passReadyRating: String
        let passBuildingRating: String
        let passDrillRating: String
        let seeAll: String
        let unlockedCountFormat: String
        let achievementUnlocked: String
        let achievementProgressFormat: String
        let freezesFormat: String
        let freezesPluralFormat: String
        let freezeUsedTitle: String
        let freezeUsedMessage: String
        let quizTimes: String
        let quizTimesHelp: String
        let practiceTime: String
        let practiceTimeHelp: String
        let correctQuestions: String
        let missedQuestions: String
    }

    struct Settings: Codable, Equatable {
        let title: String
        let practiceSection: String
        let quizModeTitle: String
        let learningMode: String
        let learningModeDesc: String
        let quickMode: String
        let quickModeDesc: String
        let mockMode: String
        let mockModeDesc: String
        let examDate: String
        let examState: String
        let dailyGoal: String
        let notifications: String
        let reminderTime: String
        let appearance: String
        let light: String
        let dark: String
        let system: String
        let generalSection: String
        let restorePurchases: String
        let shareApp: String
        let rateApp: String
        let termsOfUse: String
        let privacyPolicy: String
        let resetProgress: String
        let resetConfirmTitle: String
        let resetConfirmMessage: String
        let contactUs: String
        let reminderNotificationTitle: String
        let reminderNotificationBody: String
        let stateChangeTitle: String
        let stateChangeMessageFormat: String
        let stateChangeConfirm: String
        let signInTitle: String
        let signInSubtitle: String
        let signedInFormat: String
        let signOut: String
        let deleteAccount: String
        let deleteAccountConfirmTitle: String
        let deleteAccountConfirmMessage: String
        let deleteAccountConfirmButton: String
        let examNotif30DayTitle: String
        let examNotif30DayBody: String
        let examNotif14DayTitle: String
        let examNotif14DayBody: String
        let examNotif7DayTitle: String
        let examNotif7DayBody: String
        let examNotif3DayTitle: String
        let examNotif3DayBody: String
        let examNotifDayTitle: String
        let examNotifDayBody: String
        let lapseNotifTitle: String
        let lapseNotifBody: String
        let lapseNotifStreakFormat: String
    }

    struct Paywall: Codable, Equatable {
        let title: String
        let titleDailyCap: String
        let titleQuickCap: String
        let titleStudyLocked: String
        let loadErrorTitle: String
        let retry: String
        let feature1: String
        let feature2: String
        let feature3: String
        let feature4: String
        let weeklyName: String
        let monthlyName: String
        let perWeek: String
        let perMonth: String
        let saveBadge: String
        let timelineInstall: String
        let timelineToday: String
        let timelineMember: String
        let trialCta: String
        let continueCta: String
        let monthlySubtitleFormat: String
        let monthlyNoTrialSubtitleFormat: String
        let weeklySubtitleFormat: String
        let securedNote: String
        let restore: String
        let weeklyTodayLine: String
        let weeklyRenewLine: String
        let monthlyTodayLine: String
        let monthlyRenewLine: String
        let exitOfferTitle: String
        let exitOfferSubtitle: String
        let exitOfferCta: String
        let exitOfferNoThanks: String
        let exitOfferSubtitleFormat: String
    }

    struct Onboarding: Codable, Equatable {
        let value1Title: String
        let value1Subtitle: String
        let value2Title: String
        let value2Subtitle: String
        let levelTitle: String
        let levelSubtitle: String
        let levelNewbie: String
        let levelSkilled: String
        let levelMaster: String
        let levelExpert: String
        let goalTitle: String
        let goalSubtitle: String
        let goalPass: String
        let goalKnowledge: String
        let goalSkills: String
        let goalBarriers: String
        let takenTitle: String
        let takenSubtitle: String
        let takenNever: String
        let takenOnce: String
        let takenMany: String
        let concernTitle: String
        let concernSubtitle: String
        let concernFailing: String
        let concernTime: String
        let concernMaterial: String
        let concernAnxiety: String
        let painTitle: String
        let painLead: String
        let painPoints: [String]
        let painFailingTitle: String
        let painFailingLead: String
        let painFailingPoints: [String]
        let painTimeTitle: String
        let painTimeLead: String
        let painTimePoints: [String]
        let painMaterialTitle: String
        let painMaterialLead: String
        let painMaterialPoints: [String]
        let painAnxietyTitle: String
        let painAnxietyLead: String
        let painAnxietyPoints: [String]
        let methodTitle: String
        let methodLead: String
        let methodPoints: [String]
        let minutesTitle: String
        let minutesSubtitle: String
        let minutesFormat: String
        let minutesMaxLabel: String
        let daysTitle: String
        let daysSubtitle: String
        let timeTitle: String
        let timeSubtitle: String
        let stateTitle: String
        let stateSubtitle: String
        let stateSearch: String
        let examDateTitle: String
        let examDateSubtitle: String
        let examDateUnknown: String
        let streakTitle: String
        let streakSubtitle: String
        let streakFormat: String
        let notifTitle: String
        let notifSubtitle: String
        let notifEnable: String
        let notifLater: String
        let subjectsTitle: String
        let subjectsSubtitle: String
        let personalizingTitle: String
        let personalizingStep1: String
        let personalizingStep2: String
        let personalizingStep3: String
        let planTitle: String
        let planSubtitle: String
        let planPerDayFormat: String
        let planCta: String
        let planBullet1: String
        let planBullet2: String
        let planBullet3: String
        let planCtaSubtext: String
        let planQuestionsLabel: String
        let planTopicsLabel: String
        let welcomeTitle: String
        let welcomeSubtitle: String
        let welcomeCta: String
    }

    struct Empty: Codable, Equatable {
        let reviewTitle: String
        let reviewSubtitle: String
        let collectedTitle: String
        let collectedSubtitle: String
        let missedTitle: String
        let missedSubtitle: String
    }
}
