import SwiftUI
import PhotosUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onOpen: (SubScreen) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(onOpen: onOpen)

            ScreenBody {
                if let activeState = store.activeCareState {
                    ActiveCareCard(state: activeState) {
                        onOpen(activeState.destination)
                    }
                    .padding(.top, 8)
                }

                BabyBadge()
                    .padding(.top, store.activeCareState == nil ? 8 : 12)

                NightQuickEntry {
                    onOpen(.nightQuick)
                }
                .padding(.top, 14)

                HomeSectionHeader(title: "快速记录")
                    .padding(.top, 20)

                let cols = quickActionColumns
                LazyVGrid(columns: cols, spacing: 12) {
                    QuickTile(kind: .sleep,  onTap: { onOpen(.sleep) })
                    QuickTile(kind: .feed,   onTap: { onOpen(.feed) })
                    QuickTile(kind: .diaper, onTap: { onOpen(.diaper) })
                    QuickTile(kind: .solid,  onTap: { onOpen(.solid) })
                }
                .padding(.top, 10)

                DailySummaryStrip().padding(.top, 16)

                VaccineReminderBanner(onOpen: { onOpen(.vaccine) })
                    .padding(.top, 14)

            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Palette.bg)
    }

    private var quickActionColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }
}

private struct HomeSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .appText(.sectionTitle)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NightQuickEntry: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        leadingContent
                        callToAction
                    }
                } else {
                    HStack(spacing: 12) {
                        leadingContent
                        Spacer(minLength: 8)
                        callToAction
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Palette.lavender, store.theme.primaryTint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                    .stroke(Palette.lavenderInk.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("夜间快速记录")
        .accessibilityHint("打开只包含睡眠、喂奶、尿布和辅食的快速记录")
    }

    private var leadingContent: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                    .fill(Palette.card.opacity(0.72))
                AppIcon.Moon(size: 26, color: Palette.lavenderInk)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("夜间快速记录")
                    .appText(.cardTitle)
                    .foregroundStyle(Palette.ink)
                Text("低注意力 · 两步左右完成")
                    .appText(.caption)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var callToAction: some View {
        HStack(spacing: 5) {
            Text("打开")
                .appText(.label)
            AppIcon.Chevron(size: 14, color: Palette.lavenderInk)
        }
        .foregroundStyle(Palette.lavenderInk)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Palette.card.opacity(0.72), in: Capsule())
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
    }
}

private struct HomeHeader: View {
    @Environment(AppStore.self) private var store
    var onOpen: (SubScreen) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dateLine())
                    .appText(.bodyEmphasis)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)

                if let greeting = specialGreeting(for: store.baby) {
                    Text(greeting.text)
                        .appFont(size: 18, weight: .bold)
                        .foregroundStyle(Palette.ink)
                    Text(greeting.detail)
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(store.theme.primary600)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            HStack(spacing: 10) {
                Button { onOpen(.settings) } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.theme.primary600)
                        .frame(width: 44, height: 44)
                        .background(store.theme.primaryTint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("设置")

                Button { onOpen(.backup) } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.theme.primary600)
                        .frame(width: 44, height: 44)
                        .background(store.theme.primaryTint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("数据备份")
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Palette.bg.opacity(0.68))
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            HeaderBottomFade()
                .offset(y: 34)
        }
        .zIndex(1)
    }

    private func dateLine() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }
}

private struct SpecialGreeting {
    let text: String
    let detail: String
}

private func specialGreeting(for baby: Baby) -> SpecialGreeting? {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let birthDate = calendar.startOfDay(for: baby.birthDate)
    let days = max(0, calendar.dateComponents([.day], from: birthDate, to: today).day ?? 0)

    if days > 0, days % 100 == 0 {
        return SpecialGreeting(
            text: "\(baby.name)来到这个世界的第 \(days) 天",
            detail: "值得纪念的一天"
        )
    }

    let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: today)
    if components.day == 0 {
        let months = (components.year ?? 0) * 12 + (components.month ?? 0)
        if months == 12 {
            return SpecialGreeting(text: "\(baby.name)一岁了", detail: "生日快乐")
        }
        if months > 0 {
            return SpecialGreeting(text: "\(baby.name)满 \(months) 个月了", detail: "成长纪念日")
        }
    }

    let birthDay = calendar.dateComponents([.month, .day], from: birthDate)
    let currentDay = calendar.dateComponents([.month, .day], from: today)
    if let years = components.year,
       years >= 1,
       birthDay.month == currentDay.month,
       birthDay.day == currentDay.day {
        return SpecialGreeting(text: "\(baby.name) \(years) 岁了", detail: "生日快乐")
    }

    return nil
}

