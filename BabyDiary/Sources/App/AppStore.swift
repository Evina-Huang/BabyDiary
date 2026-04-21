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
    var teeth: [ToothRecord] = ToothPosition.all.map(ToothRecord.empty(for:))
    var milestones: [Milestone] = []
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

    func addEvent(_ e: Event) {
        events.insert(e, at: 0)
        persist()
    }

    func deleteEvent(_ e: Event) {
        events.removeAll { $0.id == e.id }
        if e.kind == .solid {
            syncSolidFoods(named: Set(solidFoodNames(in: e)))
        }
        persist()
    }

    func updateEvent(_ e: Event) {
        guard let idx = events.firstIndex(where: { $0.id == e.id }) else { return }
        let original = events[idx]
        events[idx] = e
        if original.kind == .solid || e.kind == .solid {
            syncSolidFoods(named: Set(solidFoodNames(in: original) + solidFoodNames(in: e)))
        }
        persist()
    }

    func updateGrowth(_ g: GrowthPoint) {
        guard let idx = growth.firstIndex(where: { $0.id == g.id }) else { return }
        var updated = g
        updated.ageMonths = ageMonths(on: updated.date)
        growth[idx] = updated
        persist()
    }

    func ageMonths(on date: Date) -> Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: baby.birthDate)
        let end = cal.startOfDay(for: date)
        guard end > start else { return 0 }
        let comps = cal.dateComponents([.month, .day], from: start, to: end)
        let months = Double(comps.month ?? 0)
        let days = Double(comps.day ?? 0)
        return max(0, months + days / 30.0)
    }

    func startTimer(kind: EventKind, at date: Date = Date()) {
        activeTimer = RunningTimer(kind: kind, startedAt: date)
    }

    @discardableResult
    func stopTimer() -> RunningTimer? {
        let t = activeTimer
        activeTimer = nil
        return t
    }

    // MARK: — Vaccine plan management

    /// 备选模板中尚未加入用户计划的那些。
    var availableVaccineTemplates: [VaccineTemplate] {
        VaccineCatalog.presets.filter { t in !vaccines.contains { $0.id == t.id } }
    }

    func recommendedDate(forMonths months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: baby.birthDate) ?? baby.birthDate
    }

    func addVaccineFromTemplate(_ t: VaccineTemplate) {
        guard !vaccines.contains(where: { $0.id == t.id }) else { return }
        vaccines.append(Vaccine(
            id: t.id, name: t.name, ageLabel: t.ageLabel, ageMonths: t.ageMonths,
            scheduledDate: recommendedDate(forMonths: t.ageMonths),
            doneDate: nil, isCustom: false
        ))
        sortVaccines()
        persist()
    }

    func addCustomVaccine(name: String, ageMonths: Int, scheduledDate: Date?) {
        let id = "vc_" + UUID().uuidString.prefix(6).lowercased()
        vaccines.append(Vaccine(
            id: id, name: name, ageLabel: vaccineAgeLabel(months: ageMonths),
            ageMonths: ageMonths,
            scheduledDate: scheduledDate ?? recommendedDate(forMonths: ageMonths),
            doneDate: nil, isCustom: true
        ))
        sortVaccines()
        persist()
    }

    func updateVaccine(_ v: Vaccine) {
        guard let idx = vaccines.firstIndex(where: { $0.id == v.id }) else { return }
        vaccines[idx] = v
        sortVaccines()
        persist()
    }

    func removeVaccine(_ id: String) {
        vaccines.removeAll { $0.id == id }
        persist()
    }

    func toggleVaccine(_ id: String) {
        guard let idx = vaccines.firstIndex(where: { $0.id == id }) else { return }
        if vaccines[idx].done {
            vaccines[idx].doneDate = nil
        } else {
            vaccines[idx].doneDate = Date()
        }
        persist()
    }

    private func sortVaccines() {
        vaccines.sort { (a, b) in
            // 已完成放后面；按推荐日期/月龄排序
            if a.done != b.done { return !a.done && b.done }
            let ad = a.scheduledDate ?? Calendar.current.date(byAdding: .month, value: a.ageMonths, to: baby.birthDate) ?? Date()
            let bd = b.scheduledDate ?? Calendar.current.date(byAdding: .month, value: b.ageMonths, to: baby.birthDate) ?? Date()
            return ad < bd
        }
    }

    func addGrowth(_ g: GrowthPoint) {
        var newPoint = g
        newPoint.ageMonths = ageMonths(on: newPoint.date)
        growth.append(newPoint)
        persist()
    }

    // MARK: — Milestones

    func addMilestone(_ m: Milestone) { milestones.append(m); persist() }

    func updateMilestone(_ m: Milestone) {
        guard let idx = milestones.firstIndex(where: { $0.id == m.id }) else { return }
        milestones[idx] = m
        persist()
    }

    func deleteMilestone(_ id: String) {
        milestones.removeAll { $0.id == id }
        persist()
    }

    // MARK: — Teeth

    func tooth(at position: ToothPosition) -> ToothRecord {
        if let found = teeth.first(where: { $0.position == position }) { return found }
        return .empty(for: position)
    }

    func setTooth(_ position: ToothPosition, eruptedAt: Date?, note: String? = nil) {
        let id = ToothRecord.id(for: position)
        if let idx = teeth.firstIndex(where: { $0.id == id }) {
            teeth[idx].eruptedAt = eruptedAt
            teeth[idx].note = note
        } else {
            teeth.append(.init(id: id, position: position, eruptedAt: eruptedAt, note: note))
        }
        persist()
    }

    func recordSolidFood(_ name: String, at date: Date = .now, observationDays: Int = 3) {
        if let idx = foods.firstIndex(where: { $0.name == name }) {
            foods[idx].timesEaten += 1
            foods[idx].firstUsedAt = min(foods[idx].firstUsedAt, date)
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
        persist()
    }

    func updateFoodStatus(_ id: String, _ status: FoodStatus) {
        guard let idx = foods.firstIndex(where: { $0.id == id }) else { return }
        foods[idx].status = status
        persist()
    }

    func renameFood(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let idx = foods.firstIndex(where: { $0.id == id }) else { return }
        foods[idx].name = trimmed
        persist()
    }

    func deleteFood(_ id: String) {
        foods.removeAll { $0.id == id }
        persist()
    }

    private func solidFoodNames(in event: Event) -> [String] {
        guard event.kind == .solid else { return [] }
        let parts = event.title
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let names = parts.isEmpty
            ? [event.title.trimmingCharacters(in: .whitespacesAndNewlines)]
            : parts
        var seen: Set<String> = []
        return names.filter { seen.insert($0).inserted }
    }

    private func syncSolidFoods(named names: Set<String>) {
        for name in names where !name.isEmpty {
            syncSolidFood(named: name)
        }
    }

    private func syncSolidFood(named name: String) {
        let matches = events.filter {
            $0.kind == .solid && solidFoodNames(in: $0).contains(name)
        }
        guard let firstUsedAt = matches.map(\.at).min() else {
            foods.removeAll { $0.name == name }
            return
        }

        if let idx = foods.firstIndex(where: { $0.name == name }) {
            foods[idx].firstUsedAt = firstUsedAt
            foods[idx].timesEaten = matches.count
        } else {
            foods.append(FoodItem(
                id: "fd" + UUID().uuidString.prefix(6).lowercased(),
                name: name,
                firstUsedAt: firstUsedAt,
                status: .observing,
                timesEaten: matches.count,
                observationDays: 3
            ))
        }
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

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let ipv3  = cal.date(byAdding: .month, value: 4, to: baby.birthDate) ?? now
        let dtp3  = cal.date(byAdding: .month, value: 5, to: baby.birthDate) ?? now
        let mmr   = cal.date(byAdding: .month, value: 8, to: baby.birthDate) ?? now
        vaccines = [
            .init(id: "t_bcg",   name: "卡介苗 (BCG)",     ageLabel: "出生时", ageMonths: 0, scheduledDate: baby.birthDate,            doneDate: df.date(from: "2025-10-18")),
            .init(id: "t_hepb1", name: "乙肝疫苗 第1剂",   ageLabel: "出生时", ageMonths: 0, scheduledDate: baby.birthDate,            doneDate: df.date(from: "2025-10-18")),
            .init(id: "t_hepb2", name: "乙肝疫苗 第2剂",   ageLabel: "1 月龄", ageMonths: 1, scheduledDate: cal.date(byAdding: .month, value: 1, to: baby.birthDate), doneDate: df.date(from: "2025-11-20")),
            .init(id: "t_ipv1",  name: "脊灰疫苗 第1剂",   ageLabel: "2 月龄", ageMonths: 2, scheduledDate: cal.date(byAdding: .month, value: 2, to: baby.birthDate), doneDate: df.date(from: "2025-12-19")),
            .init(id: "t_dtp1",  name: "百白破疫苗 第1剂", ageLabel: "3 月龄", ageMonths: 3, scheduledDate: cal.date(byAdding: .month, value: 3, to: baby.birthDate), doneDate: df.date(from: "2026-01-20")),
            .init(id: "t_ipv3",  name: "脊灰疫苗 第3剂",   ageLabel: "4 月龄", ageMonths: 4, scheduledDate: ipv3, doneDate: nil),
            .init(id: "t_dtp3",  name: "百白破疫苗 第3剂", ageLabel: "5 月龄", ageMonths: 5, scheduledDate: dtp3, doneDate: nil),
            .init(id: "t_mmr",   name: "麻腮风疫苗",       ageLabel: "8 月龄", ageMonths: 8, scheduledDate: mmr,  doneDate: nil),
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

        milestones = [
            .init(id: "ms_smile", date: f.date(from: "2025-12-05")!,
                  title: "第一次笑出声",
                  note: "爸爸做鬼脸时突然咯咯笑，太可爱了。",
                  emoji: "😊", photoData: nil),
            .init(id: "ms_roll", date: f.date(from: "2026-02-22")!,
                  title: "第一次翻身",
                  note: "从仰卧翻到趴着，自己还吓了一跳。",
                  emoji: "🌀", photoData: nil),
            .init(id: "ms_mama", date: f.date(from: "2026-04-10")!,
                  title: "会叫\"妈妈\"",
                  note: nil,
                  emoji: "💞", photoData: nil),
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
    case sleep, feed, diaper, solid, vaccine, foodList, teeth, backup
    var id: String { rawValue }
}

enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case home, records, growth, health, stats
    var id: String { rawValue }
    var label: String {
        switch self {
        case .home:    return "首页"
        case .records: return "记录"
        case .growth:  return "成长"
        case .health:  return "健康"
        case .stats:   return "统计"
        }
    }
}
