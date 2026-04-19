import SwiftUI
import Charts

// WHO-ish reference values (50th percentile approximation for demo).
// Not medical data.
struct GrowthRef {
    let m: Int
    let p3: Double
    let p50: Double
    let p97: Double
}

enum GrowthMetric: String, Hashable, CaseIterable {
    case weight, height

    var label: String { self == .weight ? "体重" : "身高" }
    var unit: String  { self == .weight ? "kg" : "cm" }

    var accentInk: Color   { self == .weight ? Palette.pinkInk : Palette.blueInk }
    var accentTint: Color  { self == .weight ? Palette.pink    : Palette.blue }
}

fileprivate let WEIGHT_REF: [GrowthRef] = [
    .init(m: 0,  p3: 2.5, p50: 3.3, p97: 4.4),
    .init(m: 1,  p3: 3.4, p50: 4.5, p97: 5.8),
    .init(m: 2,  p3: 4.4, p50: 5.6, p97: 7.1),
    .init(m: 3,  p3: 5.1, p50: 6.4, p97: 8.0),
    .init(m: 4,  p3: 5.6, p50: 7.0, p97: 8.7),
    .init(m: 5,  p3: 6.1, p50: 7.5, p97: 9.3),
    .init(m: 6,  p3: 6.4, p50: 7.9, p97: 9.8),
    .init(m: 7,  p3: 6.7, p50: 8.3, p97: 10.3),
    .init(m: 8,  p3: 6.9, p50: 8.6, p97: 10.7),
    .init(m: 9,  p3: 7.1, p50: 8.9, p97: 11.0),
    .init(m: 10, p3: 7.4, p50: 9.2, p97: 11.4),
    .init(m: 11, p3: 7.6, p50: 9.4, p97: 11.7),
    .init(m: 12, p3: 7.7, p50: 9.6, p97: 12.0),
]

fileprivate let HEIGHT_REF: [GrowthRef] = [
    .init(m: 0,  p3: 46.1, p50: 49.9, p97: 53.7),
    .init(m: 1,  p3: 50.8, p50: 54.7, p97: 58.6),
    .init(m: 2,  p3: 54.4, p50: 58.4, p97: 62.4),
    .init(m: 3,  p3: 57.3, p50: 61.4, p97: 65.5),
    .init(m: 4,  p3: 59.7, p50: 63.9, p97: 68.0),
    .init(m: 5,  p3: 61.7, p50: 65.9, p97: 70.1),
    .init(m: 6,  p3: 63.3, p50: 67.6, p97: 71.9),
    .init(m: 7,  p3: 64.8, p50: 69.2, p97: 73.5),
    .init(m: 8,  p3: 66.2, p50: 70.6, p97: 75.0),
    .init(m: 9,  p3: 67.5, p50: 72.0, p97: 76.5),
    .init(m: 10, p3: 68.7, p50: 73.3, p97: 77.9),
    .init(m: 11, p3: 69.9, p50: 74.5, p97: 79.2),
    .init(m: 12, p3: 71.0, p50: 75.7, p97: 80.5),
]

private func refFor(_ m: GrowthMetric) -> [GrowthRef] {
    m == .weight ? WEIGHT_REF : HEIGHT_REF
}

struct GrowthView: View {
    let onOpenVaccines: () -> Void
    @Environment(AppStore.self) private var store

    @State private var metric: GrowthMetric = .weight
    @State private var adding = false
    @State private var wInput: String = ""
    @State private var hInput: String = ""
    @State private var historyOpen = false
    @State private var historyFilter: HistoryFilter = .all

    enum HistoryFilter: Hashable { case all, d30, d90, d365
        var label: String {
            switch self {
            case .all: return "全部"
            case .d30: return "近 30 天"
            case .d90: return "近 90 天"
            case .d365:return "近 1 年"
            }
        }
    }

