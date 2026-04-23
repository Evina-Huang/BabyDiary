import SwiftUI

struct StatsView: View {
    @Environment(AppStore.self) private var store

    enum Range: Int, Hashable, CaseIterable {
        case d7 = 7, d14 = 14, d30 = 30
        var label: String { "\(rawValue) 天" }
    }

    @State private var range: Range = .d7

    var body: some View {
        VStack(spacing: 0) {
            ScreenBody {
                rangeSeg
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 14)
                PatternChart(events: store.events, range: range.rawValue)
            }
        }
        .background(Palette.bg)
    }

    private var rangeSeg: some View {
        SegPill(selection: $range,
                options: Range.allCases.map { ($0, $0.label) })
    }
}

// 24h vertical × N days horizontal — reveals daily rhythm.
private struct PatternChart: View {
    let events: [Event]
    let range: Int

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
        var color: Color {
            switch self {
            case .all: return Palette.ink
            case .feed: return Palette.pinkInk
            case .sleep: return Palette.lavenderInk
            case .diaper: return Palette.blueInk
            case .solid: return Palette.yellowInk
            }
        }
    }

    @State private var filter: Filter = .all

    private let HOURS = 24
    private let CELL_H: CGFloat = 18
    private let AXIS_W: CGFloat = 28
    private let AXIS_LABEL_H: CGFloat = 16

    private var chartH: CGFloat { CGFloat(HOURS) * CELL_H }
    private var tickHours: [Int] { Array(stride(from: 0, through: HOURS, by: 2)) }

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<range).map { i in
            cal.date(byAdding: .day, value: i - (range - 1), to: today)!
        }
    }

    var body: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 6)
                filterChips.padding(.bottom, 12)
                chartBody
                legend.padding(.top, 14)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xFFE8E0))
                AppIcon.Clock(size: 20, color: Color(hex: 0xFF7F64))
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("时间规律")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
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
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(-0.12)
                            .foregroundStyle(filter == f ? .white : Palette.ink2)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(filter == f ? f.color : Palette.bg2, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
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
    }

    private var yAxis: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(tickHours, id: \.self) { hour in
                Text(String(format: "%02d", hour))
                    .font(.system(size: 10, weight: .bold))
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
                    .fill(isToday ? Color(hex: 0xFFE8E0) : Palette.bg2)
                    .opacity(isToday ? 1 : 0.7)
                    .frame(height: chartH)

                ForEach(tickHours, id: \.self) { hour in
                    Rectangle()
                        .fill(Color.white.opacity(0.7))
                        .frame(height: 1)
                        .offset(y: yOffset(forHour: Double(hour)))
                }

                if filter == .all || filter == .sleep {
                    ForEach(sleeps) { s in sleepBar(for: s, on: d) }
                }
                ForEach(points) { e in eventDot(e) }
            }
            Text(xLabel(for: d))
                .font(.system(size: 10, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color(hex: 0xFF7F64) : Palette.ink3)
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
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .frame(width: 10, height: 10)
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                .offset(x: geo.size.width / 2 - 5, y: top - 5)
        }
    }

    private func kindColor(_ k: EventKind) -> Color {
        switch k {
        case .feed:   return Palette.pinkInk
        case .sleep:  return Palette.lavenderInk
        case .diaper: return Palette.blueInk
        case .solid:  return Palette.yellowInk
        }
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
        HStack(spacing: 14) {
            legendItem(circle: Palette.pinkInk,     label: "喂奶")
            legendItem(ring: Palette.lavenderInk,   label: "睡眠")
            legendItem(circle: Palette.blueInk,     label: "尿布")
            legendItem(circle: Palette.yellowInk,   label: "辅食")
            Spacer()
        }
        .padding(.top, 10)
        .overlay(Rectangle().fill(Palette.line).frame(height: 1), alignment: .top)
    }

    private func legendItem(circle: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(circle).frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.ink2)
        }
    }
    private func legendItem(ring: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().stroke(ring, lineWidth: 3).frame(width: 10, height: 10).opacity(0.45)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.ink2)
        }
    }
}

#Preview("统计") {
    StatsView()
        .environment(AppStore.preview)
}
