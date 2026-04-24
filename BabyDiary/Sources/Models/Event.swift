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
}
