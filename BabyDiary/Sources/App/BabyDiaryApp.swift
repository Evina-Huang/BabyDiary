import SwiftUI
import UIKit
import UserNotifications

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
