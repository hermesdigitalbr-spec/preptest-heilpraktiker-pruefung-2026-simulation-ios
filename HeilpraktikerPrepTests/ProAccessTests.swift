import Testing
@testable import HeilpraktikerPrep

struct ProAccessTests {
    @Test func dailyIsAlwaysFree() {
        #expect(!ProAccess.isLocked(mode: .daily, isPro: false,
                                    quickQuizzesUsed: 99, freeQuickQuizzes: 3))
    }

    @Test func quickQuizFreeWithinAllowance() {
        #expect(!ProAccess.isLocked(mode: .quick10, isPro: false,
                                    quickQuizzesUsed: 0, freeQuickQuizzes: 3))
        #expect(!ProAccess.isLocked(mode: .quick10, isPro: false,
                                    quickQuizzesUsed: 2, freeQuickQuizzes: 3))
    }

    @Test func quickQuizLockedAfterAllowance() {
        #expect(ProAccess.isLocked(mode: .quick10, isPro: false,
                                   quickQuizzesUsed: 3, freeQuickQuizzes: 3))
        #expect(ProAccess.isLocked(mode: .quick10, isPro: false,
                                   quickQuizzesUsed: 7, freeQuickQuizzes: 3))
    }

    @Test func paidModesAreLockedForFreeUsers() {
        for mode in [QuizMode.timed, .missed, .collected, .mock, .custom] {
            #expect(ProAccess.isLocked(mode: mode, isPro: false))
        }
    }

    @Test func nothingIsLockedForPro() {
        for mode in QuizMode.allCases {
            #expect(!ProAccess.isLocked(mode: mode, isPro: true,
                                        quickQuizzesUsed: 99, freeQuickQuizzes: 3))
        }
    }

    @Test func remainingFreeNeverNegative() {
        #expect(ProAccess.remainingFreeQuickQuizzes(used: 5, allowance: 3) == 0)
        #expect(ProAccess.remainingFreeQuickQuizzes(used: 1, allowance: 3) == 2)
    }
}
