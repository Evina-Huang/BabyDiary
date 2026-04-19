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

struct Event: Identifiable, Hashable {
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
