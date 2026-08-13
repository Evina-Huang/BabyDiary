import SwiftUI

struct RecordsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onOpen: (SubScreen) -> Void

    init(onOpen: @escaping (SubScreen) -> Void = { _ in }) {
        self.onOpen = onOpen
    }

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
    @State private var showingTrends = false
    @State private var statsRange: StatsRange = .d7
    @State private var pendingDeletion: DeletedEventSnapshot?
    @State private var undoDismissTask: Task<Void, Never>?

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
        ZStack {
            timelineList
                .opacity(showingTrends ? 0 : 1)
                .allowsHitTesting(!showingTrends)
                .accessibilityHidden(showingTrends)

            trendsScroll
                .opacity(showingTrends ? 1 : 0)
                .allowsHitTesting(showingTrends)
                .accessibilityHidden(!showingTrends)
        }
        .background(Palette.bg)
        .overlay(alignment: .bottom) {
            if let pendingDeletion {
                UndoToast(message: "已删除“\(pendingDeletion.event.title)”", action: undoDeletion)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $editing) { ev in
            EventEditSheet(
                event: ev,
                onCancel: { editing = nil },
                onSave: { updated in
                    store.updateEvent(updated)
                    editing = nil
                },
                onDelete: { removed in
                    deleteWithUndo(removed)
                    editing = nil
                }
            )
            .environment(store)
        }
        .onDisappear {
            undoDismissTask?.cancel()
        }
    }

    private var recordsHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Text("记录")
                .appText(.pageTitle)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Button { setShowingTrends(true) } label: {
                HStack(spacing: 6) {
                    AppIcon.Chart(size: 16, color: store.theme.primary600)
                    Text("趋势")
                        .appFont(size: 13, weight: .semibold)
                }
                .foregroundStyle(store.theme.primary600)
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .background(store.theme.primaryTint, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("查看记录趋势")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trendsHeader: some View {
        HStack(spacing: 12) {
            Button { setShowingTrends(false) } label: {
                HStack(spacing: 3) {
                    AppIcon.Back(size: 18, color: Palette.ink2)
                    Text("记录")
                        .appFont(size: 13, weight: .semibold)
                }
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(Palette.bg2, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("返回记录流水")

            VStack(alignment: .leading, spacing: 3) {
                Text("趋势")
                    .appText(.pageTitle)
                    .foregroundStyle(Palette.ink)
                Text("查看宝宝最近的照护节奏")
                    .appFont(size: 13, weight: .medium)
                    .foregroundStyle(Palette.ink3)
            }

            Spacer(minLength: 0)
        }
    }

    private func setShowingTrends(_ isShowing: Bool) {
        if reduceMotion {
            showingTrends = isShowing
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                showingTrends = isShowing
            }
        }
    }

    private var timelineList: some View {
        List {
            recordsHeader
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 18, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            filterControls
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let activeState = visibleActiveState {
                ActiveRecordBanner(state: activeState) {
                    onOpen(activeState.destination)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 18, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if groups.isEmpty {
                let emptyTitle = selectedDate == nil ? "还没有记录" : "这天还没有记录"
                let emptySub = selectedDate == nil ? "快回到首页添加第一条小记录吧" : "换一天看看吧"
                EmptyStateView(title: emptyTitle, subtitle: emptySub)
                    .padding(.vertical, 28)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(groups) { group in
                Section {
                    let summary = store.dailySummary(on: group.day)
                    if filter == .all, !summary.isEmpty {
                        DailySummaryText(summary: summary)
                            .padding(.vertical, 10)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, event in
                        RecordsTimelineRow(
                            event: event,
                            isLast: index == group.items.count - 1,
                            onDelete: deleteWithUndo,
                            onEdit: { editing = $0 }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    daySectionHeader(group)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(0)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .background(Palette.bg)
    }

    private var trendsScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                trendsHeader
                    .padding(.bottom, 18)

                StatsDashboardView(range: $statsRange)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(Palette.bg)
    }

    private var visibleActiveState: ActiveCareState? {
        guard let state = store.activeCareState else { return nil }
        guard filter.kind == nil || filter.kind == state.kind else { return nil }
        return state
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                typeFilterMenu

                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 1, height: 24)

                compactDateFilter
            }
            .padding(4)
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            }

            if calendarOpen {
                MonthCalendarExpanded(
                    anchor: $anchor,
                    selectedDate: $selectedDate,
                    events: store.events,
                    onCollapse: { setCalendarOpen(false) }
                )
            }
        }
        .padding(.bottom, 18)
    }

    private var typeFilterMenu: some View {
        let categoryStyle = filter.kind.map { CategoryStyle.forKind($0, iconSize: 17) }
        let ink = categoryStyle?.ink ?? store.theme.primary600

        return Menu {
            ForEach(RecordFilter.allCases, id: \.self) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        filter = option
                    }
                } label: {
                    if filter == option {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                if let categoryStyle {
                    categoryStyle.icon
                        .frame(width: 18, height: 18)
                } else {
                    AppIcon.Book(size: 18, color: ink)
                }
                Text(filter == .all ? "全部类型" : filter.label)
                    .appText(.label)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                AppIcon.Chevron(size: 12, color: Palette.ink3)
                    .rotationEffect(.degrees(90))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("记录类型，\(filter.label)")
    }

    private var compactDateFilter: some View {
        Button {
            setCalendarOpen(!calendarOpen)
        } label: {
            HStack(spacing: 6) {
                AppIcon.Calendar(size: 17, color: store.theme.primary600)
                Text(compactDateLabel)
                    .appText(.label)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                AppIcon.Chevron(size: 12, color: Palette.ink3)
                    .rotationEffect(.degrees(calendarOpen ? -90 : 90))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("日期筛选，\(collapsedLabel)")
        .accessibilityValue(calendarOpen ? "已展开" : "已收起")
    }

    private func setCalendarOpen(_ isOpen: Bool) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            calendarOpen = isOpen
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

    private var compactDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if let selectedDate {
            formatter.dateFormat = "M月d日"
            return formatter.string(from: selectedDate)
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let anchorYear = calendar.component(.year, from: anchor)
        formatter.dateFormat = currentYear == anchorYear ? "M月" : "yyyy年M月"
        return formatter.string(from: anchor)
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

    private func daySectionHeader(_ group: DayGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.label)
                .appText(.sectionTitle)
                .foregroundStyle(Palette.ink)
            Text(groupDateDetail(group.day))
                .appText(.caption)
                .foregroundStyle(Palette.ink3)
            Spacer(minLength: 8)
            Text("\(group.items.count) 条")
                .appText(.captionEmphasis)
                .monospacedDigit()
                .foregroundStyle(Palette.ink3)
        }
        .textCase(nil)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Palette.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func groupDateDetail(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    private func deleteWithUndo(_ event: Event) {
        guard let snapshot = store.deleteEventForUndo(event) else { return }
        undoDismissTask?.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.easeOut(duration: 0.2)) {
            pendingDeletion = snapshot
        }
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                pendingDeletion = nil
            }
        }
    }

    private func undoDeletion() {
        guard let snapshot = pendingDeletion else { return }
        undoDismissTask?.cancel()
        store.restoreDeletedEvent(snapshot)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AppAccessibility.announce("已撤销删除，记录已恢复")
        withAnimation(.easeIn(duration: 0.16)) {
            pendingDeletion = nil
        }
    }
}

private struct ActiveRecordBanner: View {
    let state: ActiveCareState
    let onContinue: () -> Void

    var body: some View {
        let style = CategoryStyle.forKind(state.kind, iconSize: 22)
        Button(action: onContinue) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        CategoryIcon(kind: state.kind, size: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(state.isRunning ? style.ink : Palette.yellowInk)
                                    .frame(width: 7, height: 7)
                                Text(state.isRunning ? "进行中" : "已暂停")
                                    .appText(.captionEmphasis)
                                    .foregroundStyle(state.isRunning ? style.ink : Palette.yellowInk)
                            }
                            Text(state.activityLabel)
                                .appText(.cardTitle)
                                .foregroundStyle(Palette.ink)
                            Text("开始于 \(formatTime(state.startedAt))")
                                .appText(.caption)
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer(minLength: 8)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(formatDur(state.elapsed(at: context.date)))
                            .appFont(size: 24, weight: .black, relativeTo: .title2)
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        HStack(spacing: 5) {
                            Text("继续记录")
                                .appText(.label)
                            AppIcon.Chevron(size: 13, color: style.ink)
                        }
                        .foregroundStyle(style.ink)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(style.tint, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                        .stroke(style.ink.opacity(0.18), lineWidth: 1)
                }
                .appSurface(.elevated)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(state.activityLabel)，\(state.isRunning ? "进行中" : "已暂停")，继续记录")
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
                VStack(spacing: 2) {
                    CategoryIcon(kind: event.kind, size: 40)
                    if !isLast {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(style.ink.opacity(0.16))
                            .frame(width: 2, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
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
                            .padding(.top, 3)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, isLast ? 12 : 0)
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(event)
            } label: {
                Label("删除", systemImage: "trash")
            }

            Button {
                onEdit(event)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(Palette.blueInk)
        }
        .contextMenu {
            Button {
                onEdit(event)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(event)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityHint("轻触编辑，也可向左侧滑编辑或删除")
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
                        .lineLimit(2)
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
        Card(padding: 6) {
            VStack(spacing: 2) {
                header
                HStack(spacing: 2) {
                    ForEach(weekdays, id: \.self) { w in
                        Text(w)
                            .appText(.micro)
                            .foregroundStyle(Palette.ink3)
                            .frame(maxWidth: .infinity)
                            .frame(height: 16)
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
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
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
        return LazyVGrid(columns: columns, spacing: 0) {
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
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                            .fill(
                                isSelected ? store.theme.primary600
                                : isToday ? store.theme.primaryTint
                                : .clear
                            )
                    )
                }
                .buttonStyle(PressableStyle())
            } else {
                Color.clear.frame(height: 28)
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
