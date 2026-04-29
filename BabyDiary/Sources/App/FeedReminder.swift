import Foundation
import UserNotifications

struct FeedReminderSettings: Equatable, Codable {
    static let minIntervalHours = 1
    static let maxIntervalHours = 8

    var isEnabled: Bool = false
    var intervalHours: Int = 4
    var anchorAt: Date? = nil
    var quietHoursEnabled: Bool = false
    var quietStartMinuteOfDay: Int = 22 * 60
    var quietEndMinuteOfDay: Int = 7 * 60

    init(
        isEnabled: Bool = false,
        intervalHours: Int = 4,
        anchorAt: Date? = nil,
        quietHoursEnabled: Bool = false,
        quietStartMinuteOfDay: Int = 22 * 60,
        quietEndMinuteOfDay: Int = 7 * 60
    ) {
        self.isEnabled = isEnabled
        self.intervalHours = intervalHours
        self.anchorAt = anchorAt
        self.quietHoursEnabled = quietHoursEnabled
        self.quietStartMinuteOfDay = quietStartMinuteOfDay
        self.quietEndMinuteOfDay = quietEndMinuteOfDay
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        intervalHours = try values.decodeIfPresent(Int.self, forKey: .intervalHours) ?? 4
        anchorAt = try values.decodeIfPresent(Date.self, forKey: .anchorAt)
        quietHoursEnabled = try values.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false
        quietStartMinuteOfDay = try values.decodeIfPresent(Int.self, forKey: .quietStartMinuteOfDay) ?? 22 * 60
        quietEndMinuteOfDay = try values.decodeIfPresent(Int.self, forKey: .quietEndMinuteOfDay) ?? 7 * 60
    }

    var normalizedIntervalHours: Int {
        Self.clampedIntervalHours(intervalHours)
    }

    var interval: TimeInterval {
        TimeInterval(normalizedIntervalHours * 60 * 60)
    }

    static func clampedIntervalHours(_ hours: Int) -> Int {
        min(maxIntervalHours, max(minIntervalHours, hours))
    }

    var normalizedQuietStartMinuteOfDay: Int {
        Self.clampedMinuteOfDay(quietStartMinuteOfDay)
    }

    var normalizedQuietEndMinuteOfDay: Int {
        Self.clampedMinuteOfDay(quietEndMinuteOfDay)
    }

    static func clampedMinuteOfDay(_ minute: Int) -> Int {
        min(23 * 60 + 59, max(0, minute))
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case intervalHours
        case anchorAt
        case quietHoursEnabled
        case quietStartMinuteOfDay
        case quietEndMinuteOfDay
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
        let rawDue = anchor.addingTimeInterval(settings.interval)
        return nextAllowedDate(rawDue, settings: settings)
    }

    static func scheduledDates(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        now: Date = Date(),
        count: Int = 12
    ) -> [Date] {
        guard settings.isEnabled, count > 0 else { return [] }
        let interval = settings.interval
        var candidate = dueDate(settings: settings, lastFeed: lastFeed, now: now) ?? now.addingTimeInterval(interval)
        if candidate <= now {
            candidate = nextAllowedDate(now.addingTimeInterval(fallbackDelay), settings: settings)
        }

        var dates: [Date] = []
        var attempts = 0
        while dates.count < count && attempts < count * 8 {
            if candidate > now, dates.last != candidate {
                dates.append(candidate)
            }

            let lastCandidate = candidate
            candidate = nextAllowedDate(lastCandidate.addingTimeInterval(interval), settings: settings)
            if candidate <= lastCandidate {
                candidate = nextAllowedDate(
                    lastCandidate.addingTimeInterval(max(interval, fallbackDelay)),
                    settings: settings
                )
            }
            attempts += 1
        }
        return dates
    }

    static func isInQuietHours(_ date: Date, settings: FeedReminderSettings) -> Bool {
        guard settings.quietHoursEnabled else { return false }
        return ReminderTimeWindow.contains(
            date,
            startMinute: settings.normalizedQuietStartMinuteOfDay,
            endMinute: settings.normalizedQuietEndMinuteOfDay
        )
    }

    static func nextAllowedDate(_ date: Date, settings: FeedReminderSettings) -> Date {
        guard settings.quietHoursEnabled else { return date }
        return ReminderTimeWindow.nextAllowedDate(
            date,
            startMinute: settings.normalizedQuietStartMinuteOfDay,
            endMinute: settings.normalizedQuietEndMinuteOfDay
        )
    }
}

