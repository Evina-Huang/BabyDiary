import SwiftUI

struct RecordsView: View {
    @Environment(AppStore.self) private var store

    private enum RecordFilter: String, CaseIterable, Hashable {
        case all, feed, sleep, diaper, solid

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
    }

    @State private var anchor: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var selectedDate: Date? = nil
    @State private var calendarOpen = false
    @State private var editing: Event? = nil
    @State private var filter: RecordFilter = .all

    private var filteredSorted: [Event] {
        let dateFiltered: [Event] = {
            guard let sel = selectedDate else { return store.events }
            let cal = Calendar.current
            return store.events.filter { cal.isDate($0.at, inSameDayAs: sel) }
        }()
        let kindFiltered = filter.kind.map { kind in
            dateFiltered.filter { $0.kind == kind }
        } ?? dateFiltered
        return kindFiltered.sorted { $0.at > $1.at }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let label: String
        let items: [Event]
        var id: String { String(day.timeIntervalSinceReferenceDate) }
    }

    private var groups: [DayGroup] {
        let cal = Calendar.current
        var out: [DayGroup] = []
        var currentDay: Date? = nil
        var bucket: [Event] = []
        for e in filteredSorted {
            let day = cal.startOfDay(for: e.at)
            if currentDay == nil {
                currentDay = day
                bucket = [e]
            } else if let currentDay, cal.isDate(day, inSameDayAs: currentDay) {
                bucket.append(e)
            } else {
                out.append(.init(day: currentDay!, label: groupDateLabel(currentDay!), items: bucket))
                currentDay = day
                bucket = [e]
            }
        }
        if let currentDay {
            out.append(.init(day: currentDay, label: groupDateLabel(currentDay), items: bucket))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenBody {
                pageHeader
                    .padding(.bottom, 18)

                filterBar
                    .padding(.bottom, 12)

                monthCalendarHeader

                if groups.isEmpty {
                    let emptyTitle = selectedDate == nil ? "还没有记录" : "这天还没有记录"
                    let emptySub = selectedDate == nil ? "快回到首页添加第一条小记录吧" : "换一天看看吧"
                    Card(padding: 0) {
                        EmptyStateView(title: emptyTitle, subtitle: emptySub)
                    }
                } else {
                    ForEach(groups) { g in
                        groupBlock(g).padding(.bottom, 14)
                    }
                }
            }
        }
        .background(Palette.bg)
        .sheet(item: $editing) { ev in
            EventEditSheet(
                event: ev,
                onCancel: { editing = nil },
                onSave: { updated in
                    store.updateEvent(updated)
                    editing = nil
                },
                onDelete: { removed in
                    store.deleteEvent(removed)
                    editing = nil
                }
            )
            .environment(store)
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("记录")
                    .appFont(size: 28, weight: .bold)
                    .tracking(-0.7)
                    .foregroundStyle(Palette.ink)
                Text(selectedDate == nil ? "按时间查看宝宝的日常" : collapsedLabel)
                    .appFont(size: 13, weight: .medium)
                    .foregroundStyle(Palette.ink3)
            }
            Spacer(minLength: 8)
            Text("\(filteredSorted.count) 条")
                .appFont(size: 13, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(store.theme.primary600)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(store.theme.primaryTint, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecordFilter.allCases, id: \.self) { option in
                    filterChip(option)
                }
            }
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private func filterChip(_ option: RecordFilter) -> some View {
        let selected = filter == option
        let categoryStyle = option.kind.map { CategoryStyle.forKind($0, iconSize: 16) }
        let ink = categoryStyle?.ink ?? store.theme.primary600
        let tint = categoryStyle?.tint ?? store.theme.primaryTint

        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                filter = option
            }
        } label: {
            HStack(spacing: 6) {
                if let categoryStyle {
                    categoryStyle.icon
                        .frame(width: 18, height: 18)
                }
                Text(option.label)
                    .appFont(size: 14, weight: .semibold)
            }
            .foregroundStyle(selected ? ink : Palette.ink2)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(selected ? tint : Palette.card, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(selected ? ink.opacity(0.1) : Palette.line, lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var monthCalendarHeader: some View {
        if !calendarOpen {
            Button { withAnimation(.spring()) { calendarOpen = true } } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(store.theme.primaryTint)
                        AppIcon.Calendar(size: 20, color: store.theme.primary600)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("日期筛选")
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                        Text(collapsedLabel)
                            .appFont(size: 15, weight: .semibold)
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                    AppIcon.Chevron(size: 16, color: Palette.ink3)
                        .rotationEffect(.degrees(90))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                }
            }
            .buttonStyle(PressableStyle())
            .padding(.bottom, 18)
        } else {
            MonthCalendarExpanded(
                anchor: $anchor,
                selectedDate: $selectedDate,
                events: store.events,
                onCollapse: { withAnimation(.spring()) { calendarOpen = false } }
            )
            .padding(.bottom, 18)
        }
    }

    private var collapsedLabel: String {
        if let sel = selectedDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M月d日 EEEE"
            return f.string(from: sel)
        }
        let cal = Calendar.current
        let y = cal.component(.year, from: anchor)
        let m = cal.component(.month, from: anchor)
        return "\(y) 年 \(m) 月 · 全部"
    }

