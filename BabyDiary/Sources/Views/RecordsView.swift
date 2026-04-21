import SwiftUI

struct RecordsView: View {
    @Environment(AppStore.self) private var store

    @State private var anchor: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var selectedDate: Date? = nil
    @State private var calendarOpen = false
    @State private var editing: Event? = nil

    private var filteredSorted: [Event] {
        let base: [Event] = {
            guard let sel = selectedDate else { return store.events }
            let cal = Calendar.current
            return store.events.filter { cal.isDate($0.at, inSameDayAs: sel) }
        }()
        return base.sorted { $0.at > $1.at }
    }

    private struct Group: Identifiable {
        let label: String
        let items: [Event]
        var id: String { label }
    }

    private var groups: [Group] {
        var out: [Group] = []
        var currentLabel: String? = nil
        var bucket: [Event] = []
        for e in filteredSorted {
            let lbl = formatDateLabel(e.at)
            if currentLabel == nil {
                currentLabel = lbl
                bucket = [e]
            } else if currentLabel == lbl {
                bucket.append(e)
            } else {
                out.append(.init(label: currentLabel!, items: bucket))
                currentLabel = lbl
                bucket = [e]
            }
        }
        if let l = currentLabel { out.append(.init(label: l, items: bucket)) }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            TabTitleHeader(kicker: kickerText, title: "记录")
            ScreenBody {
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

    private var kickerText: String {
        if let sel = selectedDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M月d日 EEEE"
            return f.string(from: sel)
        }
        return "全部"
    }

    @ViewBuilder
    private var monthCalendarHeader: some View {
        if !calendarOpen {
            Button { withAnimation(.spring()) { calendarOpen = true } } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(store.theme.primaryTint)
                        AppIcon.Calendar(size: 18, color: store.theme.primary600)
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("查看日期")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.ink3)
                        Text(collapsedLabel)
                            .font(.system(size: 14, weight: .heavy))
                            .tracking(-0.14)
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                    AppIcon.Chevron(size: 16, color: Palette.ink3)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadowCard()
            }
            .buttonStyle(PressableStyle())
            .padding(.bottom, 14)
        } else {
            MonthCalendarExpanded(
                anchor: $anchor,
                selectedDate: $selectedDate,
                events: store.events,
                onCollapse: { withAnimation(.spring()) { calendarOpen = false } }
            )
            .padding(.bottom, 14)
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

    private func groupBlock(_ g: Group) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(g.label)
                .font(.system(size: 13, weight: .heavy))
                .tracking(0.52)
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(g.items.enumerated()), id: \.element.id) { i, e in
                        EventRow(event: e,
                                 last: i == g.items.count - 1,
                                 onDelete: { store.deleteEvent($0) },
                                 onEdit: { editing = $0 })
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

// MARK: — Expanded month calendar

private struct MonthCalendarExpanded: View {
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
                            .font(.system(size: 10, weight: .heavy))
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
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(-0.12)
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
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
                .font(.system(size: 15, weight: .heavy))
                .tracking(-0.15)
                .frame(maxWidth: .infinity)
            navBtn(mirrored: true) { shiftMonth(1) }
            Button(action: onCollapse) {
                AppIcon.Close(size: 16, color: Palette.ink2)
                    .frame(width: 32, height: 32)
                    .background(Palette.bg2, in: Circle())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func navBtn(mirrored: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppIcon.Back(size: 18, color: Palette.ink2)
                .frame(width: 32, height: 32)
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
                            .font(.system(size: 13, weight: isSelected || isToday ? .heavy : .semibold))
                            .monospacedDigit()
                            .foregroundStyle(
                                isSelected ? .white
                                : isToday ? Color(hex: 0xFF7F64)
                                : Palette.ink
                            )
                        HStack(spacing: 2) {
                            ForEach(kinds.prefix(4), id: \.self) { k in
                                Circle()
                                    .fill(isSelected ? Color.white : kindColor(k))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                isSelected ? Color(hex: 0xFF9B85)
                                : isToday ? Color(hex: 0xFFE8E0)
                                : .clear
                            )
                    )
                }
                .buttonStyle(PressableStyle())
            } else {
                Color.clear.frame(height: 40)
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
