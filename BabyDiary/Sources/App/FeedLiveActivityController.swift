import ActivityKit
import Foundation

enum FeedLiveActivityController {
    static func update(draft: FeedDraft?, babyName: String) {
        Task { await updateActivities(draft: draft, babyName: babyName) }
    }

    static func end(babyName: String) {
        Task { await endActivities(babyName: babyName) }
    }

    @available(iOS 16.2, *)
    private static func updateActivities(draft: FeedDraft?, babyName: String) async {
        guard let draft, let state = state(from: draft) else {
            await endActivities(babyName: babyName)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = ActivityContent(
            state: state,
            staleDate: state.startedAt.addingTimeInterval(4 * 60 * 60),
            relevanceScore: 1
        )

        let activities = Activity<BabyDiaryFeedAttributes>.activities
        guard !activities.isEmpty else {
            _ = try? Activity.request(
                attributes: BabyDiaryFeedAttributes(babyName: babyName),
                content: content,
                pushType: nil
            )
            return
        }

        for activity in activities {
            await activity.update(content)
        }
    }

    @available(iOS 16.2, *)
    private static func endActivities(babyName: String) async {
        let content = ActivityContent(
            state: BabyDiaryFeedAttributes.ContentState(
                mode: .breast,
                startedAt: Date(),
                accumulated: 0,
                resumedAt: nil,
                updatedAt: Date(),
                activeSide: nil,
                breastLeftDuration: 0,
                breastRightDuration: 0,
                milliliters: nil
            ),
            staleDate: nil,
            relevanceScore: 0
        )

        for activity in Activity<BabyDiaryFeedAttributes>.activities {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }

    private static func state(from draft: FeedDraft) -> BabyDiaryFeedAttributes.ContentState? {
        switch draft.mode {
        case .breast:
            guard draft.breastSubMode == .timer,
                  draft.breastPhase == .running || draft.breastPhase == .paused else {
                return nil
            }

            let accumulated = draft.breastLeftDuration + draft.breastRightDuration
            return BabyDiaryFeedAttributes.ContentState(
                mode: .breast,
                startedAt: draft.breastSessionStart ?? draft.breastSegmentStart ?? Date(),
                accumulated: accumulated,
                resumedAt: draft.breastPhase == .running ? draft.breastSegmentStart : nil,
                updatedAt: Date(),
                activeSide: draft.breastActiveSide == .left ? .left : .right,
                breastLeftDuration: draft.breastLeftDuration,
                breastRightDuration: draft.breastRightDuration,
                milliliters: nil
            )
        case .formula:
            guard draft.formulaSubMode == .timer,
                  draft.formulaPhase == .running || draft.formulaPhase == .paused else {
                return nil
            }

            return BabyDiaryFeedAttributes.ContentState(
                mode: .formula,
                startedAt: draft.formulaSessionStart ?? draft.formulaSegmentStart ?? Date(),
                accumulated: draft.formulaDuration,
                resumedAt: draft.formulaPhase == .running ? draft.formulaSegmentStart : nil,
                updatedAt: Date(),
                activeSide: nil,
                breastLeftDuration: 0,
                breastRightDuration: 0,
                milliliters: draft.formulaMilliliters
            )
        }
    }
}
