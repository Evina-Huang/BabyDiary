import Foundation

enum EventKind: String, Codable, CaseIterable, Hashable {
    case feed
    case diaper
    case sleep
    case solid

    var label: String {
        switch self {
        case .feed:   return "喂奶"
        case .diaper: return "换尿布"
        case .sleep:  return "睡眠"
        case .solid:  return "辅食"
        }
    }
}

enum DiaperEventType: String, Codable, CaseIterable, Hashable {
    case wet
    case dirty
    case both

    var label: String {
        switch self {
        case .wet: return "嘘嘘"
        case .dirty: return "臭臭"
        case .both: return "嘘嘘+臭臭"
        }
    }

    var subtitle: String {
        ""
    }

    var emoji: String {
        switch self {
        case .wet: return "💧"
        case .dirty: return "💩"
        case .both: return "💧💩"
        }
    }

    var allowsNote: Bool {
        self != .wet
    }

    static func from(title: String) -> Self {
        if title.contains("嘘嘘") || (title.contains("湿") && !title.contains("便")) {
            return title.contains("臭") ? .both : .wet
        }
        if title.contains("臭") || title == "便便" || (title.contains("便") && !title.contains("两")) {
            return .dirty
        }
        return .both
    }
}

enum DiaperNotePreset: String, CaseIterable, Hashable {
    case milkCurds = "奶瓣"
    case loose = "稀便"
    case watery = "水样便"
    case mucus = "有黏液"
    case green = "墨绿色"
    case dry = "偏干"

    static func options(including current: String?) -> [String] {
        let presets = Self.allCases.map(\.rawValue)
        guard let current else { return presets }

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !presets.contains(trimmed) else { return presets }
        return presets + [trimmed]
    }
}

enum BreastFeedSide: String, Codable, Hashable {
    case left
    case right
}

struct Event: Identifiable, Hashable, Codable {
    let id: String
    var kind: EventKind
    var at: Date
    var endAt: Date?
    var title: String
    var sub: String?

    init(
        id: String = "e" + UUID().uuidString.prefix(6).lowercased(),
        kind: EventKind,
        at: Date,
        endAt: Date? = nil,
        title: String,
        sub: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.at = at
        self.endAt = endAt
        self.title = title
        self.sub = sub
    }

    var duration: TimeInterval? {
        guard let endAt else { return nil }
        return endAt.timeIntervalSince(at)
    }

    var occurredAt: Date {
        if kind == .feed,
           let endAt,
           let correctedEndAt = correctedBreastFeedEndAt(endAt: endAt) {
            return correctedEndAt
        }
        return endAt ?? at
    }

    var startedAtForDisplay: Date {
        guard kind == .feed,
              let start = Self.timeRangeStart(in: sub, relativeTo: occurredAt) else {
            return at
        }
        return start
    }

    var isFormulaFeed: Bool {
        kind == .feed && (title.contains("奶粉") || title.contains("配方奶"))
    }

    var isBreastFeed: Bool {
        kind == .feed && title.contains("母乳")
    }

    var breastEndingSide: BreastFeedSide? {
        guard isBreastFeed else { return nil }

        if title.contains("双侧") {
            let leftIndex = sub?.range(of: "左", options: .backwards)?.lowerBound
            let rightIndex = sub?.range(of: "右", options: .backwards)?.lowerBound
            switch (leftIndex, rightIndex) {
            case let (.some(left), .some(right)):
                return left > right ? .left : .right
            case (.some, .none):
                return .left
            case (.none, .some):
                return .right
            default:
                return nil
            }
        }

        if title.contains("右侧") {
            return .right
        }
        if title.contains("左侧") {
            return .left
        }
        return nil
    }

    static let staleFeedTimerTolerance: TimeInterval = 60 * 60

    private func correctedBreastFeedEndAt(endAt: Date) -> Date? {
        guard let activeDuration = breastFeedDurationFromText, activeDuration > 0 else { return nil }
        let wallDuration = endAt.timeIntervalSince(at)
        guard wallDuration > activeDuration + Self.staleFeedTimerTolerance else { return endAt }
        return at.addingTimeInterval(activeDuration)
    }

    private var breastFeedDurationFromText: TimeInterval? {
        guard isBreastFeed else { return nil }
        if let totalMinutes = Self.firstCapturedInt(in: sub, pattern: #"共\s*(\d+)\s*分"#) {
            return TimeInterval(totalMinutes * 60)
        }
        if title.contains("双") {
            let left = Self.minutesAfter("左", in: sub) ?? 0
            let right = Self.minutesAfter("右", in: sub) ?? 0
            if left + right > 0 {
                return TimeInterval((left + right) * 60)
            }
        }
        if let minutes = Self.firstCapturedInt(in: sub, pattern: #"(\d+)\s*分"#) {
            return TimeInterval(minutes * 60)
        }
        return nil
    }

    private static func minutesAfter(_ marker: Character, in text: String?) -> Int? {
        guard let text, let idx = text.firstIndex(of: marker) else { return nil }
        let tail = text[text.index(after: idx)...]
        guard let match = tail.range(of: #"^\s*(\d+)\s*分"#, options: .regularExpression) else { return nil }
        let value = tail[match].filter { $0.isNumber }
        return Int(String(value))
    }

    private static func firstCapturedInt(in text: String?, pattern: String) -> Int? {
        guard let text else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[valueRange])
    }

    private static func timeRangeStart(in text: String?, relativeTo referenceDate: Date) -> Date? {
        guard let text else { return nil }
        let pattern = #"(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})"#
        let range = NSRange(text.startIndex..., in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges == 5,
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hour = Int(text[hourRange]),
              let minute = Int(text[minuteRange]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard var start = cal.date(from: components) else { return nil }
        if start > referenceDate.addingTimeInterval(60),
           let previousDay = cal.date(byAdding: .day, value: -1, to: start) {
            start = previousDay
        }
        return start
    }
}

func orderedBreastFeedSummary(
    leftMinutes: Int,
    rightMinutes: Int,
    firstSide: BreastFeedSide
) -> String {
    let total = leftMinutes + rightMinutes
    let first = firstSide == .left
        ? "左 \(leftMinutes)分 · 右 \(rightMinutes)分"
        : "右 \(rightMinutes)分 · 左 \(leftMinutes)分"
    return "\(first) · 共 \(total)分"
}
