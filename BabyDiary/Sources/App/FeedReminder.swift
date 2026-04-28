import Foundation
import UserNotifications

struct FeedReminderSettings: Equatable, Codable {
    static let minIntervalHours = 1
    static let maxIntervalHours = 8

    var isEnabled: Bool = false
    var intervalHours: Int = 4
    var anchorAt: Date? = nil

    var normalizedIntervalHours: Int {
        Self.clampedIntervalHours(intervalHours)
    }

    var interval: TimeInterval {
        TimeInterval(normalizedIntervalHours * 60 * 60)
    }

    static func clampedIntervalHours(_ hours: Int) -> Int {
        min(maxIntervalHours, max(minIntervalHours, hours))
    }
}

enum FeedReminderPlanner {
    static let fallbackDelay: TimeInterval = 60

    static func dueDate(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        now: Date = Date()
    ) -> Date? {
        guard settings.isEnabled else { return nil }
        let anchor = lastFeed?.occurredAt ?? settings.anchorAt ?? now
        return anchor.addingTimeInterval(settings.interval)
    }

    static func scheduledDates(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        now: Date = Date(),
        count: Int = 12
    ) -> [Date] {
        guard settings.isEnabled, count > 0 else { return [] }
        let interval = settings.interval
        let idealFirst = dueDate(settings: settings, lastFeed: lastFeed, now: now) ?? now.addingTimeInterval(interval)
        let first = idealFirst > now ? idealFirst : now.addingTimeInterval(fallbackDelay)

        return (0..<count).map { offset in
            first.addingTimeInterval(TimeInterval(offset) * interval)
        }
    }
}

enum FeedReminderNotificationController {
    private static let identifierPrefix = "BabyDiary.feedReminder."
    private static let scheduledCount = 12

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
        @unknown default:
            return false
        }
    }

    static func sync(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        babyName: String,
        now: Date = Date()
    ) {
        Task {
            await syncAsync(settings: settings, lastFeed: lastFeed, babyName: babyName, now: now)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
    }

    private static func syncAsync(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        babyName: String,
        now: Date
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)

        guard settings.isEnabled else { return }
        let notificationSettings = await center.notificationSettings()
        guard notificationSettings.authorizationStatus == .authorized ||
              notificationSettings.authorizationStatus == .provisional ||
              notificationSettings.authorizationStatus == .ephemeral else {
            return
        }

        let dates = FeedReminderPlanner.scheduledDates(
            settings: settings,
            lastFeed: lastFeed,
            now: now,
            count: scheduledCount
        )

        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "该喂奶了"
            content.body = bodyText(settings: settings, babyName: babyName)
            content.sound = .default
            content.userInfo = [
                "destination": BabyDiaryDestination.feed.rawValue
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(index)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static var reminderIdentifiers: [String] {
        (0..<scheduledCount).map { "\(identifierPrefix)\($0)" }
    }

    private static func bodyText(settings: FeedReminderSettings, babyName: String) -> String {
        "\(babyName) 距离上次喂奶已经 \(settings.normalizedIntervalHours) 小时"
    }
}

extension Notification.Name {
    static let babyDiaryNotificationDestination = Notification.Name("BabyDiary.notificationDestination")
}
