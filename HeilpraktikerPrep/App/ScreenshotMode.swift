#if DEBUG
import SwiftUI

/// App Store screenshot harness — active only when the process is launched
/// with SCREENSHOT_SCREEN in the environment (never in normal use, never in
/// Release). Seeds a believable premium profile and renders one screen as
/// root so `simctl io screenshot` can capture it.
@MainActor
enum ScreenshotMode {
    static var screen: String? {
        ProcessInfo.processInfo.environment["SCREENSHOT_SCREEN"]
    }

    static var isActive: Bool { screen != nil }

    /// Replaces user state with the showcase fixture. Idempotent: wipes
    /// progress first so repeated launches don't stack history.
    static func seed(_ session: AppSession) {
        // Premium everywhere EXCEPT the paywall — that shot must show the plans
        // and prices (used as the App Review screenshot for the subscriptions).
        session.iap.debugEntitlement = (screen?.hasPrefix("paywall") == true) ? .free : .premium
        if screen?.hasPrefix("paywall") == true {
            // StoreKit products don't load under simctl, so inject display
            // prices to render a complete paywall (no "couldn't load" banner).
            session.iap.debugWeeklyPrice = "6,99 €"
            session.iap.debugMonthlyPrice = "17,99 €"
        }
        // Keep the rate prompt out of the frame — both the 14-day cooldown and
        // the one-shot "first quiz as premium" prompt (which would otherwise
        // pop over the results screenshot).
        UserDefaults.standard.set(Date.now, forKey: "ratePrompt.lastDate.v1")
        UserDefaults.standard.set(true, forKey: "ratePrompt.premiumAsked.v1")

        var profile = UserProfile()
        profile.level = .skilled
        profile.goal = .passExam
        profile.stateId = "CA"
        profile.examDate = Calendar.current.date(byAdding: .day, value: 24, to: .now)
        profile.examDateSetAt = Calendar.current.date(byAdding: .day, value: -8, to: .now)
        profile.dailyMinutes = 15
        profile.studyDays = [2, 3, 4, 5, 6]
        profile.preferredHour = 19
        profile.streakGoal = 14
        profile.planQuestionsPerDay = 20
        profile.weakSubjectIds = ["pharmacology", "cardiology"]
        profile.hasCompletedOnboarding = true
        session.profile = profile

        session.progress.resetAll()
        seedHistory(session)
        // Mark every already-earned badge as celebrated so the unlock sheet
        // doesn't pop over the results screenshot.
        session.progress.markCelebrated(Set(session.achievementStatuses.filter(\.unlocked).map(\.id)))
    }

