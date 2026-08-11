import SwiftUI

enum StatsRange: Int, Hashable, CaseIterable {
    case d7 = 7, d14 = 14, d30 = 30
    var label: String { "\(rawValue) 天" }
}

struct StatsDashboardView: View {
    @Environment(AppStore.self) private var store
    @Binding var range: StatsRange

    private var periodStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today) ?? today
    }

    private var periodEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1,
                              to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var periodEvents: [Event] {
        store.events.filter { $0.at >= periodStart && $0.at < periodEnd }
    }

    private var averageSleep: TimeInterval {
        let seconds = store.events.reduce(0.0) { result, event in
            guard event.kind == .sleep, let endAt = event.endAt else { return result }
            let clippedStart = max(event.at, periodStart)
            let clippedEnd = min(endAt, periodEnd)
            return result + max(0, clippedEnd.timeIntervalSince(clippedStart))
        }
        return seconds / Double(range.rawValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            rangeSeg
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)

            overviewCard
                .padding(.bottom, 16)

            PatternChart(events: store.events, range: range.rawValue, theme: store.theme)
        }
    }

    private var rangeSeg: some View {
        SegPill(selection: $range,
                options: StatsRange.allCases.map { ($0, $0.label) })
            .frame(minHeight: 44)
            .accessibilityLabel("趋势时间范围")
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("周期概览")
                    .appFont(size: 16, weight: .bold)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(periodDateLabel)
                    .appFont(size: 12, weight: .medium)
                    .foregroundStyle(Palette.ink3)
            }

            HStack(spacing: 10) {
                summaryCell(kind: .sleep,
                            value: formatDurShort(averageSleep),
                            subtitle: "日均时长")
                summaryCell(kind: .feed,
                            value: averageCount(for: .feed),
                            subtitle: "日均次数")
            }
            HStack(spacing: 10) {
                summaryCell(kind: .diaper,
                            value: averageCount(for: .diaper),
                            subtitle: "日均次数")
                summaryCell(kind: .solid,
                            value: averageCount(for: .solid),
                            subtitle: "日均次数")
            }
        }
    }

    private func summaryCell(kind: EventKind, value: String, subtitle: String) -> some View {
        let style = CategoryStyle.forKind(kind, iconSize: 17)
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                    .fill(Palette.card.opacity(0.7))
                style.icon
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.label)
                    .appFont(size: 11, weight: .medium)
                    .foregroundStyle(style.ink)
                Text(value)
                    .appFont(size: 17, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .appFont(size: 10, weight: .medium)
                    .foregroundStyle(Palette.ink3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(style.tint, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func averageCount(for kind: EventKind) -> String {
        let count = periodEvents.filter { $0.kind == kind }.count
        let average = Double(count) / Double(range.rawValue)
        return String(format: "%.1f 次", average)
    }

    private var periodDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: periodEnd) ?? Date()
        return "\(formatter.string(from: periodStart)) – \(formatter.string(from: lastDay))"
    }
}

// 24h vertical × N days horizontal — reveals daily rhythm.
private struct PatternChart: View {
    let events: [Event]
    let range: Int
    let theme: AppTheme

    enum Filter: Hashable { case all, feed, sleep, diaper, solid
        var label: String {
            switch self {
            case .all: return "全部"
            case .feed: return "喂奶"
            case .sleep: return "睡眠"
            case .diaper: return "尿布"
            case .solid: return "辅食"
            }
        }
        var kind: EventKind? {
            switch self {
            case .all: return nil
            case .feed: return .feed
            case .sleep: return .sleep
            case .diaper: return .diaper
            case .solid: return .solid
            }
        }
        var color: Color {
            kind.map { CategoryStyle.forKind($0).ink } ?? Palette.ink
        }
        var tint: Color {
            kind.map { CategoryStyle.forKind($0).tint } ?? Palette.card
        }
    }

    @State private var filter: Filter = .all

    private let HOURS = 24
    private let CELL_H: CGFloat = 16
    private let AXIS_W: CGFloat = 28
    private let AXIS_LABEL_H: CGFloat = 16

