import ActivityKit
import Foundation

enum SleepLiveActivityController {
    static func start(timer: RunningTimer, babyName: String) {
        guard timer.kind == .sleep else { return }
        Task { await startActivity(timer: timer, babyName: babyName) }
    }

    static func update(timer: RunningTimer, babyName: String) {
        guard timer.kind == .sleep else { return }
        Task { await updateActivities(timer: timer, babyName: babyName) }
    }

    static func end(timer: RunningTimer?, babyName: String) {
        Task { await endActivities(timer: timer, babyName: babyName) }
    }

    @available(iOS 16.2, *)
    private static func startActivity(timer: RunningTimer, babyName: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endActivities(timer: nil, babyName: babyName)

        let attributes = BabyDiarySleepAttributes(babyName: babyName)
        let content = ActivityContent(
            state: state(from: timer),
            staleDate: timer.startedAt.addingTimeInterval(12 * 60 * 60),
            relevanceScore: 1
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    @available(iOS 16.2, *)
    private static func updateActivities(timer: RunningTimer, babyName: String) async {
        let activities = Activity<BabyDiarySleepAttributes>.activities
        guard !activities.isEmpty else {
            await startActivity(timer: timer, babyName: babyName)
            return
        }

        let content = ActivityContent(
            state: state(from: timer),
            staleDate: timer.startedAt.addingTimeInterval(12 * 60 * 60),
            relevanceScore: 1
        )
        for activity in activities {
            await activity.update(content)
        }
    }

    @available(iOS 16.2, *)
    private static func endActivities(timer: RunningTimer?, babyName: String) async {
        let fallbackState = BabyDiarySleepAttributes.ContentState(
            startedAt: Date(),
            accumulated: 0,
            resumedAt: nil,
            updatedAt: Date()
        )
        let finalState = timer.map(state(from:)) ?? fallbackState
        let content = ActivityContent(
            state: finalState,
            staleDate: nil,
            relevanceScore: 0
        )
        for activity in Activity<BabyDiarySleepAttributes>.activities {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }

    private static func state(from timer: RunningTimer) -> BabyDiarySleepAttributes.ContentState {
        BabyDiarySleepAttributes.ContentState(
            startedAt: timer.startedAt,
            accumulated: timer.accumulated,
            resumedAt: timer.resumedAt,
            updatedAt: Date()
        )
    }
}