struct SleepReminderSettings: Equatable, Codable {
    static let minAwakeIntervalMinutes = 30
    static let maxAwakeIntervalMinutes = 360

    var isEnabled: Bool = false
    var awakeIntervalMinutes: Int = 120
    var anchorAt: Date? = nil
    var quietHoursEnabled: Bool = false
    var quietStartMinuteOfDay: Int = 22 * 60
    var quietEndMinuteOfDay: Int = 7 * 60

    init(
        isEnabled: Bool = false,
        awakeIntervalMinutes: Int = 120,
        anchorAt: Date? = nil,
        quietHoursEnabled: Bool = false,
        quietStartMinuteOfDay: Int = 22 * 60,
        quietEndMinuteOfDay: Int = 7 * 60
    ) {
        self.isEnabled = isEnabled
        self.awakeIntervalMinutes = awakeIntervalMinutes
        self.anchorAt = anchorAt
        self.quietHoursEnabled = quietHoursEnabled
        self.quietStartMinuteOfDay = quietStartMinuteOfDay
        self.quietEndMinuteOfDay = quietEndMinuteOfDay
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        awakeIntervalMinutes = try values.decodeIfPresent(Int.self, forKey: .awakeIntervalMinutes) ?? 120
        anchorAt = try values.decodeIfPresent(Date.self, forKey: .anchorAt)
        quietHoursEnabled = try values.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false
        quietStartMinuteOfDay = try values.decodeIfPresent(Int.self, forKey: .quietStartMinuteOfDay) ?? 22 * 60
        quietEndMinuteOfDay = try values.decodeIfPresent(Int.self, forKey: .quietEndMinuteOfDay) ?? 7 * 60
    }

    var normalizedAwakeIntervalMinutes: Int {
        Self.clampedAwakeIntervalMinutes(awakeIntervalMinutes)
    }

    var interval: TimeInterval {
        TimeInterval(normalizedAwakeIntervalMinutes * 60)
    }

    static func clampedAwakeIntervalMinutes(_ minutes: Int) -> Int {
        min(maxAwakeIntervalMinutes, max(minAwakeIntervalMinutes, minutes))
    }

    var normalizedQuietStartMinuteOfDay: Int {
        Self.clampedMinuteOfDay(quietStartMinuteOfDay)
    }

    var normalizedQuietEndMinuteOfDay: Int {
        Self.clampedMinuteOfDay(quietEndMinuteOfDay)
    }

    static func clampedMinuteOfDay(_ minute: Int) -> Int {
        FeedReminderSettings.clampedMinuteOfDay(minute)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case awakeIntervalMinutes
        case anchorAt
        case quietHoursEnabled
        case quietStartMinuteOfDay
        case quietEndMinuteOfDay
    }
}

enum SleepReminderPlanner {
    static let fallbackDelay: TimeInterval = 60

    static func dueDate(
        settings: SleepReminderSettings,
        lastSleep: Event?,
        isSleeping: Bool,
        now: Date = Date()
    ) -> Date? {
        guard settings.isEnabled, !isSleeping else { return nil }
        let anchor = lastSleep?.occurredAt ?? settings.anchorAt ?? now
        let rawDue = anchor.addingTimeInterval(settings.interval)
        return nextAllowedDate(rawDue, settings: settings)
    }

    static func scheduledDates(
        settings: SleepReminderSettings,
        lastSleep: Event?,
        isSleeping: Bool,
        now: Date = Date(),
        count: Int = 12
    ) -> [Date] {
        guard settings.isEnabled, !isSleeping, count > 0 else { return [] }
        let interval = settings.interval
        var candidate = dueDate(settings: settings, lastSleep: lastSleep, isSleeping: isSleeping, now: now)
            ?? now.addingTimeInterval(interval)
        if candidate <= now {
            candidate = nextAllowedDate(now.addingTimeInterval(fallbackDelay), settings: settings)
        }

        var dates: [Date] = []
        var attempts = 0
        while dates.count < count && attempts < count * 8 {
            if candidate > now, dates.last != candidate {
                dates.append(candidate)
            }

            let lastCandidate = candidate
            candidate = nextAllowedDate(lastCandidate.addingTimeInterval(interval), settings: settings)
            if candidate <= lastCandidate {
                candidate = nextAllowedDate(
                    lastCandidate.addingTimeInterval(max(interval, fallbackDelay)),
                    settings: settings
                )
            }
            attempts += 1
        }
        return dates
    }