private struct HeaderBottomFade: View {
    var body: some View {
        LinearGradient(
            colors: [
                Palette.bg.opacity(0.78),
                Palette.bg.opacity(0.32),
                Palette.bg.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 34)
        .allowsHitTesting(false)
    }
}

// MARK: — Baby badge header card

private struct BabyBadge: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = store.baby.avatarData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    BabyAvatar()
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        babyName
                        babyAge
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        babyName
                        babyAge
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Button { editing = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 44, height: 44)
                    .background(Palette.bg2, in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("编辑宝宝资料")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
        .sheet(isPresented: $editing) {
            EditBabyScreen(onClose: { editing = false })
                .environment(store)
        }
    }

    private var babyName: some View {
        Text(store.baby.name)
            .appText(.heroTitle)
            .foregroundStyle(Palette.ink)
            .lineLimit(2)
    }

    private var babyAge: some View {
        Text(store.baby.ageLabel)
            .appText(.captionEmphasis)
            .foregroundStyle(store.theme.primary600)
            .lineLimit(2)
    }
}

private struct BabyAvatar: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(store.theme.primaryTint)
                    .overlay {
                        Circle()
                            .stroke(store.theme.primary600.opacity(0.12), lineWidth: 1)
                    }

                Image(systemName: "person.fill")
                    .font(.system(
                        size: max(19, proxy.size.width * 0.42),
                        weight: .medium
                    ))
                    .foregroundStyle(store.theme.primary600)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: — Quick-action tile

private struct QuickTile: View {
    @Environment(AppStore.self) private var store
    let kind: EventKind
    let onTap: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let style = CategoryStyle.forKind(kind, iconSize: 24)
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                                .fill(Palette.card.opacity(0.72))
                            style.icon
                        }
                        .frame(width: 42, height: 42)
                        Spacer(minLength: 8)
                        AppIcon.Plus(size: 14, color: style.ink)
                            .frame(width: 32, height: 32)
                            .background(Palette.card.opacity(0.62), in: Circle())
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(style.label)
                            .appText(.cardTitle)
                            .foregroundStyle(style.ink)
                        Text(statusText(at: context.date))
                            .appText(.caption)
                            .monospacedDigit()
                            .foregroundStyle(style.ink.opacity(0.78))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                .background(style.tint, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                        .stroke(style.ink.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("记录\(style.label)，\(statusText(at: context.date))")
        }
    }

    private func statusText(at now: Date) -> String {
        if kind == .sleep, let timer = store.activeTimer, timer.kind == .sleep {
            return timer.isRunning ? "正在进行" : "已经暂停"
        }
        if kind == .feed, store.feedDraft?.hasActiveState == true {
            return "正在记录"
        }
        guard let event = store.mostRecentEvent(kind: kind) else {
            return "还没有记录"
        }
        let seconds = max(0, Int(now.timeIntervalSince(event.occurredAt)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "上次 · \(hours)时\(minutes)分前" : "上次 · \(minutes)分前"
    }
}

// MARK: — Priority live status

private struct ActiveCareCard: View {
    let state: ActiveCareState
    let onContinue: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let style = CategoryStyle.forKind(state.kind, iconSize: 26)
            Card(
                padding: 18,
                surfaceStyle: .elevated,
                backgroundColor: style.tint
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                                .fill(Palette.card.opacity(0.72))
                            style.icon
                        }
                        .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                if state.isRunning {
                                    PulseDot(color: style.ink)
                                }
                                Text(state.isRunning ? "进行中" : "已暂停")
                                    .appText(.captionEmphasis)
                                    .foregroundStyle(style.ink)
                            }
                            Text(state.activityLabel)
                                .appText(.heroTitle)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(2)
                            Text("开始于 \(formatTime(state.startedAt))")
                                .appText(.body)
                                .foregroundStyle(Palette.ink2)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 14) {
                            duration(at: ctx.date, ink: style.ink)
                            continueButton(ink: style.ink)
                        }
                    } else {
                        HStack(alignment: .bottom, spacing: 16) {
                            duration(at: ctx.date, ink: style.ink)
                            Spacer(minLength: 0)
                            continueButton(ink: style.ink)
                        }
                    }
                }
            }
        }
    }

    private func duration(at date: Date, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("已持续")
                .appText(.caption)
                .foregroundStyle(Palette.ink2)
            Text(formatDur(state.elapsed(at: date)))
                .appText(.statValue)
                .monospacedDigit()
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func continueButton(ink: Color) -> some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text("继续记录")
                    .appText(.button)
                AppIcon.Chevron(size: 16, color: ink)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 16)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
            .background(Palette.card.opacity(0.78), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("打开\(state.activityLabel)记录")
    }
}