    private var chartH: CGFloat { CGFloat(HOURS) * CELL_H }
    private var tickHours: [Int] { Array(stride(from: 0, through: HOURS, by: 3)) }

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<range).map { i in
            cal.date(byAdding: .day, value: i - (range - 1), to: today)!
        }
    }

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 10)
                filterChips.padding(.bottom, 14)
                chartBody
                legend.padding(.top, 14)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("24 小时时间分布")
                    .appFont(size: 16, weight: .bold)
                    .foregroundStyle(Palette.ink)
                Text("纵向查看每天的记录发生时段")
                    .appFont(size: 12, weight: .medium)
                    .foregroundStyle(Palette.ink3)
            }
            Spacer(minLength: 0)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach([Filter.all, .feed, .sleep, .diaper, .solid], id: \.self) { f in
                    Button { withAnimation(.easeOut(duration: 0.16)) { filter = f } } label: {
                        Text(f.label)
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(filter == f ? f.color : Palette.ink2)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(filter == f ? f.tint : Palette.bg2, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(filter == f ? f.color.opacity(0.12) : Palette.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(filter == f ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private var chartBody: some View {
        HStack(spacing: 0) {
            yAxis
            if range > 7 {
                ScrollView(.horizontal, showsIndicators: false) {
                    daysRow(minWidth: CGFloat(range) * 44)
                }
            } else {
                daysRow(minWidth: nil)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("过去 \(range) 天的\(filter.label)时间分布，纵轴从零点到二十四点")
    }

    private var yAxis: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(tickHours, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .appFont(size: 10, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink3)
                    .frame(width: AXIS_W, height: AXIS_LABEL_H, alignment: .trailing)
                    .offset(y: axisLabelOffset(forHour: hour))
            }
        }
        .frame(width: AXIS_W, height: chartH, alignment: .topTrailing)
        .padding(.trailing, 10)
    }

    private func daysRow(minWidth: CGFloat?) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                dayColumn(d)
                    .frame(width: range > 7 ? 44 : nil)
                    .frame(maxWidth: range <= 7 ? .infinity : nil)
            }
        }
        .frame(minWidth: minWidth)
    }

    private func dayColumn(_ d: Date) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(d)
        let sleeps = events.filter {
            $0.kind == .sleep && $0.duration != nil && matchesFilter($0) && sleepOverlapsDay($0, d)
        }
        let points = events.filter {
            cal.isDate($0.at, inSameDayAs: d) && matchesFilter($0) && !($0.kind == .sleep && $0.duration != nil)
        }

        return VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isToday ? theme.primaryTint : Palette.bg2)
                    .opacity(isToday ? 1 : 0.7)
                    .frame(height: chartH)

                ForEach(tickHours, id: \.self) { hour in
                    Rectangle()
                        .fill(Palette.card.opacity(0.7))
                        .frame(height: 1)
                        .offset(y: yOffset(forHour: Double(hour)))
                }

                if filter == .all || filter == .sleep {
                    ForEach(sleeps) { s in sleepBar(for: s, on: d) }
                }
                ForEach(points) { e in eventDot(e) }
            }
            Text(xLabel(for: d))
                .appFont(size: 10, weight: .bold)
                .monospacedDigit()
                .foregroundStyle(isToday ? theme.primary600 : Palette.ink3)
        }
    }

    @ViewBuilder
    private func sleepBar(for s: Event, on day: Date) -> some View {
        let cal = Calendar.current
        if let endAt = s.endAt {
            let dayStart = cal.startOfDay(for: day)
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let a = max(s.at.timeIntervalSince(dayStart), 0)
            let b = min(endAt.timeIntervalSince(dayStart), dayEnd.timeIntervalSince(dayStart))
            let topHours = a / 3600
            let durHours = max((b - a) / 3600, 0.1)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Palette.lavenderInk.opacity(0.35))
                    .frame(width: geo.size.width - 4,
                           height: max(3, durHours * CELL_H))
                    .offset(x: 2, y: yOffset(forHour: topHours))
            }
        }
    }

    private func sleepOverlapsDay(_ s: Event, _ day: Date) -> Bool {
        guard let endAt = s.endAt else { return false }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        return s.at < dayEnd && endAt > dayStart
    }

    private func eventDot(_ e: Event) -> some View {
        let cal = Calendar.current
        let hour = Double(cal.component(.hour, from: e.at))
        let minute = Double(cal.component(.minute, from: e.at))
        let top = yOffset(forHour: hour + minute / 60)
        return GeometryReader { geo in
            Circle()
                .fill(kindColor(e.kind))
                .overlay(Circle().stroke(Palette.card, lineWidth: 1.5))
                .frame(width: 10, height: 10)
                .offset(x: geo.size.width / 2 - 5, y: top - 5)
        }
    }

    private func kindColor(_ k: EventKind) -> Color {
        CategoryStyle.forKind(k).ink
    }

    private func matchesFilter(_ e: Event) -> Bool {
        switch filter {
        case .all: return true
        case .feed: return e.kind == .feed
        case .sleep: return e.kind == .sleep
        case .diaper: return e.kind == .diaper
        case .solid: return e.kind == .solid
        }
    }

    private func yOffset(forHour hour: Double) -> CGFloat {
        CGFloat(hour) * CELL_H
    }

    private func axisLabelOffset(forHour hour: Int) -> CGFloat {
        yOffset(forHour: Double(hour)) - AXIS_LABEL_H / 2
    }

    private func xLabel(for d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "今天" }
        if range <= 7 {
            let w = (cal.component(.weekday, from: d) + 5) % 7
            return ["一","二","三","四","五","六","日"][w]
        }
        let m = cal.component(.month, from: d)
        let day = cal.component(.day, from: d)
        return "\(m)/\(day)"
    }

    private var legend: some View {
        let feed = CategoryStyle.forKind(.feed)
        let sleep = CategoryStyle.forKind(.sleep)
        let diaper = CategoryStyle.forKind(.diaper)
        let solid = CategoryStyle.forKind(.solid)
        return HStack(spacing: 14) {
            legendItem(circle: feed.ink, label: feed.label)
            legendItem(ring: sleep.ink, label: sleep.label)
            legendItem(circle: diaper.ink, label: "尿布")
            legendItem(circle: solid.ink, label: solid.label)
            Spacer()
        }
        .padding(.top, 10)
        .overlay(Rectangle().fill(Palette.line).frame(height: 1), alignment: .top)
    }

    private func legendItem(circle: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(circle).frame(width: 10, height: 10)
            Text(label)
                .appFont(size: 12, weight: .bold)
                .foregroundStyle(Palette.ink2)
        }
    }
    private func legendItem(ring: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().stroke(ring, lineWidth: 3).frame(width: 10, height: 10).opacity(0.45)
            Text(label)
                .appFont(size: 12, weight: .bold)
                .foregroundStyle(Palette.ink2)
        }
    }
}

#Preview("记录趋势") {
    ScreenBody {
        StatsDashboardView(range: .constant(.d7))
    }
    .background(Palette.bg)
    .environment(AppStore.preview)
}
