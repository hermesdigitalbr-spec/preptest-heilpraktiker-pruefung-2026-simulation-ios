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
        // VoiceOver (accessibility) texts
        let a11yClose: String
        let a11yExpandImage: String
        let a11yOptionFormat: String        // %1$@ = letter, %2$@ = option text
        let a11ySelected: String
        let a11yCorrectAnswer: String
        let a11yYourAnswerWrong: String
        let a11yUnlockedFormat: String      // %1$@ = title, %2$@ = detail
        let a11yLockedFormat: String        // %1$@ = title, %2$@ = detail
    }

    struct Home: Codable, Equatable {
        let greetingMorning: String
        let greetingAfternoon: String
        let greetingEvening: String
        let greetingWithNameFormat: String
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
        let verdictCorrect: String
        let verdictWrong: String
        let answerChipFormat: String
        let explanationLabel: String
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
        /// Verdadeiro/Falso packs: the two fixed choices and their short tokens
        /// (pt-BR "V"/"F", en "T"/"F").
        let trueLabel: String
        let falseLabel: String
        let trueLetter: String
        let falseLetter: String
    }

    struct Results: Codable, Equatable {
        let calculating: String
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
        let shareStoreBadge: String
        let sharePreviewTitle: String
        let correctOfFormat: String
        let badgeUnlockedFormat: String
        let badgeNextFormat: String
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
        let emptyEmoji: String
        let emptyTitle: String
        let emptyBody: String
        let emptyCta: String
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
        let dailyLogTitle: String
        let dailyLogMinutesFormat: String
        let dailyLogHoursFormat: String
        let studyLogDays: String
        let studyLogMocks: String
        let dailyLogQuestionsFormat: String
        let dailyLogMocksFormat: String
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
        let examStateFormat: String
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
        let notifEducationTitle: String
        let notifEducationBody: String
        let notifEducationStep1Prefix: String
        let notifEducationStep1Bold: String
        let notifEducationStep1Suffix: String
        let notifEducationStep2Prefix: String
        let notifEducationStep2Bold: String
        let notifEducationStep3Prefix: String
        let notifEducationStep3Bold: String
        let notifEducationCta: String
        let notifEducationEnableCta: String
        let notifEducationLater: String
        let reminderNudgeTitle: String
        let reminderNudgeBody: String
        let reminderNudgeCta: String
        let reminderNotificationTitle: String
        let reminderNotificationBody: String
        let stateChangeTitleFormat: String
        let stateChangeMessageFormat: String
        let stateChangeConfirmFormat: String
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
        let quarterlyName: String
        let perQuarter: String
        let quarterlySubtitleFormat: String
        let perDayFormat: String
        let quarterlyTodayLine: String
        let quarterlyRenewLine: String
        let perWeek: String
        let perMonth: String
        let saveBadge: String
        let timelineInstall: String
        let timelineToday: String
        let timelineMember: String
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
        let slide1Title: String
        let slide1TitleScore: String
        let slide1Subtitle: String
        let slide2TitleFormat: String
        let slide2Subtitle: String
        let slide2CardTitle: String
        let slide2BadgeFormat: String
        let slide2Answer: String
        let signupToastFormat: String
        let signupToastNames: [String]
        let slide3Title: String
        let slide3QuestionsFormat: String
        let slide3Subtitle: String
        let slide3SubtitleScore: String
        let declineCta: String
        let trialCtaFunnel: String
        let monthlyCardName: String
        let quarterlyCardName: String
        let monthlyCardDetailFormat: String
        let quarterlyCardDetailFormat: String
        let saveBadgeFormat: String
        let summaryMonthlyFormat: String
        let summaryQuarterlyFormat: String
        let giftTitle: String
        let giftRibbon: String
        let giftPlanName: String
        let giftPlanDetail: String
        let giftAfter: String
        let giftPerWeek: String
        let giftFreeDays: String
        let giftCta: String
        let monthlyCardPriceFormat: String
        let quarterlyCardPriceFormat: String
        let trialBadge: String
        let subscribeMonthlyCta: String
        let giftSubscribeCta: String
        let subscribeQuarterlyCta: String
        let quarterlyTrialSubtitleFormat: String
        let perDayEquivalentFormat: String
    }

    struct Onboarding: Codable, Equatable {
        let minutesSubtitle: String
        let regionLabelDefault: String
        let stateSearchFormat: String
        let personalizingTitle: String
        let personalizingStep3: String
        let nameTitle: String
        let nameSubtitle: String
        let namePlaceholder: String
        let paceSprint: String
        let paceActive: String
        let paceSteady: String
        let paceAdviceSprint: String
        let paceAdviceActive: String
        let paceAdviceSteady: String
        let minutesHintTightFormat: String
        let minutesHintFits: String
        let forecastToday: String
        let introTitle: String
        let introSubtitleFormat: String
        let introTrustChip: String
        let introStatValue: String
        let introStatLabel: String
        let introStatLabelScore: String
        let stateTitleFunnel: String
        let examDateTitleFunnel: String
        let examDateSubtitleFunnel: String
        let examDateCta: String
        let examDateNoDate: String
        let examDateDaysLeftFormat: String
        let motivationTitle: String
        let motivationSubtitle: String
        let motivationStability: String
        let motivationStabilityDetail: String
        let motivationCalling: String
        let motivationCallingDetail: String
        let motivationFamily: String
        let motivationFamilyDetail: String
        let motivationNewCareer: String
        let motivationNewCareerDetail: String
        let firstTimeTitle: String
        let firstTimeYes: String
        let firstTimeNo: String
        let affirmationFirst: String
        let affirmationFirstScore: String
        let affirmationRetry: String
        let affirmationLead: String
        let levelTitleFunnel: String
        let levelNotReady: String
        let levelSomewhat: String
        let levelReady: String
        let levelVeryReady: String
        let rightPlaceTitle: String
        let rightPlaceTitleGreen: String
        let rightPlaceLead: String
        let rightPlaceProofTop: String
        let rightPlaceProofTopScore: String
        let rightPlaceProofRatingFormat: String
        let reviewsTitle: String
        let reviewsLead: String
        let minutesTitleFunnel: String
        let minutesDaysLeftFormat: String
        let personalizingTitleFunnel: String
        let personalizingApplyingSyllabus: String
        let personalizingSelectingFormat: String
        let personalizingSchedulingFormat: String
        let personalizingPerDayFormat: String
        let personalizingPerDayTail: String
        let planTitleFunnelNamedFormat: String
        let planTitleFunnel: String
        let planBulletQuestions: String
        let planBulletMocks: String
        let planBulletReview: String
        let planPaceNoDate: String
        let planPaceSpeedUp: String
        let planPaceOnTrack: String
        let planPaceLeadNoDate: String
        let planPaceLeadSpeedUp: String
        let planPaceLeadOnTrack: String
        let planPaceLeadPrefixFormat: String
        let forecastTitleFunnel: String
        let detailsTitleFunnel: String
        let detailsExamLabel: String
        let detailsExamDateLabel: String
        let detailsFallbackExamDate: String
        let planCtaFunnel: String
        let minutesPerDayFormat: String
        let hoursPerDayFormat: String
        let reviews: [Review]

        let nameFieldLabel: String
        let forecastFinishEmoji: String
        let detailsExamEmoji: String
        let detailsStateEmoji: String
        let detailsExamDateEmoji: String
        let paceEmoji: String
        let hintEmojiFits: String
        let hintEmojiTight: String
        let rightPlaceProofTopEmoji: String
        let rightPlaceProofRatingEmoji: String
        let levelEmojiNotReady: String
        let levelEmojiSomewhat: String
        let levelEmojiReady: String
        let levelEmojiVeryReady: String
        let amountPerDayFormat: String
        let hoursMinutesPerDayFormat: String
        let minutesPaceSlow: String
        let minutesPaceBalanced: String
        let minutesPaceFast: String
        let minutesPaceIntense: String
        struct Review: Codable, Equatable {
            let title: String
            let body: String
            let author: String
        }
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