private struct PulseDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on: Bool = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(reduceMotion ? 1 : (on ? 0.4 : 1.0))
            .scaleEffect(reduceMotion ? 1 : (on ? 0.8 : 1.0))
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: on)
            .onAppear { on = !reduceMotion }
    }
}

// MARK: — Daily summary strip (4 tinted pills)

private struct DailySummaryStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let summary = store.dailySummary(on: ctx.date, now: ctx.date)

            Card(padding: 16, cornerRadius: AppRadius.surface, surfaceStyle: .card) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("今天")
                        .appFont(size: 17, weight: .bold)
                        .foregroundStyle(Palette.ink)
                    if dynamicTypeSize.isAccessibilitySize {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                            ],
                            spacing: 12
                        ) {
                            ForEach(summaryItems(summary)) { item in
                                SummaryCell(item: item, grouped: true)
                            }
                        }
                    } else {
                        HStack(spacing: 0) {
                            ForEach(summaryItems(summary)) { item in
                                SummaryCell(item: item, grouped: false)
                            }
                        }
                    }
                }
            }
        }
    }

    private func summaryItems(_ summary: DailyEventSummary) -> [SummaryItem] {
        [
            SummaryItem(label: "睡眠", value: formatDurShort(summary.sleepDuration).replacingOccurrences(of: " ", with: ""), ink: Palette.lavenderInk),
            SummaryItem(label: "喂奶", value: "\(summary.feedCount)次", ink: Palette.pinkInk),
            SummaryItem(label: "尿布", value: "\(summary.diaperCount)次", ink: Palette.blueInk),
            SummaryItem(label: "辅食", value: "\(summary.solidCount)次", ink: Palette.yellowInk),
        ]
    }

    private struct SummaryItem: Identifiable {
        let label: String
        let value: String
        let ink: Color
        var id: String { label }
    }

    private struct SummaryCell: View {
        let item: SummaryItem
        let grouped: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.value)
                    .appFont(size: 16, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(item.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.label)
                    .appFont(size: 11, weight: .medium)
                    .foregroundStyle(Palette.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, grouped ? 10 : 4)
            .padding(.vertical, grouped ? 10 : 0)
            .background(grouped ? Palette.bg2 : .clear, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
        }
    }
}

// MARK: — Since-last row (小字行)