    private func groupDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = cal.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "M月d日"
            : "yyyy年M月d日"
        return f.string(from: date)
    }

    private func groupBlock(_ g: DayGroup) -> some View {
        let summary = store.dailySummary(on: g.day)
        return Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(g.label)
                            .appFont(size: 20, weight: .bold)
                            .tracking(-0.4)
                            .foregroundStyle(Palette.ink)
                        Text(groupDateDetail(g.day))
                            .appFont(size: 12, weight: .medium)
                            .foregroundStyle(Palette.ink3)
                        Spacer(minLength: 8)
                        Text("\(g.items.count) 条")
                            .appFont(size: 12, weight: .semibold)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink3)
                    }

                    if filter == .all, !summary.isEmpty {
                        DailySummaryText(summary: summary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)

                VStack(spacing: 0) {
                    ForEach(Array(g.items.enumerated()), id: \.element.id) { index, event in
                        RecordsTimelineRow(
                            event: event,
                            isLast: index == g.items.count - 1,
                            onDelete: { store.deleteEvent($0) },
                            onEdit: { editing = $0 }
                        )
                    }
                }
            }
        }
    }

    private func groupDateDetail(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }
}

private struct RecordsTimelineRow: View {
    let event: Event
    let isLast: Bool
    let onDelete: (Event) -> Void
    let onEdit: (Event) -> Void

    var body: some View {
        let display = recordDisplayText(for: event)
        let style = CategoryStyle.forKind(event.kind, iconSize: 22)

        Button {
            onEdit(event)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    CategoryIcon(kind: event.kind, size: 40)
                    if !isLast {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(style.ink.opacity(0.16))
                            .frame(width: 2, height: 22)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(display.title)
                            .appFont(size: 15, weight: .semibold)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Text(formatTime(event.at))
                            .appFont(size: 13, weight: .semibold)
                            .monospacedDigit()
                            .foregroundStyle(style.ink)
                    }

                    if let subtitle = display.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .appFont(size: 13, weight: .medium)
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if !isLast {
                        Rectangle()
                            .fill(Palette.line.opacity(0.8))
                            .frame(height: 1)
                            .padding(.top, 7)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, isLast ? 16 : 0)
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button {
                onEdit(event)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                onDelete(event)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityHint("轻触编辑，长按可删除")
    }
}

private struct DailySummaryText: View {
    let summary: DailyEventSummary

    private struct Item: Identifiable {
        let id: String
        let title: String
        let color: Color
    }

    private var items: [Item] {
        var rows: [Item] = []
        if summary.breastCount > 0 {
            rows.append(.init(
                id: "breast",
                title: "母乳 \(summary.breastCount)次 \(formatDurShort(summary.breastDuration))",
                color: Palette.pinkInk
            ))
        }
        if summary.formulaCount > 0 {
            rows.append(.init(
                id: "formula",
                title: "奶粉 \(summary.formulaCount)次 \(summary.formulaMilliliters)ml",
                color: AppTheme.coral.primary600
            ))
        }
        if summary.sleepCount > 0 {
            rows.append(.init(
                id: "sleep",
                title: "睡眠 \(summary.sleepCount)次 \(formatDurShort(summary.sleepDuration))",
                color: Palette.lavenderInk
            ))
        }
        if summary.diaperCount > 0 {
            rows.append(.init(
                id: "diaper",
                title: "换尿布 \(summary.diaperCount)次",
                color: Palette.blueInk
            ))
        }
        if summary.solidCount > 0 {
            rows.append(.init(
                id: "solid",
                title: "辅食 \(summary.solidCount)次",
                color: Palette.yellowInk
            ))
        }
        return rows
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2)

        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 6, height: 6)
                    Text(item.title)
                        .appFont(size: 13, weight: .semibold)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
            }
        }
    }
}

