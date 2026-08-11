import Foundation

enum VaccineStatus: String, Hashable {
    case done, due, overdue, upcoming
}

struct Vaccine: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var ageLabel: String       // "出生时" / "3 月龄"
    var ageMonths: Int         // 用于根据出生日期推算推荐日期
    var scheduledDate: Date?   // 用户自定义或推算出的计划接种日期
    var doneDate: Date?        // 实际接种日期
    var isCustom: Bool = false

    var done: Bool { doneDate != nil }

    func status(referenceDate: Date = Date()) -> VaccineStatus {
        if done { return .done }
        guard let d = scheduledDate else { return .upcoming }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: referenceDate),
                                      to: cal.startOfDay(for: d)).day ?? 0
        if days < 0 { return .overdue }
        if days <= 30 { return .due }
        return .upcoming
    }
}

struct VaccineTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let ageLabel: String
    let ageMonths: Int

    var familyName: String {
        if name.contains("卡介苗") { return "卡介苗" }
        if name.contains("乙肝") { return "乙肝疫苗" }
        if name.contains("脊灰") { return "脊灰疫苗" }
        if name.contains("百白破") || name.contains("白破") { return "百白破 / 白破疫苗" }
        if name.contains("A群流脑多糖") { return "A 群流脑多糖疫苗" }
        if name.contains("A+C群流脑多糖") { return "A+C 群流脑多糖疫苗" }
        if name.contains("B群流脑") { return "B 群流脑结合疫苗" }
        if name.contains("ACYW135") { return "ACYW135 群流脑疫苗" }
        if name.contains("乙脑") { return "乙脑疫苗" }
        if name.contains("麻腮风") { return "麻腮风疫苗" }
        if name.contains("甲肝") { return "甲肝疫苗" }
        if name.contains("轮状") { return "轮状病毒疫苗" }
        if name.contains("13价肺炎") { return "13价肺炎球菌疫苗" }
        if name.contains("Hib") { return "Hib 疫苗" }
        if name.contains("流感") { return "流感疫苗" }
        if name.contains("手足口") || name.contains("EV71") { return "EV71 手足口病疫苗" }
        if name.contains("水痘") { return "水痘疫苗" }
        if name.contains("HPV") { return "9价 HPV 疫苗" }
        if name.contains("狂犬") { return "狂犬疫苗" }
        return name
            .replacingOccurrences(of: " 首年第1剂", with: "")
            .replacingOccurrences(of: " 首年第2剂", with: "")
            .replacingOccurrences(of: " 第1剂", with: "")
            .replacingOccurrences(of: " 第2剂", with: "")
            .replacingOccurrences(of: " 第3剂", with: "")
            .replacingOccurrences(of: " 第4剂", with: "")
            .replacingOccurrences(of: " 加强", with: "")
    }

    var doseIndex: Int? {
        if name.contains("第1剂") { return 1 }
        if name.contains("第2剂") { return 2 }
        if name.contains("第3剂") { return 3 }
        if name.contains("第4剂") { return 4 }
        if name.contains("第5剂") { return 5 }
        return nil
    }

    var doseKindLabel: String? {
        if name.contains("加强") { return "加强" }
        if name.contains("首年") { return "首年" }
        return nil
    }

    var isProgramVaccine: Bool {
        VaccineCatalog.programTemplateIDs.contains(id)
    }

    var costLabel: String {
        isProgramVaccine ? "免费" : "自费"
    }
}

enum VaccineCatalog {
    static let programTemplateIDs: Set<String> = [
        "t_bcg", "t_hepb1", "t_hepb2", "t_ipv1", "t_ipv2", "t_dtp1",
        "t_dtp2", "t_bopv", "t_dtp3", "t_hepb3", "t_menA1", "t_menA2",
        "t_je1", "t_mmr1", "t_hepa", "t_dtp4", "t_mmr2", "t_je2",
        "t_menAC1", "t_ipv4", "t_dtp5", "t_menAC2"
    ]

