import Testing
@testable import HeilpraktikerPrep

struct ResultBadgeTests {
    private func status(_ id: String, _ current: Int, _ target: Int) -> AchievementStatus {
        let def = AchievementDef(id: id, title: id, detail: "", icon: "star", tint: "#000000",
                                 criterion: .init(type: "totalAnswered", value: target))
        return AchievementStatus(def: def, current: current, target: target)
    }

    @Test func newUnlocksComeFirstThenClosestLocked() {
        let fresh = status("fresh", 5, 5)
        let all = [fresh, status("far", 1, 10), status("close", 9, 10), status("old", 3, 3)]
        let picked = ResultBadge.pick(newlyUnlocked: [fresh], all: all)
        #expect(picked.map(\.id) == ["fresh", "close"])
        #expect(picked[0].justUnlocked && !picked[1].justUnlocked)
    }

    @Test func withoutUnlocksShowsTwoClosestAndSkipsUntouched() {
        let all = [status("zero", 0, 10), status("a", 2, 10), status("b", 8, 10), status("c", 5, 10)]
        #expect(ResultBadge.pick(newlyUnlocked: [], all: all).map(\.id) == ["b", "c"])
    }
}
