import Foundation

struct GrowthPoint: Identifiable, Hashable, Codable {
    let id: String
    var date: Date
    var ageMonths: Double
    var weightKg: Double
    var heightCm: Double
    var headCm: Double?
}

enum BabyGender: String, CaseIterable, Hashable, Codable {
    case girl, boy, unspecified
    var label: String {
        switch self {
        case .girl: return "女宝"
        case .boy:  return "男宝"
        case .unspecified: return "未设置"
        }
    }
}

struct Baby: Hashable, Codable {
    var name: String
    var birthDate: Date
    var gender: BabyGender = .unspecified
    var avatarData: Data? = nil

    var ageLabel: String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: birthDate, to: Date())
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        if y >= 1 {
            if m > 0 && d > 0 { return "\(y) 岁 \(m) 个月 \(d) 天" }
            if m > 0 { return "\(y) 岁 \(m) 个月" }
            return "\(y) 岁"
        }
        if m >= 1 { return d > 0 ? "\(m) 个月 \(d) 天" : "\(m) 个月" }
        return "\(max(d, 0)) 天"
    }

    var birthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日"
        return f.string(from: birthDate)
    }
}
