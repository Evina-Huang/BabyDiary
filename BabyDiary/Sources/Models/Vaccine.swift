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
}

enum VaccineCatalog {
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
}

// 根据月龄生成展示文案
func vaccineAgeLabel(months: Int) -> String {
    if months <= 0 { return "出生时" }
    if months < 12 { return "\(months) 月龄" }
    let y = months / 12
    let m = months % 12
    return m == 0 ? "\(y) 岁" : "\(y) 岁 \(m) 月"
}