    static func isInQuietHours(_ date: Date, settings: SleepReminderSettings) -> Bool {
        guard settings.quietHoursEnabled else { return false }
        return ReminderTimeWindow.contains(
            date,
            startMinute: settings.normalizedQuietStartMinuteOfDay,
            endMinute: settings.normalizedQuietEndMinuteOfDay
        )
    }

    static func nextAllowedDate(_ date: Date, settings: SleepReminderSettings) -> Date {
        guard settings.quietHoursEnabled else { return date }
        return ReminderTimeWindow.nextAllowedDate(
            date,
            startMinute: settings.normalizedQuietStartMinuteOfDay,
            endMinute: settings.normalizedQuietEndMinuteOfDay
        )
    }
}

enum ReminderNotificationAuthorization {
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
}

enum FeedReminderNotificationController {
    private static let identifierPrefix = "BabyDiary.feedReminder."
    private static let scheduledCount = 12

    static func requestAuthorization() async -> Bool {
        await ReminderNotificationAuthorization.requestAuthorization()
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

enum SleepReminderNotificationController {
    private static let identifierPrefix = "BabyDiary.sleepReminder."
    private static let scheduledCount = 12

    static func requestAuthorization() async -> Bool {
        await ReminderNotificationAuthorization.requestAuthorization()
    }

    static func sync(
        settings: SleepReminderSettings,
        lastSleep: Event?,
        isSleeping: Bool,
        babyName: String,
        now: Date = Date()
    ) {
        Task {
            await syncAsync(
                settings: settings,
                lastSleep: lastSleep,
                isSleeping: isSleeping,
                babyName: babyName,
                now: now
            )
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
    }

    private static func syncAsync(
        settings: SleepReminderSettings,
        lastSleep: Event?,
        isSleeping: Bool,
        babyName: String,
        now: Date
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)

        guard settings.isEnabled, !isSleeping else { return }
        let notificationSettings = await center.notificationSettings()
        guard notificationSettings.authorizationStatus == .authorized ||
              notificationSettings.authorizationStatus == .provisional ||
              notificationSettings.authorizationStatus == .ephemeral else {
            return
        }

        let dates = SleepReminderPlanner.scheduledDates(
            settings: settings,
            lastSleep: lastSleep,
            isSleeping: isSleeping,
            now: now,
            count: scheduledCount
        )

        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "该哄睡了"
            content.body = bodyText(settings: settings, babyName: babyName)
            content.sound = .default
            content.userInfo = [
                "destination": BabyDiaryDestination.sleep.rawValue
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

    private static func bodyText(settings: SleepReminderSettings, babyName: String) -> String {
        "\(babyName) 已经清醒 \(settings.normalizedAwakeIntervalMinutes) 分钟"
    }
}

private enum ReminderTimeWindow {
    private static let minutesPerDay = 24 * 60

    static func contains(
        _ date: Date,
        startMinute: Int,
        endMinute: Int,
        calendar: Calendar = .current
    ) -> Bool {
        let start = FeedReminderSettings.clampedMinuteOfDay(startMinute)
        let end = FeedReminderSettings.clampedMinuteOfDay(endMinute)
        guard start != end else { return false }

        let minute = minuteOfDay(for: date, calendar: calendar)
        if start < end {
            return minute >= start && minute < end
        }
        return minute >= start || minute < end
    }

    static func nextAllowedDate(
        _ date: Date,
        startMinute: Int,
        endMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        guard contains(date, startMinute: startMinute, endMinute: endMinute, calendar: calendar) else {
            return date
        }

        let start = FeedReminderSettings.clampedMinuteOfDay(startMinute)
        let end = FeedReminderSettings.clampedMinuteOfDay(endMinute)
        let minute = minuteOfDay(for: date, calendar: calendar)
        let startOfDay = calendar.startOfDay(for: date)
        let dayOffset = start > end && minute >= start ? 1 : 0
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) ?? startOfDay
        return calendar.date(byAdding: .minute, value: end, to: targetDay) ?? date
    }

    private static func minuteOfDay(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return min(minutesPerDay - 1, max(0, hour * 60 + minute))
    }
}

extension Notification.Name {
    static let babyDiaryNotificationDestination = Notification.Name("BabyDiary.notificationDestination")
    static let babyDiaryShortcutDestination = Notification.Name("BabyDiary.shortcutDestination")
}