    private var sorted: [GrowthPoint] {
        store.growth.sorted { $0.ageMonths < $1.ageMonths }
    }
    private var latest: GrowthPoint? { sorted.last }
    private var prev: GrowthPoint? {
        sorted.count >= 2 ? sorted[sorted.count - 2] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            TabTitleHeader(kicker: "\(store.baby.name) · \(store.baby.ageLabel)",
                           title: "成长")
            ScreenBody {
                statCards
                chartCard.padding(.top, 14)
                addButton.padding(.top, 14)
                historyBlock.padding(.top, 22)
                vaccinesEntry.padding(.top, 22)
            }
        }
        .background(Palette.bg)
    }

    // MARK: — Two stat cards (weight + height)

    private var statCards: some View {
        HStack(spacing: 10) {
            statCard(.weight)
            statCard(.height)
        }
    }

    private func statCard(_ m: GrowthMetric) -> some View {
        let on = metric == m
        let delta: Double? = {
            guard let l = latest, let p = prev else { return nil }
            return m == .weight ? l.weightKg - p.weightKg : l.heightCm - p.heightCm
        }()
        let value: Double? = latest.map { m == .weight ? $0.weightKg : $0.heightCm }
        return Button { withAnimation(.easeOut(duration: 0.16)) { metric = m } } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(m.label)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(m.accentInk.opacity(0.75))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.system(size: 26, weight: .black))
                        .tracking(-0.52)
                        .monospacedDigit()
                        .foregroundStyle(m.accentInk)
                    Text(m.unit)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(m.accentInk.opacity(0.7))
                }
                .padding(.top, 6)
                if let d = delta, d > 0 {
                    Text("本月 +\(String(format: "%.1f", d)) \(m.unit)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(m.accentInk.opacity(0.75))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(m.accentTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(on ? m.accentInk : .clear, lineWidth: 2)
            )
            .shadow(color: on ? Color(hex: 0x2B2520).opacity(0.06) : .clear, radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: — Chart card

    private var chartCard: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("生长曲线 · \(metric.label)")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(-0.15)
                        Text("0 — 12 月龄 · WHO 参考范围")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                    if let p = percentileTag() {
                        Text(p.label)
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(-0.11)
                            .foregroundStyle(p.ink)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(metric.accentTint, in: Capsule())
                    }
                }

                GrowthChartView(metric: metric, entries: sorted)
                    .frame(height: 200)

                if let txt = peerText() {
                    Text(txt)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(-0.12)
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                legend
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(Rectangle().fill(metric.accentInk).frame(width: 14, height: 3), label: "小宝")
            legendItem(Rectangle().fill(metric.accentTint.opacity(0.55))
                        .frame(width: 14, height: 8)
                        .clipShape(RoundedRectangle(cornerRadius: 3)),
                       label: "健康范围")
            legendItem(Rectangle().fill(metric.accentInk.opacity(0.5))
                        .frame(width: 14, height: 1.5),
                       label: "中位数")
            Spacer()
        }
        .padding(.top, 4)
    }

    private func legendItem<S: View>(_ swatch: S, label: String) -> some View {
        HStack(spacing: 6) {
            swatch
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.ink2)
        }
    }

    private func percentileTag() -> (label: String, ink: Color)? {
        guard let l = latest else { return nil }
        let ref = refFor(metric)
        guard let r = ref.first(where: { $0.m == Int(l.ageMonths) }) ?? ref.last else { return nil }
        let v = metric == .weight ? l.weightKg : l.heightCm
        if v < r.p3 { return ("偏低", Color(hex: 0xFF7F64)) }
        if v > r.p97 { return ("偏高", Palette.yellowInk) }
        let pct: Double = v < r.p50
            ? 3 + (v - r.p3) / (r.p50 - r.p3) * 47
            : 50 + (v - r.p50) / (r.p97 - r.p50) * 47
        return ("第 \(Int(pct.rounded())) 百分位", Palette.mint600)
    }

    private func peerText() -> String? {
        guard let l = latest else { return nil }
        let ref = refFor(metric)
        guard let r = ref.first(where: { $0.m == Int(l.ageMonths) }) else { return nil }
        let v = metric == .weight ? l.weightKg : l.heightCm
        var pct = v < r.p50
            ? 3 + (v - r.p3) / (r.p50 - r.p3) * 47
            : 50 + (v - r.p50) / (r.p97 - r.p50) * 47
        pct = max(1, min(99, pct.rounded()))
        return "\(store.baby.name)的\(metric.label)超过了同龄\(Int(pct))%的宝宝 ✨"
    }

    // MARK: — Add measurement

    @ViewBuilder
    private var addButton: some View {
        if !adding {
            Button {
                withAnimation(.spring()) { adding = true }
            } label: {
                HStack(spacing: 8) {
                    AppIcon.Plus(size: 18, color: .white)
                    Text("记录新测量")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(store.theme.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadowPill(tint: store.theme.primary600)
            }
            .buttonStyle(PressableStyle())
        } else {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("新测量")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel(text: "体重 (kg)")
                            TextField(latest.map { String(format: "%.1f", $0.weightKg) } ?? "0.0",
                                      text: $wInput)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            FieldLabel(text: "身高 (cm)")
                            TextField(latest.map { String(format: "%.1f", $0.heightCm) } ?? "0.0",
                                      text: $hInput)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    HStack(spacing: 8) {
                        Button {
                            withAnimation { adding = false; wInput = ""; hInput = "" }
                        } label: {
                            Text("取消")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        Button(action: submit) {
                            Text("保存")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(store.theme.primary,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadowPill(tint: store.theme.primary600)
                        }
                        .buttonStyle(PressableStyle())
                        .frame(maxWidth: .infinity)
                        .layoutPriority(2)
                    }
                }
            }
        }
    }

    private func submit() {
        let w = Double(wInput.trimmingCharacters(in: .whitespaces))
        let h = Double(hInput.trimmingCharacters(in: .whitespaces))
        guard w != nil || h != nil else { return }
        let useW = w ?? latest?.weightKg ?? 0
        let useH = h ?? latest?.heightCm ?? 0
        store.addGrowth(.init(
            id: "g" + UUID().uuidString.prefix(6).lowercased(),
            date: Date(),
            ageMonths: 6,
            weightKg: useW,
            heightCm: useH,
            headCm: nil))
        wInput = ""; hInput = ""
        withAnimation(.spring()) { adding = false }
    }

    // MARK: — History

    private var historyBlock: some View {
        let all = Array(sorted.reversed())
        let visible: [GrowthPoint] = {
            if !historyOpen { return Array(all.prefix(5)) }
            switch historyFilter {
            case .all: return all
            case .d30, .d90, .d365:
                let days = historyFilter == .d30 ? 30 : (historyFilter == .d90 ? 90 : 365)
                let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
                return all.filter { $0.date >= cutoff }
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("测量历史")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                Spacer()
                Text("共 \(all.count) 条")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink3)
            }

            if historyOpen {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([HistoryFilter.all, .d30, .d90, .d365], id: \.self) { f in
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) { historyFilter = f }
                            } label: {
                                Text(f.label)
                                    .font(.system(size: 12, weight: .heavy))
                                    .tracking(-0.12)
                                    .foregroundStyle(historyFilter == f ? .white : Palette.ink2)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(historyFilter == f ? store.theme.primary : Palette.bg2,
                                                in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }

            Card(padding: 0) {
                VStack(spacing: 0) {
                    if visible.isEmpty {
                        Text("这段时间没有记录")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { i, g in
                            historyRow(g, earlier: i + 1 < visible.count ? visible[i + 1] : nil,
                                       last: i == visible.count - 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }

            if !historyOpen, all.count > 5 {
                Button { withAnimation(.spring()) { historyOpen = true } } label: {
                    Text("显示全部 \(all.count) 条记录")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(-0.13)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
            if historyOpen {
                Button {
                    withAnimation(.spring()) { historyOpen = false; historyFilter = .all }
                } label: {
                    Text("收起")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(-0.13)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func historyRow(_ g: GrowthPoint, earlier: GrowthPoint?, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.mintTint)
                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                        Text("\(Int(g.ageMonths))")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Palette.mint600)
                        Text("月")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.mint600)
                    }
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(format: "%.1f", g.weightKg)) kg · \(String(format: "%.1f", g.heightCm)) cm")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    let dateStr = isoDate(g.date)
                    let deltaText: String = {
                        guard let e = earlier else { return "" }
                        return String(format: " · +%.1fkg / +%.1fcm",
                                      g.weightKg - e.weightKg,
                                      g.heightCm - e.heightCm)
                    }()
                    Text("\(dateStr)\(deltaText)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            if !last {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
    }

    private func isoDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    // MARK: — Vaccines entry card

    private var vaccinesEntry: some View {
        Button(action: onOpenVaccines) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.mintTint)
                    AppIcon.Shield(size: 24, color: Palette.mint600)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("疫苗记录")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    Text("查看接种计划与进度")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
                AppIcon.Chevron(size: 16, color: Palette.ink3)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadowCard()
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: — Native Swift Charts growth chart

private struct GrowthChartView: View {
    let metric: GrowthMetric
    let entries: [GrowthPoint]

    var body: some View {
        let ref = refFor(metric)
        let accent = metric.accentInk
        let tint = metric.accentTint

        Chart {
            ForEach(ref, id: \.m) { r in
                AreaMark(
                    x: .value("月龄", r.m),
                    yStart: .value("p3", r.p3),
                    yEnd: .value("p97", r.p97)
                )
                .foregroundStyle(tint.opacity(0.35))
                .interpolationMethod(.catmullRom)
            }
            ForEach(ref, id: \.m) { r in
                LineMark(
                    x: .value("月龄", r.m),
                    y: .value("p50", r.p50),
                    series: .value("series", "p50")
                )
                .foregroundStyle(accent.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .interpolationMethod(.catmullRom)
            }
            ForEach(entries) { e in
                let v = metric == .weight ? e.weightKg : e.heightCm
                LineMark(
                    x: .value("月龄", e.ageMonths),
                    y: .value(metric.label, v),
                    series: .value("series", "baby")
                )
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { i, e in
                let v = metric == .weight ? e.weightKg : e.heightCm
                PointMark(
                    x: .value("月龄", e.ageMonths),
                    y: .value(metric.label, v)
                )
                .symbol {
                    Circle()
                        .stroke(accent, lineWidth: 2.5)
                        .background(Circle().fill(.white))
                        .frame(width: i == entries.count - 1 ? 10 : 7,
                               height: i == entries.count - 1 ? 10 : 7)
                }
            }
            if let l = entries.last {
                let v = metric == .weight ? l.weightKg : l.heightCm
                PointMark(
                    x: .value("月龄", l.ageMonths),
                    y: .value(metric.label, v)
                )
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    Text("\(String(format: "%.1f", v))\(metric.unit)")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(accent, in: Capsule())
                }
                .symbol { Circle().fill(.clear).frame(width: 0, height: 0) }
            }
        }
        .chartXScale(domain: 0...12)
        .chartXAxis {
            AxisMarks(values: [0, 3, 6, 9, 12]) { v in
                AxisValueLabel {
                    if let m = v.as(Int.self) {
                        Text("\(m)月")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.ink3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Palette.line)
                AxisValueLabel()
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.ink3)
            }
        }
    }
}

// Reusable large-title header for tab screens (matches React kicker + title).
struct TabTitleHeader: View {
    let kicker: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker)
                .font(.system(size: 13, weight: .bold))
                .tracking(1.04)
                .textCase(.uppercase)
                .foregroundStyle(Palette.ink3)
            Text(title)
                .font(.system(size: 28, weight: .black))
                .tracking(-0.84)
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 62)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

#Preview("成长") {
    GrowthView(onOpenVaccines: {})
        .environment(AppStore.preview)
}
