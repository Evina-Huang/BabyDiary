import SwiftUI
import UIKit
import UserNotifications
import AppIntents

@main
struct BabyDiaryApp: App {
    @UIApplicationDelegateAdaptor(BabyDiaryAppDelegate.self) private var appDelegate
    @State private var store = AppStore.loadedOrSeeded()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(store.theme.primary600)
                .preferredColorScheme(.light)
        }
    }
}

final class BabyDiaryAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let destination = response.notification.request.content.userInfo["destination"] as? String else { return }
        await MainActor.run {
            NotificationCenter.default.post(
                name: .babyDiaryNotificationDestination,
                object: nil,
                userInfo: ["destination": destination]
            )
        }
    }
}

struct StartFeedingIntent: AppIntent {
    static var title: LocalizedStringResource = "开始喂奶"
    static var description = IntentDescription("开始一次母乳喂奶计时。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = BabyDiaryShortcutCoordinator.startFeeding()
        let dialog: IntentDialog = status == .started ? "已开始喂奶" : "已经在喂奶"
        return .result(dialog: dialog)
    }
}

struct StartSleepingIntent: AppIntent {
    static var title: LocalizedStringResource = "开始睡觉"
    static var description = IntentDescription("开始一次睡眠计时。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = BabyDiaryShortcutCoordinator.startSleeping()
        let dialog: IntentDialog = status == .started ? "已开始睡觉" : "已经在睡觉"
        return .result(dialog: dialog)
    }
}

struct BabyDiaryAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFeedingIntent(),
            phrases: [
                "用 \(.applicationName) 我要喂奶",
                "用 \(.applicationName) 开始喂奶",
                "在 \(.applicationName) 记录喂奶",
                "\(.applicationName) 我要喂奶"
            ],
            shortTitle: "开始喂奶",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: StartSleepingIntent(),
            phrases: [
                "用 \(.applicationName) 开始睡觉",
                "用 \(.applicationName) 宝宝开始睡觉",
                "在 \(.applicationName) 记录睡觉",
                "\(.applicationName) 开始睡觉"
            ],
            shortTitle: "开始睡觉",
            systemImageName: "moon.fill"
        )
    }
}

@MainActor
enum BabyDiaryShortcutCoordinator {
    private static let pendingDestinationKey = "BabyDiary.shortcutDestination"
    private static weak var activeStore: AppStore?

    static func register(_ store: AppStore) {
        activeStore = store
    }

    static func startFeeding(at date: Date = Date()) -> ShortcutStartStatus {
        let target = activeStore ?? AppStore.loadedOrSeeded()
        let status = target.startFeedFromShortcut(at: date)
        requestOpen(.feed)
        return status
    }

    static func startSleeping(at date: Date = Date()) -> ShortcutStartStatus {
        let target = activeStore ?? AppStore.loadedOrSeeded()
        let status = target.startSleepFromShortcut(at: date)
        requestOpen(.sleep)
        return status
    }

    static func consumePendingDestination() -> BabyDiaryDestination? {
        guard let rawValue = UserDefaults.standard.string(forKey: pendingDestinationKey) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: pendingDestinationKey)
        return BabyDiaryDestination(rawValue: rawValue)
    }

    private static func requestOpen(_ destination: BabyDiaryDestination) {
        UserDefaults.standard.set(destination.rawValue, forKey: pendingDestinationKey)
        NotificationCenter.default.post(
            name: .babyDiaryShortcutDestination,
            object: nil,
            userInfo: ["destination": destination.rawValue]
        )
    }
}