    static let presets: [VaccineTemplate] = [
        // ===== 一类疫苗(免疫规划/免费) =====
        .init(id: "t_bcg",       name: "卡介苗 (BCG)",         ageLabel: "出生时",  ageMonths: 0),
        .init(id: "t_hepb1",     name: "乙肝疫苗 第1剂",       ageLabel: "出生时",  ageMonths: 0),
        .init(id: "t_hepb2",     name: "乙肝疫苗 第2剂",       ageLabel: "1 月龄",  ageMonths: 1),
        .init(id: "t_ipv1",      name: "脊灰灭活疫苗 第1剂",   ageLabel: "2 月龄",  ageMonths: 2),
        .init(id: "t_ipv2",      name: "脊灰灭活疫苗 第2剂",   ageLabel: "3 月龄",  ageMonths: 3),
        .init(id: "t_dtp1",      name: "百白破疫苗 第1剂",     ageLabel: "3 月龄",  ageMonths: 3),
        .init(id: "t_dtp2",      name: "百白破疫苗 第2剂",     ageLabel: "4 月龄",  ageMonths: 4),
        .init(id: "t_bopv",      name: "脊灰减毒活疫苗 (bOPV)", ageLabel: "4 月龄",  ageMonths: 4),
        .init(id: "t_dtp3",      name: "百白破疫苗 第3剂",     ageLabel: "5 月龄",  ageMonths: 5),
        .init(id: "t_hepb3",     name: "乙肝疫苗 第3剂",       ageLabel: "6 月龄",  ageMonths: 6),
        .init(id: "t_menA1",     name: "A群流脑多糖疫苗 第1剂", ageLabel: "6 月龄",  ageMonths: 6),
        .init(id: "t_menA2",     name: "A群流脑多糖疫苗 第2剂", ageLabel: "9 月龄",  ageMonths: 9),
        .init(id: "t_je1",       name: "乙脑减毒活疫苗 第1剂",  ageLabel: "8 月龄",  ageMonths: 8),
        .init(id: "t_mmr1",      name: "麻腮风疫苗 第1剂",     ageLabel: "8 月龄",  ageMonths: 8),
        .init(id: "t_hepa",      name: "甲肝减毒活疫苗",       ageLabel: "18 月龄", ageMonths: 18),
        .init(id: "t_dtp4",      name: "百白破疫苗 第4剂",     ageLabel: "18 月龄", ageMonths: 18),
        .init(id: "t_mmr2",      name: "麻腮风疫苗 第2剂",     ageLabel: "18 月龄", ageMonths: 18),
        .init(id: "t_je2",       name: "乙脑减毒活疫苗 第2剂",  ageLabel: "2 岁",    ageMonths: 24),
        .init(id: "t_menAC1",    name: "A+C群流脑多糖疫苗 第1剂", ageLabel: "3 岁", ageMonths: 36),
        .init(id: "t_ipv4",      name: "脊灰灭活疫苗 加强",    ageLabel: "4 岁",    ageMonths: 48),
        .init(id: "t_dtp5",      name: "白破疫苗 (DT) 加强",   ageLabel: "6 岁",    ageMonths: 72),
        .init(id: "t_menAC2",    name: "A+C群流脑多糖疫苗 第2剂", ageLabel: "6 岁", ageMonths: 72),

        // ===== 二类疫苗(自费,按需接种) =====
        .init(id: "t_rota",      name: "轮状病毒疫苗 第1剂",   ageLabel: "2 月龄",  ageMonths: 2),
        .init(id: "t_rota2",     name: "轮状病毒疫苗 第2剂",   ageLabel: "4 月龄",  ageMonths: 4),
        .init(id: "t_rota3",     name: "轮状病毒疫苗 第3剂",   ageLabel: "6 月龄",  ageMonths: 6),
        .init(id: "t_pcv13_1",   name: "13价肺炎球菌疫苗 第1剂", ageLabel: "2 月龄", ageMonths: 2),
        .init(id: "t_pcv13_2",   name: "13价肺炎球菌疫苗 第2剂", ageLabel: "4 月龄", ageMonths: 4),
        .init(id: "t_pcv13_3",   name: "13价肺炎球菌疫苗 第3剂", ageLabel: "6 月龄", ageMonths: 6),
        .init(id: "t_pcv13_4",   name: "13价肺炎球菌疫苗 加强",  ageLabel: "12 月龄", ageMonths: 12),
        .init(id: "t_hib1",      name: "Hib 疫苗 第1剂",      ageLabel: "2 月龄",  ageMonths: 2),
        .init(id: "t_hib2",      name: "Hib 疫苗 第2剂",      ageLabel: "4 月龄",  ageMonths: 4),
        .init(id: "t_hib3",      name: "Hib 疫苗 第3剂",      ageLabel: "6 月龄",  ageMonths: 6),
        .init(id: "t_hib4",      name: "Hib 疫苗 加强",       ageLabel: "18 月龄", ageMonths: 18),
        .init(id: "t_flu1",      name: "流感疫苗 首年第1剂",   ageLabel: "6 月龄",  ageMonths: 6),
        .init(id: "t_flu2",      name: "流感疫苗 首年第2剂",   ageLabel: "7 月龄",  ageMonths: 7),
        .init(id: "t_ev71_1",    name: "手足口 (EV71) 第1剂",  ageLabel: "6 月龄",  ageMonths: 6),
        .init(id: "t_ev71_2",    name: "手足口 (EV71) 第2剂",  ageLabel: "7 月龄",  ageMonths: 7),
        .init(id: "t_varicella1",name: "水痘疫苗 第1剂",       ageLabel: "12 月龄", ageMonths: 12),
        .init(id: "t_varicella2",name: "水痘疫苗 第2剂",       ageLabel: "4 岁",    ageMonths: 48),
        .init(id: "t_menB1",     name: "B群流脑结合疫苗 第1剂", ageLabel: "3 月龄",  ageMonths: 3),
        .init(id: "t_menB2",     name: "B群流脑结合疫苗 第2剂", ageLabel: "5 月龄",  ageMonths: 5),
        .init(id: "t_menACYW",   name: "ACYW135 群流脑疫苗",   ageLabel: "2 岁",    ageMonths: 24),
        .init(id: "t_hepa_inact",name: "甲肝灭活疫苗 加强",    ageLabel: "2 岁",    ageMonths: 24),
        .init(id: "t_je_inact",  name: "乙脑灭活疫苗",         ageLabel: "8 月龄",  ageMonths: 8),
        .init(id: "t_rabies",    name: "狂犬疫苗 (暴露后)",    ageLabel: "按需",    ageMonths: 0),
        .init(id: "t_hpv9",      name: "9价 HPV 疫苗",        ageLabel: "9 岁起",  ageMonths: 108),
    ]

