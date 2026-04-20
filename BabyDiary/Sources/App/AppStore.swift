import SwiftUI
import Observation

@Observable
final class AppStore {
    var baby = Baby(
        name: "小宝",
        birthDate: Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 18)) ?? Date(),
        gender: .girl
    )
    var events: [Event] = []
    var vaccines: [Vaccine] = []
    var growth: [GrowthPoint] = []
    var foods: [FoodItem] = []
    var theme: AppTheme = .blossom
    var activeTimer: RunningTimer? = nil

    init() { seed() }

    static let preview: AppStore = {
        let s = AppStore()
        // Trim down to just enough data for canvas rendering
        s.events  = Array(s.events.prefix(4))
        s.vaccines = Array(s.vaccines.prefix(3))
        s.growth   = Array(s.growth.suffix(2))
        return s
    }()

    func addEvent(_ e: Event) { events.insert(e, at: 0) }
    func deleteEvent(_ e: Event) { events.removeAll { $0.id == e.id } }

    func startTimer(kind: EventKind, at date: Date = Date()) {
        activeTimer = RunningTimer(kind: kind, startedAt: date)
    }

    @discardableResult
    func stopTimer() -> RunningTimer? {
        let t = activeTimer
        activeTimer = nil
        return t
    }

    func toggleVaccine(_ id: String) {
        guard let idx = vaccines.firstIndex(where: { $0.id == id }) else { return }
        var v = vaccines[idx]
        v.done.toggle()
        if v.done {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            v.doneDate = f.string(from: Date())
            v.status = .done
        } else {
            v.doneDate = nil
            v.status = .due
        }
        vaccines[idx] = v
    }

    func addGrowth(_ g: GrowthPoint) { growth.append(g) }

    func recordSolidFood(_ name: String, at date: Date = .now, observationDays: Int = 3) {
        if let idx = foods.firstIndex(where: { $0.name == name }) {
            foods[idx].timesEaten += 1
        } else {
            foods.append(FoodItem(
                id: "fd" + UUID().uuidString.prefix(6).lowercased(),
                name: name,
                firstUsedAt: date,
                status: .observing,
                timesEaten: 1,
                observationDays: observationDays
            ))
        }
    }

    func updateFoodStatus(_ id: String, _ status: FoodStatus) {
        guard let idx = foods.firstIndex(where: { $0.id == id }) else { return }
        foods[idx].status = status
    }

    private func seed() {
        let cal = Calendar.current
        let now = Date()
        func at(_ hOff: Int, _ mOff: Int = 0) -> Date {
            cal.date(byAdding: .minute, value: -(hOff * 60 + mOff), to: now)!
        }
        func daysAgo(_ n: Int, _ h: Int, _ m: Int = 0) -> Date {
            var d = cal.date(byAdding: .day, value: -n, to: now)!
            d = cal.date(bySettingHour: h, minute: m, second: 0, of: d)!
            return d
        }

        events = [
            .init(id: "e1",  kind: .feed,   at: at(1, 15), title: "母乳 · 左侧", sub: "18 分钟"),
            .init(id: "e2",  kind: .diaper, at: at(2, 5),  title: "湿尿布", sub: "只有尿"),
            .init(id: "e3",  kind: .sleep,  at: at(4, 30), endAt: at(2, 45), title: "睡眠 1h 45分钟", sub: nil),
            .init(id: "e4",  kind: .solid,  at: at(5, 0),  title: "南瓜泥", sub: "50g · 第一次吃"),
            .init(id: "e5",  kind: .feed,   at: at(6, 20), title: "奶粉", sub: "120 ml"),
            .init(id: "e6",  kind: .diaper, at: at(7, 40), title: "两者都有", sub: "湿 + 便便"),
            .init(id: "e7",  kind: .sleep,  at: daysAgo(1, 22), endAt: daysAgo(0, 6, 30), title: "睡眠 8h 30m", sub: "22:00 — 06:30"),
            .init(id: "e8",  kind: .feed,   at: daysAgo(1, 14), title: "母乳 · 右侧", sub: "22 分钟"),
            .init(id: "e9",  kind: .solid,  at: daysAgo(1, 12), title: "米糊", sub: "30g"),
            .init(id: "e10", kind: .diaper, at: daysAgo(1, 9),  title: "湿尿布", sub: "只有尿"),
            .init(id: "e11", kind: .feed,   at: daysAgo(2, 8),  title: "奶粉", sub: "150 ml"),
            .init(id: "e12", kind: .sleep,  at: daysAgo(2, 13), endAt: daysAgo(2, 15), title: "睡眠 2h", sub: "13:00 — 15:00"),
        ]

        vaccines = [
            .init(id: "v1",  name: "卡介苗 (BCG)",       age: "出生时",  status: .done,     done: true,  doneDate: "2025-10-18"),
            .init(id: "v2",  name: "乙肝疫苗 第1剂",     age: "出生时",  status: .done,     done: true,  doneDate: "2025-10-18"),
            .init(id: "v3",  name: "乙肝疫苗 第2剂",     age: "1 月龄",  status: .done,     done: true,  doneDate: "2025-11-20"),
            .init(id: "v4",  name: "脊灰疫苗 第1剂",     age: "2 月龄",  status: .done,     done: true,  doneDate: "2025-12-19"),
            .init(id: "v5",  name: "脊灰疫苗 第2剂",     age: "3 月龄",  status: .done,     done: true,  doneDate: "2026-01-20"),
            .init(id: "v6",  name: "百白破疫苗 第1剂",   age: "3 月龄",  status: .done,     done: true,  doneDate: "2026-01-20"),
            .init(id: "v7",  name: "百白破疫苗 第2剂",   age: "4 月龄",  status: .done,     done: true,  doneDate: "2026-02-18"),
            .init(id: "v8",  name: "脊灰疫苗 第3剂",     age: "4 月龄",  status: .overdue,  done: false),
            .init(id: "v9",  name: "百白破疫苗 第3剂",   age: "5 月龄",  status: .due,      done: false),
            .init(id: "v10", name: "麻腮风疫苗",         age: "8 月龄",  status: .upcoming, done: false),
            .init(id: "v11", name: "乙脑疫苗",           age: "8 月龄",  status: .upcoming, done: false),
            .init(id: "v12", name: "甲肝疫苗",           age: "18 月龄", status: .upcoming, done: false),
        ]

        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"

        // Foods: 3 safe, 1 allergic, 3 observing (incl. 1 expired → shows confirm prompt)
        foods = [
            .init(id: "fd1", name: "南瓜泥", firstUsedAt: at(5, 0),         status: .observing, timesEaten: 1, observationDays: 3),
            .init(id: "fd2", name: "胡萝卜", firstUsedAt: daysAgo(2, 9),    status: .observing, timesEaten: 2, observationDays: 3),
            .init(id: "fd3", name: "豌豆泥", firstUsedAt: daysAgo(4, 10),   status: .observing, timesEaten: 3, observationDays: 5),
            .init(id: "fd4", name: "米糊",   firstUsedAt: f.date(from: "2026-03-01")!, status: .safe,     timesEaten: 12, observationDays: 3),
            .init(id: "fd5", name: "苹果泥", firstUsedAt: f.date(from: "2026-03-10")!, status: .safe,     timesEaten: 8,  observationDays: 3),
            .init(id: "fd6", name: "香蕉",   firstUsedAt: f.date(from: "2026-03-20")!, status: .safe,     timesEaten: 6,  observationDays: 3),
            .init(id: "fd7", name: "鸡蛋黄", firstUsedAt: f.date(from: "2026-02-10")!, status: .allergic, timesEaten: 2,  observationDays: 7),
        ]

        growth = [
            .init(id: "g1", date: f.date(from: "2025-10-18")!, ageMonths: 0, weightKg: 3.2, heightCm: 50.0, headCm: nil),
            .init(id: "g2", date: f.date(from: "2025-11-18")!, ageMonths: 1, weightKg: 4.3, heightCm: 54.5, headCm: nil),
            .init(id: "g3", date: f.date(from: "2025-12-18")!, ageMonths: 2, weightKg: 5.5, heightCm: 58.2, headCm: nil),
            .init(id: "g4", date: f.date(from: "2026-01-18")!, ageMonths: 3, weightKg: 6.5, heightCm: 61.0, headCm: nil),
            .init(id: "g5", date: f.date(from: "2026-02-18")!, ageMonths: 4, weightKg: 7.2, heightCm: 63.8, headCm: nil),
            .init(id: "g6", date: f.date(from: "2026-03-18")!, ageMonths: 5, weightKg: 7.7, heightCm: 66.2, headCm: nil),
            .init(id: "g7", date: f.date(from: "2026-04-15")!, ageMonths: 6, weightKg: 8.1, heightCm: 68.0, headCm: nil),
        ]
    }
}

// Sub-screens launched from the Home screen as iOS sheets.
// Represents an in-progress, user-initiated timer (sleep today; feed later).
// Modeled so a future Live Activity / Widget can serialize exactly this shape.
struct RunningTimer: Equatable, Codable {
    let kind: EventKind
    let startedAt: Date
}

enum SubScreen: String, Identifiable {
    case sleep, feed, diaper, solid, vaccine, foodList
    var id: String { rawValue }
}

enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case home, records, growth, stats
    var id: String { rawValue }
    var label: String {
        switch self {
        case .home:    return "首页"
        case .records: return "记录"
        case .growth:  return "成长"
        case .stats:   return "统计"
        }
    }
}
