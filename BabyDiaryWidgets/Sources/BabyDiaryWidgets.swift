import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BabyDiaryWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LastFeedWidget()
        SleepLiveActivityWidget()
        FeedLiveActivityWidget()
    }
}

struct LastFeedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BabyDiaryLastFeedWidget", provider: LastFeedProvider()) { entry in
            LastFeedWidgetView(entry: entry)
        }
        .configurationDisplayName("上次喂奶")
        .description("快速查看最近一次喂奶。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct LastFeedEntry: TimelineEntry {
    let date: Date
    let snapshot: BabyDiaryWidgetSnapshot
}

struct LastFeedProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastFeedEntry {
        LastFeedEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastFeedEntry) -> Void) {
        completion(LastFeedEntry(date: Date(), snapshot: BabyDiaryShared.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastFeedEntry>) -> Void) {
        let now = Date()
        let entry = LastFeedEntry(date: now, snapshot: BabyDiaryShared.loadSnapshot())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LastFeedWidgetView: View {
    let entry: LastFeedEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [BDColor.feedTint, Color(hex: 0xFFF8F2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .widgetURL(BabyDiaryShared.deepLink(.feed))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            accessoryInline
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            iconBadge
            Spacer(minLength: 0)
            Text("上次喂奶")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(BDColor.ink2)
            Text(relativeFeedText)
                .font(.system(size: 25, weight: .black))
                .minimumScaleFactor(0.72)
                .foregroundStyle(BDColor.ink)
            detailText
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BDColor.ink3)
                .lineLimit(2)
        }
        .padding(4)
    }

    private var mediumWidget: some View {
        HStack(spacing: 14) {
            iconBadge
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text("上次喂奶")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(BDColor.feedInk)
                Text(relativeFeedText)
                    .font(.system(size: 28, weight: .black))
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(BDColor.ink)
                if let feed = entry.snapshot.lastFeed {
                    Text(feedDetail(feed))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BDColor.ink2)
                        .lineLimit(1)
                    Text(dateLine(feed.occurredAt))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BDColor.ink3)
                } else {
                    Text("保存第一条喂奶记录后会显示在这里")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BDColor.ink3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(4)
    }

    private var accessoryInline: some View {
        Label("喂奶 \(relativeFeedText)", systemImage: "drop.fill")
    }

    private var accessoryCircular: some View {
        VStack(spacing: 2) {
            Image(systemName: "drop.fill")
                .font(.system(size: 16, weight: .bold))
            Text(shortRelativeFeedText)
                .font(.system(size: 12, weight: .black))
                .minimumScaleFactor(0.7)
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("上次喂奶", systemImage: "drop.fill")
                .font(.system(size: 12, weight: .bold))
            Text(relativeFeedText)
                .font(.system(size: 18, weight: .black))
                .minimumScaleFactor(0.8)
            if let feed = entry.snapshot.lastFeed {
                Text(feedDetail(feed))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
        }
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.7))
            Image(systemName: "drop.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BDColor.feedInk)
        }
        .frame(width: 44, height: 44)
    }

    private var detailText: some View {
        Group {
            if let feed = entry.snapshot.lastFeed {
                Text(feedDetail(feed))
            } else {
                Text("暂无喂奶记录")
            }
        }
    }

    private var relativeFeedText: String {
        relativeText(since: entry.snapshot.lastFeed?.occurredAt, now: entry.date)
    }

    private var shortRelativeFeedText: String {
        shortRelativeText(since: entry.snapshot.lastFeed?.occurredAt, now: entry.date)
    }

    private func feedDetail(_ feed: BabyDiaryWidgetEvent) -> String {
        guard let subtitle = feed.subtitle, !subtitle.isEmpty else { return feed.title }
        return "\(feed.title) · \(subtitle)"
    }
}

struct FeedLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BabyDiaryFeedAttributes.self) { context in
            FeedLockView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(hex: 0xFFF4F8))
                .activitySystemActionForegroundColor(BDColor.feedInk)
                .widgetURL(BabyDiaryShared.deepLink(.feed))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(feedTitle(context.state), systemImage: "drop.fill")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(BDColor.feedInk)
                        Text(context.attributes.babyName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FeedElapsedText(state: context.state, size: 20)
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(feedDetail(context.state))
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        Text("开始 \(timeText(context.state.startedAt))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BDColor.feedInk)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 3)
            } compactTrailing: {
                FeedElapsedText(state: context.state, size: 13)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 3)
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(BDColor.feedInk)
            }
            .widgetURL(BabyDiaryShared.deepLink(.feed))
        }
    }
}

struct FeedLockView: View {
    let attributes: BabyDiaryFeedAttributes
    let state: BabyDiaryFeedAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                Image(systemName: "drop.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(BDColor.feedInk)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if state.isRunning {
                        Circle()
                            .fill(BDColor.feedInk)
                            .frame(width: 7, height: 7)
                    }
                    Text(state.isRunning ? "正在喂奶" : "喂奶已暂停")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(BDColor.feedInk)
                }
                FeedElapsedText(state: state, size: 31)
                    .foregroundStyle(BDColor.ink)
                Text("\(attributes.babyName) · \(feedDetail(state))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BDColor.ink2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
    }
}