private struct SinceLastRow: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let now = ctx.date
            let lastFeed = store.mostRecentEvent(kind: .feed)
            let lastDiaper = store.mostRecentEvent(kind: .diaper)
            let lastSleepEnd = store.mostRecentEvent(kind: .sleep)
            let sleepItem: (String, String, Color)? = {
                if let timer = store.activeTimer, timer.kind == .sleep {
                    return ("睡眠", timer.isRunning ? "进行中" : "已暂停", Palette.lavenderInk)
                }
                if let event = lastSleepEnd, let endedAt = event.endAt {
                    return ("睡眠", fmt(now.timeIntervalSince(endedAt)), Palette.lavenderInk)
                }
                return nil
            }()

            let items: [(String, String, Color)] = [
                lastFeed.map   { ("喂奶", fmt(now.timeIntervalSince($0.occurredAt)), Palette.pinkInk) },
                sleepItem,
                lastDiaper.map { ("尿布", fmt(now.timeIntervalSince($0.occurredAt)), Palette.blueInk) },
            ].compactMap { $0 }

            if !items.isEmpty {
                HStack(alignment: .center, spacing: 10) {
                    Text("距上次")
                        .appText(.micro)
                    HStack(spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                            HStack(spacing: 4) {
                                Text(it.0)
                                    .appFont(size: 11, weight: .heavy)
                                    .foregroundStyle(it.2)
                                Text(it.1)
                                    .appFont(size: 11, weight: .bold)
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.ink2)
                            }
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Palette.card.opacity(0.72),
                                        in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func fmt(_ s: TimeInterval) -> String {
        let sec = Int(max(0, s))
        let h = sec / 3600
        let m = (sec % 3600) / 60
        return h > 0 ? "\(h)时\(m)分" : "\(m)分"
    }
}

// MARK: — Vaccine reminder banner

private struct VaccineReminderBanner: View {
    @Environment(AppStore.self) private var store
    let onOpen: () -> Void

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let pending = store.vaccines.filter { !$0.done }
        let urgent = pending.filter { v in
            guard let d = v.scheduledDate else { return false }
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: d)).day ?? 0
            return days <= 15   // overdue (negative) or within half a month
        }
        let next = urgent.sorted {
            ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture)
        }.first

        if let v = next {
            let isOverdue = v.status() == .overdue
            let tint: Color = isOverdue ? Palette.dangerTint : Palette.yellow
            let ink: Color = isOverdue ? Palette.dangerInk : Palette.yellowInk
            let kicker: String = isOverdue ? "已逾期" : "即将接种"

            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                            .fill(Palette.card.opacity(0.6))
                        AppIcon.Syringe(size: 22, color: ink)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("疫苗提醒 · \(kicker)")
                            .appText(.micro)
                            .foregroundStyle(ink)
                        Text(v.name)
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(Palette.ink)
                        Text(reminderDetail(for: v))
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                    AppIcon.Chevron(size: 16, color: Palette.ink3)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(tint, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func reminderDetail(for v: Vaccine) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        if let d = v.scheduledDate {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: d)
            ).day ?? 0
            if days < 0 { return "\(v.ageLabel) · 计划 \(f.string(from: d))(已过 \(-days) 天)" }
            if days == 0 { return "\(v.ageLabel) · 就是今天" }
            return "\(v.ageLabel) · 还有 \(days) 天(\(f.string(from: d)))"
        }
        return v.ageLabel
    }
}

// MARK: — Edit baby profile sheet

private struct EditBabyScreen: View {
    @Environment(AppStore.self) private var store
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: BabyGender = .unspecified
    @State private var avatarData: Data? = nil
    @State private var pickerItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "编辑宝宝资料", onBack: onClose)

            ScreenBody {
                VStack(spacing: 18) {
                    avatarPicker
                        .padding(.top, 6)

                    FormField(label: "姓名") {
                        TextField("请输入宝宝姓名", text: $name)
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "出生日期")
                        DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "性别")
                        SegPill(selection: $gender, options: [
                            (.girl, "女宝"),
                            (.boy, "男宝"),
                            (.unspecified, "未设置"),
                        ])
                    }

                    CTAButton(title: "保存", theme: store.theme) {
                        var b = store.baby
                        b.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? b.name : name
                        b.birthDate = birthDate
                        b.gender = gender
                        b.avatarData = avatarData
                        store.updateBaby(b)
                        onClose()
                    }
                    .padding(.top, 6)
                }
            }
        }
        .background(Palette.bg)
        .onAppear {
            name = store.baby.name
            birthDate = store.baby.birthDate
            gender = store.baby.gender
            avatarData = store.baby.avatarData
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    avatarData = data
                }
            }
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let data = avatarData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else {
                            BabyAvatar()
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.card, lineWidth: 3))
                    .shadowCard()

                    ZStack {
                        Circle().fill(store.theme.primary)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 30, height: 30)
                }
                Text("点击更换头像")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(Palette.ink3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview("首页") {
    HomeView(onOpen: { _ in })
        .environment(AppStore.preview)
}
