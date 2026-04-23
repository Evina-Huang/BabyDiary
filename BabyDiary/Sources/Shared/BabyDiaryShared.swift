import ActivityKit
import Foundation

enum BabyDiaryDestination: String {
    case home
    case sleep
    case feed
    case records
}

enum BabyDiaryShared {
    static let appGroupIdentifier = "group.com.evina.BabyDiary"
    static let snapshotKey = "BabyDiaryWidgetSnapshot.v1"

    static func deepLink(_ destination: BabyDiaryDestination) -> URL? {
        URL(string: "babydiary://\(destination.rawValue)")
    }

    static func save(snapshot: BabyDiaryWidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupIdentifier)?.set(data, forKey: snapshotKey)
        UserDefaults.standard.set(data, forKey: snapshotKey)
    }

    static func loadSnapshot() -> BabyDiaryWidgetSnapshot {
        let data = UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: snapshotKey)
            ?? UserDefaults.standard.data(forKey: snapshotKey)
        guard let data else { return .empty }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(BabyDiaryWidgetSnapshot.self, from: data)) ?? .empty
    }
}

enum BabyDiaryWidgetEventKind: String, Codable, Hashable {
    case feed
    case diaper
    case sleep
    case solid
}

struct BabyDiaryWidgetEvent: Codable, Hashable {
    var kind: BabyDiaryWidgetEventKind
    var occurredAt: Date
    var startedAt: Date
    var endedAt: Date?
    var title: String
    var subtitle: String?
}

struct BabyDiaryWidgetSleepTimer: Codable, Hashable {
    var startedAt: Date
    var accumulated: TimeInterval
    var resumedAt: Date?

    var isRunning: Bool { resumedAt != nil }
}

struct BabyDiaryWidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var babyName: String
    var lastFeed: BabyDiaryWidgetEvent?
    var lastSleep: BabyDiaryWidgetEvent?
    var lastDiaper: BabyDiaryWidgetEvent?
    var activeSleep: BabyDiaryWidgetSleepTimer?

    static let empty = BabyDiaryWidgetSnapshot(
        updatedAt: .distantPast,
        babyName: "宝宝",
        lastFeed: nil,
        lastSleep: nil,
        lastDiaper: nil,
        activeSleep: nil
    )
}

struct BabyDiarySleepAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var accumulated: TimeInterval
        var resumedAt: Date?
        var updatedAt: Date

        var isRunning: Bool { resumedAt != nil }

        var timerReferenceDate: Date? {
            guard let resumedAt else { return nil }
            return resumedAt.addingTimeInterval(-accumulated)
        }

        func elapsed(at date: Date) -> TimeInterval {
            accumulated + (resumedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
        }
    }

    var babyName: String
}

enum BabyDiaryFeedMode: String, Codable, Hashable {
    case breast
    case formula
}

enum BabyDiaryFeedSide: String, Codable, Hashable {
    case left
    case right
}

struct BabyDiaryFeedAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mode: BabyDiaryFeedMode
        var startedAt: Date
        var accumulated: TimeInterval
        var resumedAt: Date?
        var updatedAt: Date
        var activeSide: BabyDiaryFeedSide?
        var breastLeftDuration: TimeInterval
        var breastRightDuration: TimeInterval
        var milliliters: Int?

        var isRunning: Bool { resumedAt != nil }

        var timerReferenceDate: Date? {
            guard let resumedAt else { return nil }
            return resumedAt.addingTimeInterval(-accumulated)
        }

        func elapsed(at date: Date) -> TimeInterval {
            accumulated + (resumedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
        }
    }

    var babyName: String
}
