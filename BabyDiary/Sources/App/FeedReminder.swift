import Foundation
import UserNotifications

enum FeedReminderMode: String, Codable, CaseIterable, Hashable {
    case interval
    case schedule

    var label: String {
        switch self {
        case .interval: return "固定间隔"
        case .schedule: return "作息表"
        }
    }
}

enum FeedReminderScheduleKind: String, Codable, CaseIterable, Hashable {
    case feed
    case solid

    var label: String {
        switch self {
        case .feed: return "喝奶"
        case .solid: return "辅食"
        }
    }

    var eventKind: EventKind {
        switch self {
        case .feed: return .feed
        case .solid: return .solid
        }
    }

    var destination: BabyDiaryDestination {
        switch self {
        case .feed: return .feed
        case .solid: return .solid
        }
    }

    var notificationTitle: String {
        switch self {
        case .feed: return "该喝奶了"
        case .solid: return "该吃辅食了"
        }
    }
}

struct FeedReminderScheduleEntry: Identifiable, Equatable, Codable, Hashable {
    var id: String
    var kind: FeedReminderScheduleKind
    var offsetMinutes: Int

    init(
        id: String = "schedule_" + UUID().uuidString.prefix(6).lowercased(),
        kind: FeedReminderScheduleKind,
        offsetMinutes: Int
    ) {
        self.id = id
        self.kind = kind
        self.offsetMinutes = offsetMinutes
    }
}

struct FeedReminderPlanItem: Equatable {
    var date: Date
    var kind: FeedReminderScheduleKind
    var entryID: String?
}

struct FeedReminderSettings: Equatable, Codable {
    static let minIntervalHours = 1
    static let maxIntervalHours = 8
    static let minScheduleOffsetMinutes = 0
    static let maxScheduleOffsetMinutes = 23 * 60 + 59
    static let scheduleOffsetStepMinutes = 15
    static let minScheduleEntries = 1
    static let maxScheduleEntries = 8
    static let defaultFirstFeedMinuteOfDay = 7 * 60
    static let defaultFirstFeedWindowStartMinuteOfDay = 5 * 60
    static let defaultFirstFeedWindowEndMinuteOfDay = 10 * 60
    static let defaultLatestReminderMinuteOfDay = 21 * 60
    static let maxScheduleDriftMinutes = 30

    static let defaultScheduleEntries: [FeedReminderScheduleEntry] = [
        .init(id: "feed_0700", kind: .feed, offsetMinutes: 7 * 60),
        .init(id: "solid_1000", kind: .solid, offsetMinutes: 10 * 60),
        .init(id: "feed_1300", kind: .feed, offsetMinutes: 13 * 60),
        .init(id: "solid_1600", kind: .solid, offsetMinutes: 16 * 60),
        .init(id: "feed_2000", kind: .feed, offsetMinutes: 20 * 60),
    ]

    var isEnabled: Bool = false
    var intervalHours: Int = 4
    var anchorAt: Date? = nil
    var quietHoursEnabled: Bool = false
    var quietStartMinuteOfDay: Int = 22 * 60
    var quietEndMinuteOfDay: Int = 7 * 60
    var mode: FeedReminderMode = .interval
    var defaultFirstFeedMinuteOfDay: Int = Self.defaultFirstFeedMinuteOfDay
    var firstFeedWindowStartMinuteOfDay: Int = Self.defaultFirstFeedWindowStartMinuteOfDay
    var firstFeedWindowEndMinuteOfDay: Int = Self.defaultFirstFeedWindowEndMinuteOfDay
    var latestReminderMinuteOfDay: Int = Self.defaultLatestReminderMinuteOfDay
    var scheduleEntries: [FeedReminderScheduleEntry] = Self.defaultScheduleEntries
    var scheduleUsesClockTimes: Bool = true

