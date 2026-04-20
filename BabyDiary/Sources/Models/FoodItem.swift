import Foundation

enum FoodStatus: String, Codable, Hashable {
    case observing  // 观察中
    case safe       // 安全
    case allergic   // 过敏
}

struct FoodItem: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var firstUsedAt: Date
    var status: FoodStatus
    var timesEaten: Int
    var observationDays: Int
    var notes: String?

    var observationEndAt: Date {
        Calendar.current.date(byAdding: .day, value: observationDays, to: firstUsedAt)!
    }

    // Ceiling of remaining hours / 24 — shows "1 天" until the exact moment it expires.
    var daysRemaining: Int {
        let secs = max(0, observationEndAt.timeIntervalSinceNow)
        return Int(ceil(secs / 86400))
    }

    var isObservationDue: Bool {
        status == .observing && Date() >= observationEndAt
    }
}
