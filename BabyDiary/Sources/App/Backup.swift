import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: — Snapshot

struct DataSnapshot: Codable {
    var version: Int = 3
    var exportedAt: Date = Date()
    var baby: Baby
    var events: [Event]
    var vaccines: [Vaccine]
    var growth: [GrowthPoint]
    var foods: [FoodItem]
    var medications: [MedicationRecord]? = nil
    var teeth: [ToothRecord]? = nil
    var milestones: [Milestone]? = nil
    var activeTimer: RunningTimer? = nil
    var feedDraft: FeedDraft? = nil

    init(
        version: Int = 3,
        exportedAt: Date = Date(),
        baby: Baby,
        events: [Event],
        vaccines: [Vaccine],
        growth: [GrowthPoint],
        foods: [FoodItem],
        medications: [MedicationRecord]? = nil,
        teeth: [ToothRecord]? = nil,
        milestones: [Milestone]? = nil,
        activeTimer: RunningTimer? = nil,
        feedDraft: FeedDraft? = nil
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.baby = baby
        self.events = events
        self.vaccines = vaccines
        self.growth = growth
        self.foods = foods
        self.medications = medications
        self.teeth = teeth
        self.milestones = milestones
        self.activeTimer = activeTimer
        self.feedDraft = feedDraft
    }

    init(
        version: Int = 3,
        exportedAt: Date = Date(),
        baby: Baby,
        events: [Event],
        vaccines: [Vaccine],
        growth: [GrowthPoint],
        foods: [FoodItem],
        teeth: [ToothRecord]? = nil,
        milestones: [Milestone]? = nil
    ) {
        self.init(
            version: version,
            exportedAt: exportedAt,
            baby: baby,
            events: events,
            vaccines: vaccines,
            growth: growth,
            foods: foods,
            medications: nil,
            teeth: teeth,
            milestones: milestones,
            activeTimer: nil,
            feedDraft: nil
        )
    }
}

// MARK: — Persistence + export on AppStore

extension AppStore {
    private static let storeFileName = "BabyDiary.json"
    private static let recoveryFileName = "BabyDiary.previous.json"

    static var persistenceDirectoryURL: URL = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]

    static var storeURL: URL {
        persistenceDirectoryURL.appendingPathComponent(storeFileName)
    }

    static var recoveryURL: URL {
        persistenceDirectoryURL.appendingPathComponent(recoveryFileName)
    }

    /// Returns a store populated from disk if a backup exists,
    /// otherwise the seeded demo data from `init()`.
    static func loadedOrSeeded() -> AppStore {
        let s = AppStore()
        _ = s.loadFromDisk()
        return s
    }

    func snapshot() -> DataSnapshot {
        DataSnapshot(baby: baby, events: events, vaccines: vaccines,
                     growth: growth, foods: foods, medications: medications,
                     teeth: teeth,
                     milestones: milestones, activeTimer: activeTimer,
                     feedDraft: feedDraft)
    }

    func apply(_ snap: DataSnapshot) {
        baby = snap.baby
        events = snap.events
        vaccines = snap.vaccines
        growth = snap.growth
        foods = snap.foods
        medications = snap.medications ?? []
        // 按位置合并,保证 20 颗位置齐全;老备份无 teeth 字段时回退为空记录
        milestones = snap.milestones ?? []
        if let saved = snap.teeth {
            let byId = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            teeth = ToothPosition.all.map { p in
                byId[ToothRecord.id(for: p)] ?? .empty(for: p)
            }
        } else {
            teeth = ToothPosition.all.map(ToothRecord.empty(for:))
        }
        activeTimer = snap.activeTimer
        feedDraft = snap.feedDraft
    }

    @discardableResult
    func loadFromDisk() -> Bool {
        if let snap = Self.loadSnapshot(at: Self.storeURL) {
            apply(snap)
            return true
        }
        guard let snap = Self.loadSnapshot(at: Self.recoveryURL) else { return false }
        apply(snap)
        persist(makeRecoveryCopy: false)
        return true
    }

    func persist(makeRecoveryCopy: Bool = true) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(snapshot()) else { return }
        let fileManager = FileManager.default
        if makeRecoveryCopy, fileManager.fileExists(atPath: Self.storeURL.path) {
            try? fileManager.removeItem(at: Self.recoveryURL)
            try? fileManager.copyItem(at: Self.storeURL, to: Self.recoveryURL)
        }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    func lastSavedAt() -> Date? {
        guard FileManager.default.fileExists(atPath: Self.storeURL.path) else { return nil }
        let values = try? Self.storeURL.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    // MARK: — Exports

    /// Writes a JSON backup file to a temp URL and returns it.
    func exportJSON() throws -> URL {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(snapshot())
        let name = "BabyDiary-\(Self.dateStamp()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Import from a JSON file URL. Throws on decode failure.
    func importJSON(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let snap = try Self.decodeSnapshot(from: data)
        apply(snap)
        persist()
    }

    func exportPDF() throws -> URL {
        let data = PDFBuilder.render(snapshot: snapshot())
        let name = "BabyDiary-\(Self.dateStamp()).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func decodeSnapshot(from data: Data) throws -> DataSnapshot {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(DataSnapshot.self, from: data)
    }

    private static func loadSnapshot(at url: URL) -> DataSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decodeSnapshot(from: data)
    }
}