// MARK: — Expanded month calendar

private struct MonthCalendarExpanded: View {
    @Environment(AppStore.self) private var store
    @Binding var anchor: Date
    @Binding var selectedDate: Date?
    let events: [Event]
    let onCollapse: () -> Void

    private var year: Int { Calendar.current.component(.year, from: anchor) }
    private var month: Int { Calendar.current.component(.month, from: anchor) }

    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        Card(padding: 14) {
            VStack(spacing: 10) {
                header
                HStack(spacing: 2) {
                    ForEach(weekdays, id: \.self) { w in
                        Text(w)
                            .appFont(size: 10, weight: .heavy)
                            .tracking(0.4)
                            .foregroundStyle(Palette.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(4)
                    }
                }
                grid
                if selectedDate != nil {
                    Button { selectedDate = nil } label: {
                        Text("显示全部日期")
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            navBtn(mirrored: false) { shiftMonth(-1) }
            Text("\(String(format: "%d", year)) 年 \(month) 月")
                .appFont(size: 15, weight: .semibold)
                .frame(maxWidth: .infinity)
            navBtn(mirrored: true) { shiftMonth(1) }
            Button(action: onCollapse) {
                AppIcon.Close(size: 16, color: Palette.ink2)
                    .frame(width: 44, height: 44)
                    .background(Palette.bg2, in: Circle())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func navBtn(mirrored: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppIcon.Back(size: 18, color: Palette.ink2)
                .frame(width: 44, height: 44)
                .background(Palette.bg2, in: Circle())
                .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        }
        .buttonStyle(PressableStyle())
    }

    private func shiftMonth(_ delta: Int) {
        let cal = Calendar.current
        if let next = cal.date(byAdding: .month, value: delta, to: anchor) {
            anchor = next
        }
    }

    private var grid: some View {
        let cells = buildCells()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                dayCell(d)
            }
        }
    }

    private func buildCells() -> [Int?] {
        let cal = Calendar.current
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else {
            return []
        }
        let weekdaySunStart = cal.component(.weekday, from: first) // 1=Sun
        let firstCol = (weekdaySunStart + 5) % 7  // 0=Mon
        var cells: [Int?] = Array(repeating: nil, count: firstCol)
        for d in range { cells.append(d) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func dayCell(_ d: Int?) -> some View {
        Group {
            if let d {
                let cal = Calendar.current
                let date = cal.date(from: DateComponents(year: year, month: month, day: d))!
                let isToday = cal.isDateInToday(date)
                let isSelected = selectedDate.map { cal.isDate(date, inSameDayAs: $0) } ?? false
                let kinds = kindsOn(date)
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selectedDate = isSelected ? nil : date
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text("\(d)")
                            .appFont(size: 13, weight: isSelected || isToday ? .heavy : .semibold)
                            .monospacedDigit()
                            .foregroundStyle(
                                isSelected ? .white
                                : isToday ? store.theme.primary600
                                : Palette.ink
                            )
                        HStack(spacing: 2) {
                            ForEach(kinds.prefix(4), id: \.self) { k in
                                Circle()
                                    .fill(isSelected ? Palette.card : kindColor(k))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                isSelected ? store.theme.primary600
                                : isToday ? store.theme.primaryTint
                                : .clear
                            )
                    )
                }
                .buttonStyle(PressableStyle())
            } else {
                Color.clear.frame(height: 44)
            }
        }
    }

    private func kindsOn(_ date: Date) -> [EventKind] {
        let cal = Calendar.current
        var set: Set<EventKind> = []
        for e in events where cal.isDate(e.at, inSameDayAs: date) {
            set.insert(e.kind)
        }
        return EventKind.allCases.filter { set.contains($0) }
    }

    private func kindColor(_ k: EventKind) -> Color {
        switch k {
        case .feed:   return Palette.pinkInk
        case .sleep:  return Palette.lavenderInk
        case .diaper: return Palette.blueInk
        case .solid:  return Palette.yellowInk
        }
    }
}

#Preview("记录") {
    RecordsView()
        .environment(AppStore.preview)
}