    static var groupedPresets: [VaccineTemplateGroup] {
        let groups = Dictionary(grouping: presets, by: \.familyName)
        return groups.map { name, templates in
            VaccineTemplateGroup(
                id: normalizedFamilyID(name),
                name: name,
                templates: templates.sorted { a, b in
                    if a.ageMonths != b.ageMonths { return a.ageMonths < b.ageMonths }
                    return a.name < b.name
                }
            )
        }
        .sorted { a, b in
            let aMin = a.templates.map(\.ageMonths).min() ?? 0
            let bMin = b.templates.map(\.ageMonths).min() ?? 0
            if aMin != bMin { return aMin < bMin }
            return a.name < b.name
        }
    }

    private static func normalizedFamilyID(_ name: String) -> String {
        name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "plus")
            .replacingOccurrences(of: "价", with: "v")
    }
}

struct VaccineTemplateGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let templates: [VaccineTemplate]

    var ageRangeLabel: String {
        let months = templates.map(\.ageMonths)
        guard let min = months.min(), let max = months.max() else { return "按需" }
        if min == max { return vaccineAgeLabel(months: min) }
        return "\(vaccineAgeLabel(months: min))-\(vaccineAgeLabel(months: max))"
    }

    var costSummary: String {
        let labels = Set(templates.map(\.costLabel))
        if labels.count == 1 { return labels.first ?? "接种计划" }
        return "免费 / 自费"
    }
}

// 根据月龄生成展示文案
func vaccineAgeLabel(months: Int) -> String {
    if months <= 0 { return "出生时" }
    if months < 12 { return "\(months) 月龄" }
    let y = months / 12
    let m = months % 12
    return m == 0 ? "\(y) 岁" : "\(y) 岁 \(m) 月"
}