// MARK: — PDF rendering

enum PDFBuilder {
    // A4
    private static let pageW: CGFloat = 595
    private static let pageH: CGFloat = 842
    private static let margin: CGFloat = 40

    static func render(snapshot snap: DataSnapshot) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let meta = [
            kCGPDFContextTitle as String: "宝宝日记 数据备份",
            kCGPDFContextAuthor as String: "BabyDiary"
        ]
        let fmt = UIGraphicsPDFRendererFormat()
        fmt.documentInfo = meta
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: fmt)

        return renderer.pdfData { ctx in
            var cursor = Cursor(context: ctx, pageBounds: bounds, margin: margin)
            cursor.beginPage()
            drawCover(&cursor, snap: snap)
            drawGrowth(&cursor, snap: snap)
            drawVaccines(&cursor, snap: snap)
            drawMedications(&cursor, snap: snap)
            drawFoods(&cursor, snap: snap)
            drawEvents(&cursor, snap: snap)
        }
    }

    // MARK: sections

    private static func drawCover(_ c: inout Cursor, snap: DataSnapshot) {
        c.text("宝宝日记 · 数据备份", size: 24, weight: .heavy, color: .black)
        c.gap(6)
        c.text("导出时间  \(longDate(snap.exportedAt))", size: 12, color: .darkGray)
        c.gap(20)

        c.kv("宝宝姓名", snap.baby.name)
        c.kv("性别", snap.baby.gender.label)
        c.kv("出生日期", snap.baby.birthLabel)
        c.kv("当前年龄", snap.baby.ageLabel)
        c.gap(16)

        c.text("数据概览", size: 14, weight: .bold)
        c.gap(4)
        c.kv("日常记录", "\(snap.events.count) 条")
        c.kv("疫苗计划", "\(snap.vaccines.count) 项 · 已完成 \(snap.vaccines.filter { $0.done }.count)")
        c.kv("成长曲线", "\(snap.growth.count) 个测量点")
        c.kv("辅食记录", "\(snap.foods.count) 种食物")
        let meds = snap.medications ?? []
        c.kv("用药记录", "\(meds.count) 条 · 疑似过敏 \(meds.filter { $0.reaction == .allergic }.count)")
        c.gap(10)
    }

    private static func drawGrowth(_ c: inout Cursor, snap: DataSnapshot) {
        c.sectionTitle("成长曲线")
        guard !snap.growth.isEmpty else { c.text("（暂无数据）", size: 11, color: .gray); c.gap(12); return }
        let rows = snap.growth.sorted { $0.date < $1.date }.map {
            [shortDate($0.date), fmtMonths($0.ageMonths),
             String(format: "%.2f kg", $0.weightKg),
             String(format: "%.1f cm", $0.heightCm),
             $0.headCm.map { String(format: "%.1f cm", $0) } ?? "-"]
        }
        c.table(headers: ["日期", "月龄", "体重", "身高", "头围"],
                widths: [90, 70, 90, 90, 90], rows: rows)
        c.gap(12)
    }

    private static func drawVaccines(_ c: inout Cursor, snap: DataSnapshot) {
        c.sectionTitle("疫苗接种")
        guard !snap.vaccines.isEmpty else { c.text("（暂无数据）", size: 11, color: .gray); c.gap(12); return }
        let rows = snap.vaccines.map { v -> [String] in
            let scheduled = v.scheduledDate.map(shortDate) ?? "-"
            let done = v.doneDate.map(shortDate) ?? "-"
            let status = v.done ? "✓ 已完成" : "待接种"
            return [v.name, v.ageLabel, scheduled, done, status]
        }
        c.table(headers: ["疫苗", "适龄", "计划日期", "接种日期", "状态"],
                widths: [160, 70, 85, 85, 70], rows: rows)
        c.gap(12)
    }

    private static func drawMedications(_ c: inout Cursor, snap: DataSnapshot) {
        c.sectionTitle("用药记录")
        let meds = snap.medications ?? []
        guard !meds.isEmpty else { c.text("（暂无数据）", size: 11, color: .gray); c.gap(12); return }
        let rows = meds.sorted { $0.takenAt > $1.takenAt }.map { m -> [String] in
            let reaction: String = {
                var label = m.reaction.label
                if let note = m.reactionNote, !note.isEmpty {
                    label += " · \(note)"
                }
                return label
            }()
            return [
                "\(shortDate(m.takenAt)) \(hm(m.takenAt))",
                m.name,
                m.dose.isEmpty ? "-" : m.dose,
                m.reason.isEmpty ? "-" : m.reason,
                reaction
            ]
        }
        c.table(headers: ["时间", "药名", "剂量", "用途", "过敏反应"],
                widths: [110, 115, 70, 95, 130], rows: rows)
        c.gap(12)
    }

    private static func drawFoods(_ c: inout Cursor, snap: DataSnapshot) {
        c.sectionTitle("辅食与过敏")
        guard !snap.foods.isEmpty else { c.text("（暂无数据）", size: 11, color: .gray); c.gap(12); return }
        let rows = snap.foods.map { f -> [String] in
            let status: String = {
                switch f.status {
                case .safe: return "安全"
                case .observing: return "观察中"
                case .allergic: return "⚠ 过敏"
                }
            }()
            return [f.name, shortDate(f.firstUsedAt), "\(f.timesEaten) 次",
                    "\(f.observationDays) 天", status]
        }
        c.table(headers: ["食物", "首次尝试", "次数", "观察期", "状态"],
                widths: [130, 100, 70, 80, 90], rows: rows)
        c.gap(12)
    }

    private static func drawEvents(_ c: inout Cursor, snap: DataSnapshot) {
        c.sectionTitle("日常记录")
        guard !snap.events.isEmpty else { c.text("（暂无数据）", size: 11, color: .gray); return }

        let cal = Calendar.current
        let grouped = Dictionary(grouping: snap.events) { cal.startOfDay(for: $0.at) }
        let days = grouped.keys.sorted(by: >)

        for day in days {
            c.ensure(height: 60)
            c.text(longDate(day), size: 13, weight: .bold, color: .black)
            c.gap(2)
            let rows = (grouped[day] ?? []).sorted { $0.at > $1.at }.map { e -> [String] in
                [hm(e.at), e.kind.label, e.title, e.sub ?? ""]
            }
            c.table(headers: ["时间", "类型", "内容", "备注"],
                    widths: [60, 60, 200, 195], rows: rows,
                    headerColor: UIColor(white: 0.95, alpha: 1))
            c.gap(10)
        }
    }

    // MARK: formatters

    private static func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }
    private static func longDate(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 EEEE"; return f.string(from: d)
    }
    private static func hm(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    private static func fmtMonths(_ m: Double) -> String {
        m.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(m)) 月"
            : String(format: "%.1f 月", m)
    }
}