    /// Eight days of completed sessions with rising accuracy — fills the
    /// streak flames, sparklines, activity chart and subject breakdown.
    private static func seedHistory(_ session: AppSession) {
        let calendar = Calendar.current
        let pool = session.questionPool
        guard !pool.isEmpty else { return }

        // For the Home shot history stops yesterday so the Daily CTA is live;
        // everywhere else today is filled so charts don't dip to zero.
        let lastDay = screen == "home" ? 1 : 0
        let anchor = calendar.date(bySettingHour: 19, minute: 12, second: 0, of: .now) ?? .now
        var cursor = 0
        for daysAgo in stride(from: 8, through: lastDay, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: anchor)
            else { continue }
            // Tuned so the Stats screenshot reads Pass Probability 79% (last-60
            // accuracy 50/60) while overall Quiz Accuracy stays 81% (146/180).
            let accuracy = [0.7, 0.7, 0.8, 0.8, 0.85, 0.85, 0.85, 0.8, 0.8][8 - daysAgo]
            let answers = (0..<20).map { n -> AnswerRecord in
                let question = pool[(cursor + n) % pool.count]
                let correct = Double(n % 10) < accuracy * 10
                return AnswerRecord(
                    id: UUID(),
                    questionId: question.id,
                    selectedIndex: correct ? question.correctIndex
                                           : (question.correctIndex + 1) % question.choices.count,
                    isCorrect: correct,
                    date: day,
                    quizMode: .daily)
            }
            cursor += 20
            session.progress.record(attempt: QuizAttempt(
                id: UUID(),
                mode: .daily,
                startedAt: day.addingTimeInterval(-540),
                completedAt: day,
                answers: answers,
                durationSeconds: 540))
        }
    }

    /// The requested screen, fully wired to the seeded session.
    @ViewBuilder
    static func root(_ session: AppSession) -> some View {
        switch screen {
        case "quiz":
            // A SHORT question, already answered in learning mode, so the
            // revealed correct answer (green) AND its explanation are on screen.
            let pool = session.content.questions.filter {
                $0.text.count <= 80 && $0.explanation.count <= 165
            }
            let qs = Array((pool.isEmpty ? session.content.questions : pool).prefix(8))
            let controller = QuizController(
                session: QuizSession(mode: .custom, feedback: .learning,
                                     questions: qs, shuffleSeed: 7),
                timeLimitSeconds: nil, progress: session.progress)
            QuizView(controller: answeredFirst(controller))
        case "results":
            if let controller = QuizController.make(mode: .quick10, app: session) {
                QuizResultsView(controller: completed(controller), onClose: {})
            }
        case "paywall":
            PaywallView()
        case "paywall_exit":
            PaywallView(startOnExitOffer: true)
        case "sharecard":
            // Visual check of the share card at full size on a neutral backdrop.
            let s = session.strings.results
            ZStack {
                Color.black.ignoresSafeArea()
                ShareCardView(data: ShareCardData(
                    eyebrow: session.pack.examName.uppercased(with: .current),
                    headline: s.headlineGreat,
                    score: 92, correctText: "23/25", streak: 7, timeText: "4:12",
                    challenge: String(format: s.shareChallengeFormat, 92),
                    brandName: session.pack.examName, tagline: session.pack.tagline,
                    correctLabel: s.correct, streakLabel: s.streakLabel, timeLabel: s.timeLabel, scoreLabel: s.scoreLabel,
                    iconGlyph: session.pack.examShortName.lowercased(with: .current)),
                    cornerRadius: 24)
                    .frame(width: ShareCardView.canvasWidth, height: ShareCardView.canvasHeight)
            }
        case "imgquiz":
            // A real quiz question that carries a sign image.
            let imgQs = session.content.questions.filter { $0.imageName != nil || $0.imageURL != nil }
            if !imgQs.isEmpty {
                let controller = QuizController(
                    session: QuizSession(mode: .custom, feedback: .learning,
                                         questions: Array(imgQs.prefix(10)),
                                         shuffleSeed: .random(in: .min ... .max)),
                    timeLimitSeconds: nil, progress: session.progress)
                QuizView(controller: controller)
            }
        case "achievements":
            NavigationStack { AchievementsView() }
        case "signs":
            // Verify every MUTCD SVG asset renders via Image(name) — driven
            // by the actual question pool, so a missing/typo'd asset would
            // surface as a blank tile here.
            let keys = Array(Set(session.content.questions.compactMap(\.imageName))).sorted()
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 12) {
                    ForEach(keys, id: \.self) { k in
                        VStack(spacing: 4) {
                            Image(k).resizable().scaledToFit().frame(height: 64)
                            Text(k).font(.system(size: 8)).foregroundStyle(.secondary)
                                .lineLimit(2).multilineTextAlignment(.center)
                        }
                    }
                }.padding()
            }
            .background(AppColor.background.ignoresSafeArea())
        case "subject":
            NavigationStack {
                if let subject = session.pack.subjects.first {
                    SubjectDetailView(subject: subject)
                }
            }
        default:
            // Tabs of the main shell.
            MainTabView(initialTab: ["home": 0, "study": 1, "review": 2, "stats": 3, "settings": 4][screen ?? ""] ?? 0)
        }
    }

    /// Answers the first questions so the quiz screen shows real progress.
    private static func midSession(_ controller: QuizController) -> QuizController {
        for _ in 0..<3 {
            _ = controller.submit(controller.session.currentQuestion?.correctIndex ?? 0)
            controller.advance()
        }
        return controller
    }

    /// Answers the current question correctly WITHOUT advancing, so the screen
    /// shows the revealed answer + explanation (backs the "explained" claim).
    private static func answeredFirst(_ controller: QuizController) -> QuizController {
        _ = controller.submit(controller.session.currentQuestion?.correctIndex ?? 0)
        return controller
    }

    /// Finishes a quick run at 90% for the results screen.
    private static func completed(_ controller: QuizController) -> QuizController {
        var index = 0
        while let question = controller.session.currentQuestion {
            let wrong = (question.correctIndex + 1) % question.choices.count
            _ = controller.submit(index == 4 ? wrong : question.correctIndex)
            controller.advance()
            index += 1
        }
        return controller
    }
}
#endif