    init(
        isEnabled: Bool = false,
        intervalHours: Int = 4,
        anchorAt: Date? = nil,
        quietHoursEnabled: Bool = false,
        quietStartMinuteOfDay: Int = 22 * 60,
        quietEndMinuteOfDay: Int = 7 * 60,
        mode: FeedReminderMode = .interval,
        defaultFirstFeedMinuteOfDay: Int = Self.defaultFirstFeedMinuteOfDay,
        firstFeedWindowStartMinuteOfDay: Int = Self.defaultFirstFeedWindowStartMinuteOfDay,
        firstFeedWindowEndMinuteOfDay: Int = Self.defaultFirstFeedWindowEndMinuteOfDay,
        latestReminderMinuteOfDay: Int = Self.defaultLatestReminderMinuteOfDay,
        scheduleEntries: [FeedReminderScheduleEntry] = Self.defaultScheduleEntries
    ) {
        self.isEnabled = isEnabled
        self.intervalHours = intervalHours
        self.anchorAt = anchorAt
        self.quietHoursEnabled = quietHoursEnabled
        self.quietStartMinuteOfDay = quietStartMinuteOfDay
        self.quietEndMinuteOfDay = quietEndMinuteOfDay
        self.mode = mode
        self.defaultFirstFeedMinuteOfDay = defaultFirstFeedMinuteOfDay
        self.firstFeedWindowStartMinuteOfDay = firstFeedWindowStartMinuteOfDay
        self.firstFeedWindowEndMinuteOfDay = firstFeedWindowEndMinuteOfDay
        self.latestReminderMinuteOfDay = latestReminderMinuteOfDay
        self.scheduleEntries = scheduleEntries
        self.scheduleUsesClockTimes = true
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        intervalHours = try values.decodeIfPresent(Int.self, forKey: .intervalHours) ?? 4
        anchorAt = try values.decodeIfPresent(Date.self, forKey: .anchorAt)
        quietHoursEnabled = try values.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false
        quietStartMinuteOfDay = try values.decodeIfPresent(Int.self, forKey: .quietStartMinuteOfDay) ?? 22 * 60
        quietEndMinuteOfDay = try values.decodeIfPresent(Int.self, forKey: .quietEndMinuteOfDay) ?? 7 * 60
        mode = try values.decodeIfPresent(FeedReminderMode.self, forKey: .mode) ?? .interval
        defaultFirstFeedMinuteOfDay = try values.decodeIfPresent(
            Int.self,
            forKey: .defaultFirstFeedMinuteOfDay
        ) ?? Self.defaultFirstFeedMinuteOfDay
        firstFeedWindowStartMinuteOfDay = try values.decodeIfPresent(
            Int.self,
            forKey: .firstFeedWindowStartMinuteOfDay
        ) ?? Self.defaultFirstFeedWindowStartMinuteOfDay
        firstFeedWindowEndMinuteOfDay = try values.decodeIfPresent(
            Int.self,
            forKey: .firstFeedWindowEndMinuteOfDay
        ) ?? Self.defaultFirstFeedWindowEndMinuteOfDay
        latestReminderMinuteOfDay = try values.decodeIfPresent(
            Int.self,
            forKey: .latestReminderMinuteOfDay
        ) ?? Self.defaultLatestReminderMinuteOfDay
        let decodedScheduleEntries = try values.decodeIfPresent(
            [FeedReminderScheduleEntry].self,
            forKey: .scheduleEntries
        )
        let decodedScheduleUsesClockTimes = try values.decodeIfPresent(
            Bool.self,
            forKey: .scheduleUsesClockTimes
        )
        scheduleUsesClockTimes = true
        if let decodedScheduleEntries {
            scheduleEntries = decodedScheduleUsesClockTimes == true
                ? decodedScheduleEntries
                : Self.migratedScheduleEntriesFromLegacyOffsets(
                    decodedScheduleEntries,
                    firstFeedMinuteOfDay: defaultFirstFeedMinuteOfDay
                )
        } else {
            scheduleEntries = Self.defaultScheduleEntries
        }
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

    var normalizedDefaultFirstFeedMinuteOfDay: Int {
        Self.clampedMinuteOfDay(defaultFirstFeedMinuteOfDay)
    }

    var normalizedFirstFeedWindowStartMinuteOfDay: Int {
        Self.clampedMinuteOfDay(firstFeedWindowStartMinuteOfDay)
    }

    var normalizedFirstFeedWindowEndMinuteOfDay: Int {
        Self.clampedMinuteOfDay(firstFeedWindowEndMinuteOfDay)
    }

    var normalizedLatestReminderMinuteOfDay: Int {
        Self.clampedMinuteOfDay(latestReminderMinuteOfDay)
    }

    var normalizedScheduleEntries: [FeedReminderScheduleEntry] {
        let entries = scheduleEntries.isEmpty ? Self.defaultScheduleEntries : scheduleEntries
        return Array(entries
            .map { entry in
                var normalized = entry
                normalized.offsetMinutes = Self.clampedScheduleOffsetMinutes(entry.offsetMinutes)
                return normalized
            }
            .sorted { lhs, rhs in
                if lhs.offsetMinutes != rhs.offsetMinutes {
                    return lhs.offsetMinutes < rhs.offsetMinutes
                }
                if lhs.kind != rhs.kind {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.id < rhs.id
            }
            .prefix(Self.maxScheduleEntries))
    }

    static func clampedMinuteOfDay(_ minute: Int) -> Int {
        min(23 * 60 + 59, max(0, minute))
    }

    static func clampedScheduleOffsetMinutes(_ minute: Int) -> Int {
        min(maxScheduleOffsetMinutes, max(minScheduleOffsetMinutes, minute))
    }

    private static func migratedScheduleEntriesFromLegacyOffsets(
        _ entries: [FeedReminderScheduleEntry],
        firstFeedMinuteOfDay: Int
    ) -> [FeedReminderScheduleEntry] {
        let firstFeedMinute = clampedMinuteOfDay(firstFeedMinuteOfDay)
        return entries.map { entry in
            var migrated = entry
            migrated.offsetMinutes = clampedMinuteOfDay(firstFeedMinute + entry.offsetMinutes)
            return migrated
        }
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case intervalHours
        case anchorAt
        case quietHoursEnabled
        case quietStartMinuteOfDay
        case quietEndMinuteOfDay
        case mode
        case defaultFirstFeedMinuteOfDay
        case firstFeedWindowStartMinuteOfDay
        case firstFeedWindowEndMinuteOfDay
        case latestReminderMinuteOfDay
        case scheduleEntries
        case scheduleUsesClockTimes
    }
}

enum FeedReminderPlanner {
    static let fallbackDelay: TimeInterval = 60

    static func dueDate(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        now: Date = Date()
    ) -> Date? {
        dueDate(settings: settings, lastFeed: lastFeed, events: [], now: now)
    }

    static func dueDate(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        events: [Event],
        now: Date = Date()
    ) -> Date? {
        nextReminderItem(settings: settings, lastFeed: lastFeed, events: events, now: now)?.date
    }

    static func nextReminderItem(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        events: [Event],
        now: Date = Date()
    ) -> FeedReminderPlanItem? {
        guard settings.isEnabled else { return nil }
        switch settings.mode {
        case .interval:
            let anchor = lastFeed?.occurredAt ?? settings.anchorAt ?? now
            let rawDue = anchor.addingTimeInterval(settings.interval)
            return .init(date: nextAllowedDate(rawDue, settings: settings), kind: .feed, entryID: nil)
        case .schedule:
            return nextScheduleItem(settings: settings, events: events, now: now)
        }
    }

    static func scheduledDates(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        now: Date = Date(),
        count: Int = 12
    ) -> [Date] {
        scheduledDates(settings: settings, lastFeed: lastFeed, events: [], now: now, count: count)
    }

    static func scheduledDates(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        events: [Event],
        now: Date = Date(),
        count: Int = 12
    ) -> [Date] {
        scheduledItems(settings: settings, lastFeed: lastFeed, events: events, now: now, count: count)
            .map(\.date)
    }

    static func scheduledItems(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        events: [Event],
        now: Date = Date(),
        count: Int = 12
    ) -> [FeedReminderPlanItem] {
        guard settings.isEnabled, count > 0 else { return [] }
        switch settings.mode {
        case .interval:
            return intervalScheduledItems(settings: settings, lastFeed: lastFeed, now: now, count: count)
        case .schedule:
            return scheduleNotificationItems(settings: settings, events: events, now: now, count: count)
        }
    }

    private static func intervalScheduledItems(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        now: Date,
        count: Int
    ) -> [FeedReminderPlanItem] {
        let interval = settings.interval
        var candidate = dueDate(settings: settings, lastFeed: lastFeed, now: now) ?? now.addingTimeInterval(interval)
        if candidate <= now {
            candidate = nextAllowedDate(now.addingTimeInterval(fallbackDelay), settings: settings)
        }

        var items: [FeedReminderPlanItem] = []
        var attempts = 0
        while items.count < count && attempts < count * 8 {
            if candidate > now, items.last?.date != candidate {
                items.append(.init(date: candidate, kind: .feed, entryID: nil))
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
        return items
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

    private static func nextScheduleItem(
        settings: FeedReminderSettings,
        events: [Event],
        now: Date
    ) -> FeedReminderPlanItem? {
        scheduleCandidates(settings: settings, events: events, now: now, dayCount: 8)
            .first
            .map { .init(date: nextAllowedDate($0.date, settings: settings), kind: $0.kind, entryID: $0.entryID) }
    }

    private static func scheduleNotificationItems(
        settings: FeedReminderSettings,
        events: [Event],
        now: Date,
        count: Int
    ) -> [FeedReminderPlanItem] {
        let calendar = Calendar.current
        let candidates = scheduleCandidates(settings: settings, events: events, now: now, dayCount: count + 3)
        var items: [FeedReminderPlanItem] = []
        var addedOverdue = false

        for candidate in candidates {
            var date = nextAllowedDate(candidate.date, settings: settings)
            if date <= now {
                guard !addedOverdue,
                      let fallback = overdueFallbackDate(settings: settings, now: now, calendar: calendar) else {
                    continue
                }
                date = fallback
                addedOverdue = true
            }
            guard date > now, items.last?.date != date else { continue }
            items.append(.init(date: date, kind: candidate.kind, entryID: candidate.entryID))
            if items.count == count { break }
        }

        return items
    }

    private struct ScheduleCandidate {
        var date: Date
        var kind: FeedReminderScheduleKind
        var entryID: String
        var plannedDate: Date
    }

    private static func scheduleCandidates(
        settings: FeedReminderSettings,
        events: [Event],
        now: Date,
        dayCount: Int,
        calendar: Calendar = .current
    ) -> [ScheduleCandidate] {
        let startOfToday = calendar.startOfDay(for: now)
        let daysToScan = max(1, dayCount)
        var candidates: [ScheduleCandidate] = []

        for dayOffset in 0..<daysToScan {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let dayCandidates = rawScheduleCandidates(on: day, settings: settings, events: events, calendar: calendar)
            for (index, candidate) in dayCandidates.enumerated() {
                guard !shouldSkipExpiredScheduleCandidate(
                    candidate,
                    settings: settings,
                    now: now,
                    calendar: calendar
                ) else {
                    continue
                }
                guard !isCompleted(candidate, at: index, in: dayCandidates, events: events, calendar: calendar) else {
                    continue
                }
                candidates.append(candidate)
            }
        }

        return candidates.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.entryID < rhs.entryID
        }
    }

    private static func rawScheduleCandidates(
        on day: Date,
        settings: FeedReminderSettings,
        events: [Event],
        calendar: Calendar
    ) -> [ScheduleCandidate] {
        let dayStart = calendar.startOfDay(for: day)
        let latest = latestReminderDate(on: day, settings: settings, calendar: calendar)

        let candidates = settings.normalizedScheduleEntries.compactMap { entry -> ScheduleCandidate? in
            let raw = calendar.date(byAdding: .minute, value: entry.offsetMinutes, to: dayStart) ?? dayStart
            guard raw <= latest else { return nil }
            return ScheduleCandidate(date: raw, kind: entry.kind, entryID: entry.id, plannedDate: raw)
        }

        return scheduleCandidatesByCarryingFeedDrift(
            candidates,
            events: events,
            latest: latest,
            calendar: calendar
        )
    }

    private static func scheduleCandidatesByCarryingFeedDrift(
        _ candidates: [ScheduleCandidate],
        events: [Event],
        latest: Date,
        calendar: Calendar
    ) -> [ScheduleCandidate] {
        let maxDrift = TimeInterval(FeedReminderSettings.maxScheduleDriftMinutes * 60)
        guard maxDrift > 0 else { return candidates }

        let plannedCandidates = candidates
        var adjustedCandidates = candidates

        for index in adjustedCandidates.indices {
            guard adjustedCandidates[index].kind == .feed else { continue }
            guard let previousFeedIndex = plannedCandidates[..<index].lastIndex(where: { $0.kind == .feed }),
                  let previousFeed = latestFeedEvent(
                    after: plannedCandidates[previousFeedIndex].plannedDate,
                    before: plannedCandidates[index].plannedDate,
                    events: events
                  ) else {
                continue
            }

            let drift = previousFeed.startedAtForDisplay
                .timeIntervalSince(plannedCandidates[previousFeedIndex].plannedDate)
            if drift > 0 {
                let carriedDrift = min(drift, maxDrift)
                let adjustedDate = adjustedCandidates[index].plannedDate.addingTimeInterval(carriedDrift)
                adjustedCandidates[index].date = adjustedDate > latest ? latest : adjustedDate
            }
        }

        return adjustedCandidates.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.entryID < rhs.entryID
        }
    }

    private static func isCompleted(
        _ candidate: ScheduleCandidate,
        at index: Int,
        in candidates: [ScheduleCandidate],
        events: [Event],
        calendar: Calendar
    ) -> Bool {
        completedEvent(for: candidate, at: index, in: candidates, events: events, calendar: calendar) != nil
    }

    private static func completedEvent(
        for candidate: ScheduleCandidate,
        at index: Int,
        in candidates: [ScheduleCandidate],
        events: [Event],
        calendar: Calendar
    ) -> Event? {
        let dayStart = calendar.startOfDay(for: candidate.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? candidate.date
        let start = index > 0 ? midpoint(candidates[index - 1].date, candidate.date) : dayStart
        let end = index + 1 < candidates.count ? midpoint(candidate.date, candidates[index + 1].date) : dayEnd

        return events
            .filter { event in
                guard event.kind == candidate.kind.eventKind else { return false }
                let eventDate = event.kind == .feed ? event.startedAtForDisplay : event.at
                return eventDate >= start && eventDate < end
            }
            .max { lhs, rhs in
                let lhsDate = lhs.kind == .feed ? lhs.startedAtForDisplay : lhs.at
                let rhsDate = rhs.kind == .feed ? rhs.startedAtForDisplay : rhs.at
                return lhsDate < rhsDate
            }
    }

    private static func latestFeedEvent(after start: Date, before end: Date, events: [Event]) -> Event? {
        events
            .filter { event in
                guard event.kind == .feed else { return false }
                let eventDate = event.startedAtForDisplay
                return eventDate >= start && eventDate < end
            }
            .max { $0.startedAtForDisplay < $1.startedAtForDisplay }
    }

    private static func shouldSkipExpiredScheduleCandidate(
        _ candidate: ScheduleCandidate,
        settings: FeedReminderSettings,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard candidate.date <= now else { return false }
        return now > latestReminderDate(on: candidate.date, settings: settings, calendar: calendar)
    }

    private static func overdueFallbackDate(
        settings: FeedReminderSettings,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let latest = latestReminderDate(on: now, settings: settings, calendar: calendar)
        guard now < latest else { return nil }

        let rawFallback = now.addingTimeInterval(fallbackDelay)
        let cappedFallback = rawFallback > latest ? latest : rawFallback
        let allowedFallback = nextAllowedDate(cappedFallback, settings: settings)
        guard allowedFallback > now,
              !isPastLatestReminder(allowedFallback, settings: settings, calendar: calendar) else {
            return nil
        }
        return allowedFallback
    }

    private static func isPastLatestReminder(
        _ date: Date,
        settings: FeedReminderSettings,
        calendar: Calendar
    ) -> Bool {
        date > latestReminderDate(on: date, settings: settings, calendar: calendar)
    }

    private static func latestReminderDate(
        on day: Date,
        settings: FeedReminderSettings,
        calendar: Calendar
    ) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        return calendar.date(
            byAdding: .minute,
            value: settings.normalizedLatestReminderMinuteOfDay,
            to: dayStart
        ) ?? dayStart
    }

    private static func midpoint(_ lhs: Date, _ rhs: Date) -> Date {
        lhs.addingTimeInterval(rhs.timeIntervalSince(lhs) / 2)
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
        events: [Event],
        babyName: String,
        now: Date = Date()
    ) {
        Task {
            await syncAsync(settings: settings, lastFeed: lastFeed, events: events, babyName: babyName, now: now)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
    }

    private static func syncAsync(
        settings: FeedReminderSettings,
        lastFeed: Event?,
        events: [Event],
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

        let items = FeedReminderPlanner.scheduledItems(
            settings: settings,
            lastFeed: lastFeed,
            events: events,
            now: now,
            count: scheduledCount
        )

        for (index, item) in items.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = item.kind.notificationTitle
            content.body = bodyText(settings: settings, item: item, babyName: babyName)
            content.sound = UNNotificationSound(named: UNNotificationSoundName("bubble.caf"))
            content.userInfo = [
                "destination": item.kind.destination.rawValue
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: item.date
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

    private static func bodyText(settings: FeedReminderSettings, item: FeedReminderPlanItem, babyName: String) -> String {
        switch settings.mode {
        case .interval:
            return "\(babyName) 距离上次喂奶已经 \(settings.normalizedIntervalHours) 小时"
        case .schedule:
            switch item.kind {
            case .feed:
                return "\(babyName) 今天的喝奶时间到了"
            case .solid:
                return "\(babyName) 今天的辅食时间到了"
            }
        }
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
            content.sound = UNNotificationSound(named: UNNotificationSoundName("bubble.caf"))
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