// A lightweight cursor that flows content across multiple A4 pages.
private struct Cursor {
    let context: UIGraphicsPDFRendererContext
    let pageBounds: CGRect
    let margin: CGFloat
    var y: CGFloat = 0
    private var pageStarted = false

    init(context: UIGraphicsPDFRendererContext, pageBounds: CGRect, margin: CGFloat) {
        self.context = context
        self.pageBounds = pageBounds
        self.margin = margin
        self.y = margin
    }

    var contentWidth: CGFloat { pageBounds.width - margin * 2 }
    var maxY: CGFloat { pageBounds.height - margin }

    mutating func beginPage() {
        context.beginPage()
        pageStarted = true
        y = margin
    }

    mutating func ensure(height: CGFloat) {
        if y + height > maxY {
            context.beginPage()
            y = margin
        }
    }

    mutating func gap(_ h: CGFloat) { y += h }

    mutating func text(_ s: String, size: CGFloat, weight: UIFont.Weight = .regular,
                       color: UIColor = .black) {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color
        ]
        let ns = NSAttributedString(string: s, attributes: attrs)
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: .greatestFiniteMagnitude)
        let bounding = ns.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                       options: [.usesLineFragmentOrigin], context: nil)
        ensure(height: bounding.height)
        ns.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: bounding.height),
                options: [.usesLineFragmentOrigin], context: nil)
        _ = rect
        y += bounding.height
    }

    mutating func sectionTitle(_ s: String) {
        gap(6)
        ensure(height: 30)
        let stripe = CGRect(x: margin, y: y + 2, width: 4, height: 18)
        UIColor.systemBlue.setFill()
        UIBezierPath(roundedRect: stripe, cornerRadius: 2).fill()
        let font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        NSAttributedString(string: s, attributes: attrs)
            .draw(at: CGPoint(x: margin + 12, y: y))
        y += 24
        let line = CGRect(x: margin, y: y, width: contentWidth, height: 0.5)
        UIColor(white: 0.85, alpha: 1).setFill()
        UIRectFill(line)
        y += 6
    }

    mutating func kv(_ k: String, _ v: String) {
        let keyFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let valFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        ensure(height: 18)
        NSAttributedString(string: k, attributes: [.font: keyFont, .foregroundColor: UIColor.gray])
            .draw(at: CGPoint(x: margin, y: y))
        NSAttributedString(string: v, attributes: [.font: valFont, .foregroundColor: UIColor.black])
            .draw(at: CGPoint(x: margin + 80, y: y - 1))
        y += 18
    }

    mutating func table(headers: [String], widths: [CGFloat], rows: [[String]],
                        headerColor: UIColor = UIColor(white: 0.93, alpha: 1)) {
        let rowH: CGFloat = 22
        let headerH: CGFloat = 24
        let totalW = widths.reduce(0, +)
        let scale = contentWidth / totalW
        let ws = widths.map { $0 * scale }

        func drawHeader() {
            ensure(height: headerH)
            let bg = CGRect(x: margin, y: y, width: contentWidth, height: headerH)
            headerColor.setFill()
            UIBezierPath(roundedRect: bg, cornerRadius: 4).fill()
            var x = margin
            let font = UIFont.systemFont(ofSize: 11, weight: .bold)
            for (i, h) in headers.enumerated() {
                let r = CGRect(x: x + 6, y: y + 5, width: ws[i] - 12, height: headerH - 10)
                NSAttributedString(string: h,
                                   attributes: [.font: font, .foregroundColor: UIColor.black])
                    .draw(in: r)
                x += ws[i]
            }
            y += headerH
        }

        drawHeader()
        let cellFont = UIFont.systemFont(ofSize: 10.5, weight: .regular)
        for row in rows {
            if y + rowH > maxY {
                context.beginPage()
                y = margin
                drawHeader()
            }
            var x = margin
            for (i, cell) in row.enumerated() where i < ws.count {
                let r = CGRect(x: x + 6, y: y + 4, width: ws[i] - 12, height: rowH - 6)
                NSAttributedString(string: cell,
                                   attributes: [.font: cellFont, .foregroundColor: UIColor.darkText])
                    .draw(in: r)
                x += ws[i]
            }
            // bottom line
            let line = CGRect(x: margin, y: y + rowH - 0.5, width: contentWidth, height: 0.5)
            UIColor(white: 0.9, alpha: 1).setFill()
            UIRectFill(line)
            y += rowH
        }
    }
}