struct SleepLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BabyDiarySleepAttributes.self) { context in
            SleepLockView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(hex: 0xF7F1FC))
                .activitySystemActionForegroundColor(BDColor.sleepInk)
                .widgetURL(BabyDiaryShared.deepLink(.sleep))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("睡眠中", systemImage: "moon.fill")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(BDColor.sleepInk)
                        Text(context.attributes.babyName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SleepElapsedText(state: context.state, size: 20)
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isRunning ? "正在睡觉" : "已暂停")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text("开始 \(timeText(context.state.startedAt))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BDColor.sleepInk)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 3)
            } compactTrailing: {
                SleepElapsedText(state: context.state, size: 13)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 3)
            } minimal: {
                Image(systemName: "moon.fill")
                    .foregroundStyle(BDColor.sleepInk)
            }
            .widgetURL(BabyDiaryShared.deepLink(.sleep))
        }
    }
}

struct SleepLockView: View {
    let attributes: BabyDiarySleepAttributes
    let state: BabyDiarySleepAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                Image(systemName: "moon.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(BDColor.sleepInk)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if state.isRunning {
                        Circle()
                            .fill(BDColor.sleepInk)
                            .frame(width: 7, height: 7)
                    }
                    Text(state.isRunning ? "正在睡觉" : "睡眠已暂停")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(BDColor.sleepInk)
                }
                SleepElapsedText(state: state, size: 31)
                    .foregroundStyle(BDColor.ink)
                Text("\(attributes.babyName) · \(timeText(state.startedAt)) 开始")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BDColor.ink2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
    }
}

struct FeedElapsedText: View {
    let state: BabyDiaryFeedAttributes.ContentState
    var size: CGFloat

    var body: some View {
        Group {
            if let reference = state.timerReferenceDate {
                Text(reference, style: .timer)
            } else {
                Text(formatDuration(state.accumulated))
            }
        }
        .font(.system(size: size, weight: .black))
        .monospacedDigit()
        .minimumScaleFactor(0.7)
    }
}

struct SleepElapsedText: View {
    let state: BabyDiarySleepAttributes.ContentState
    var size: CGFloat

    var body: some View {
        Group {
            if let reference = state.timerReferenceDate {
                Text(reference, style: .timer)
            } else {
                Text(formatDuration(state.accumulated))
            }
        }
        .font(.system(size: size, weight: .black))
        .monospacedDigit()
        .minimumScaleFactor(0.7)
    }
}

private func feedTitle(_ state: BabyDiaryFeedAttributes.ContentState) -> String {
    switch state.mode {
    case .breast:
        return state.isRunning ? "母乳中" : "母乳暂停"
    case .formula:
        return state.isRunning ? "奶粉中" : "奶粉暂停"
    }
}

private func feedDetail(_ state: BabyDiaryFeedAttributes.ContentState) -> String {
    switch state.mode {
    case .breast:
        let active = state.activeSide == .right ? "右侧" : "左侧"
        let left = shortMinuteText(state.breastLeftDuration)
        let right = shortMinuteText(state.breastRightDuration)
        return "\(active) · 左 \(left) · 右 \(right)"
    case .formula:
        if let milliliters = state.milliliters {
            return "奶粉 · \(milliliters) ml"
        }
        return "奶粉计时"
    }
}

private func shortMinuteText(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int((seconds / 60).rounded()))
    return "\(minutes)分"
}

private enum BDColor {
    static let ink = Color(hex: 0x2B2520)
    static let ink2 = Color(hex: 0x5A4E46)
    static let ink3 = Color(hex: 0x9A8E85)
    static let feedTint = Color(hex: 0xFFD0DC)
    static let feedInk = Color(hex: 0xC26A84)
    static let sleepInk = Color(hex: 0x7C5EB0)
}

private let sampleSnapshot = BabyDiaryWidgetSnapshot(
    updatedAt: Date(),
    babyName: "小宝",
    lastFeed: BabyDiaryWidgetEvent(
        kind: .feed,
        occurredAt: Date().addingTimeInterval(-3 * 60 * 60),
        startedAt: Date().addingTimeInterval(-3 * 60 * 60 - 20 * 60),
        endedAt: Date().addingTimeInterval(-3 * 60 * 60),
        title: "奶粉",
        subtitle: "120 ml"
    ),
    lastSleep: nil,
    lastDiaper: nil,
    activeSleep: nil
)

private func relativeText(since date: Date?, now: Date) -> String {
    guard let date else { return "暂无记录" }
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 { return "刚刚" }
    if seconds < 3600 { return "\(seconds / 60)分钟前" }
    if seconds < 86_400 {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return minutes >= 10 ? "\(hours)小时\(minutes)分前" : "\(hours)小时前"
    }
    return "\(seconds / 86_400)天前"
}

private func shortRelativeText(since date: Date?, now: Date) -> String {
    guard let date else { return "--" }
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 { return "刚刚" }
    if seconds < 3600 { return "\(seconds / 60)分" }
    if seconds < 86_400 { return "\(seconds / 3600)时" }
    return "\(seconds / 86_400)天"
}

private func dateLine(_ date: Date) -> String {
    Calendar.current.isDateInToday(date)
        ? "今天 \(timeText(date))"
        : date.formatted(.dateTime.month(.defaultDigits).day().hour().minute().locale(Locale(identifier: "zh_CN")))
}

private func timeText(_ date: Date) -> String {
    date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "zh_CN")))
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

#Preview(as: .systemSmall) {
    LastFeedWidget()
} timeline: {
    LastFeedEntry(date: Date(), snapshot: sampleSnapshot)
}
