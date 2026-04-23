import AppIntents
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
        AppIntentConfiguration(
            kind: "BabyDiaryLastFeedWidget",
            intent: BabyDiaryWidgetConfigurationIntent.self,
            provider: LastFeedProvider()
        ) { entry in
            LastFeedWidgetView(entry: entry)
        }
        .configurationDisplayName("喂奶与睡眠")
        .description("自定义查看宝宝最近记录。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

enum BabyDiaryWidgetModule: String, AppEnum, CaseIterable {
    case feed
    case sleep
    case diaper
    case activeSleep
    case activeFeed

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "模块")
    static var caseDisplayRepresentations: [BabyDiaryWidgetModule: DisplayRepresentation] = [
        .feed: "上次喂奶",
        .sleep: "上次睡眠",
        .diaper: "上次尿布",
        .activeSleep: "睡眠计时",
        .activeFeed: "喂奶计时"
    ]
}

struct BabyDiaryWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "显示内容"
    static var description = IntentDescription("选择小组件显示的模块。")

    @Parameter(title: "第一项", default: BabyDiaryWidgetModule.feed)
    var firstModule: BabyDiaryWidgetModule

    @Parameter(title: "第二项", default: BabyDiaryWidgetModule.sleep)
    var secondModule: BabyDiaryWidgetModule

    @Parameter(title: "第三项", default: BabyDiaryWidgetModule.diaper)
    var thirdModule: BabyDiaryWidgetModule

    static var parameterSummary: some ParameterSummary {
        Switch(.widgetFamily) {
            Case(.systemLarge) {
                Summary {
                    \.$firstModule
                    \.$secondModule
                    \.$thirdModule
                }
            }
            Case(.systemMedium) {
                Summary {
                    \.$firstModule
                    \.$secondModule
                }
            }
            DefaultCase {
                Summary {
                    \.$firstModule
                }
            }
        }
    }

    static var defaultConfiguration: BabyDiaryWidgetConfigurationIntent {
        BabyDiaryWidgetConfigurationIntent()
    }
}

struct LastFeedEntry: TimelineEntry {
    let date: Date
    let snapshot: BabyDiaryWidgetSnapshot
    let configuration: BabyDiaryWidgetConfigurationIntent

    init(
        date: Date,
        snapshot: BabyDiaryWidgetSnapshot,
        configuration: BabyDiaryWidgetConfigurationIntent = .defaultConfiguration
    ) {
        self.date = date
        self.snapshot = snapshot
        self.configuration = configuration
    }
}

struct LastFeedProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LastFeedEntry {
        LastFeedEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func snapshot(
        for configuration: BabyDiaryWidgetConfigurationIntent,
        in context: Context
    ) async -> LastFeedEntry {
        LastFeedEntry(date: Date(), snapshot: BabyDiaryShared.loadSnapshot(), configuration: configuration)
    }

    func timeline(
        for configuration: BabyDiaryWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<LastFeedEntry> {
        let now = Date()
        let entry = LastFeedEntry(date: now, snapshot: BabyDiaryShared.loadSnapshot(), configuration: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
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
            .widgetURL(defaultWidgetURL)
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
        case .systemLarge:
            largeWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        let item = primaryModuleContent
        return VStack(alignment: .leading, spacing: 8) {
            iconBadge(for: item)
            Spacer(minLength: 0)
            Text(item.title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(item.tint)
                .lineLimit(1)
            moduleValue(item, size: 25, minimumScale: 0.72)
            Text(item.detail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BDColor.ink3)
                .lineLimit(2)
        }
        .padding(4)
    }

    private var mediumWidget: some View {
        HStack(spacing: 10) {
            ForEach(Array(configuredModules.prefix(2))) { item in
                moduleTile(for: item.module)
            }
        }
        .padding(4)
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                    Image(systemName: "heart.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(BDColor.feedInk)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.snapshot.babyName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(BDColor.ink)
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 10) {
                ForEach(configuredModules) { item in
                    moduleRow(for: item.module)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(4)
    }

    private var accessoryInline: some View {
        let item = primaryModuleContent
        return Label {
            inlineValue(item)
        } icon: {
            Image(systemName: item.systemImage)
        }
    }

    private var accessoryCircular: some View {
        let item = primaryModuleContent
        return VStack(spacing: 2) {
            Image(systemName: item.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(item.tint)
            shortValue(item)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(BDColor.ink)
                .minimumScaleFactor(0.7)
        }
    }

    private var accessoryRectangular: some View {
        let item = primaryModuleContent
        return VStack(alignment: .leading, spacing: 2) {
            Label(item.title, systemImage: item.systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(item.tint)
            shortValue(item)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(BDColor.ink)
                .minimumScaleFactor(0.8)
            Text(item.detail)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BDColor.ink2)
                .lineLimit(1)
        }
    }

    private func iconBadge(for item: WidgetModuleContent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.7))
            Image(systemName: item.systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(item.tint)
        }
        .frame(width: 44, height: 44)
    }

    private var defaultWidgetURL: URL? {
        switch family {
        case .systemLarge:
            BabyDiaryShared.deepLink(.home)
        case .systemMedium:
            nil
        default:
            BabyDiaryShared.deepLink(primaryModule.destination)
        }
    }

    private var primaryModule: BabyDiaryWidgetModule {
        entry.configuration.firstModule
    }

    private var primaryModuleContent: WidgetModuleContent {
        moduleContent(for: primaryModule)
    }

    private var configuredModules: [ConfiguredModule] {
        [
            ConfiguredModule(slot: 0, module: entry.configuration.firstModule),
            ConfiguredModule(slot: 1, module: entry.configuration.secondModule),
            ConfiguredModule(slot: 2, module: entry.configuration.thirdModule)
        ]
    }

    @ViewBuilder
    private func moduleTile(for module: BabyDiaryWidgetModule) -> some View {
        let item = moduleContent(for: module)
        if let url = BabyDiaryShared.deepLink(module.destination) {
            Link(destination: url) {
                summaryTile(item)
            }
        } else {
            summaryTile(item)
        }
    }

    @ViewBuilder
    private func moduleRow(for module: BabyDiaryWidgetModule) -> some View {
        let item = moduleContent(for: module)
        if let url = BabyDiaryShared.deepLink(module.destination) {
            Link(destination: url) {
                summaryRow(item)
            }
        } else {
            summaryRow(item)
        }
    }

    private func summaryTile(_ item: WidgetModuleContent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(item.tint)
                Text(item.title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(item.tint)
                    .lineLimit(1)
            }

            moduleValue(item, size: 22, minimumScale: 0.68)

            Text(item.detail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BDColor.ink2)
                .lineLimit(1)

            if let date = item.date {
                Text(date)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BDColor.ink3)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryRow(_ item: WidgetModuleContent) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(item.tint.opacity(0.16))
                Image(systemName: item.systemImage)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(item.tint)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(item.tint)
                    .lineLimit(1)
                moduleValue(item, text: item.rowValue ?? item.value, size: 26, minimumScale: 0.72)
                Text(item.detail)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BDColor.ink2)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            if let date = item.date {
                Text(date)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(BDColor.ink3)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 76, alignment: .trailing)
            }
        }
        .padding(13)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func moduleValue(
        _ item: WidgetModuleContent,
        text: String? = nil,
        size: CGFloat,
        minimumScale: CGFloat
    ) -> some View {
        Group {
            if let referenceDate = item.timerReferenceDate {
                Text(referenceDate, style: .timer)
            } else {
                Text(text ?? item.value)
            }
        }
        .font(.system(size: size, weight: .black))
        .fontWidth(.compressed)
        .foregroundStyle(BDColor.ink)
        .monospacedDigit()
        .minimumScaleFactor(minimumScale)
        .lineLimit(1)
    }

    @ViewBuilder
    private func inlineValue(_ item: WidgetModuleContent) -> some View {
        if let referenceDate = item.timerReferenceDate {
            Text(referenceDate, style: .timer)
        } else {
            Text("\(item.title) \(shortValueText(for: item))")
        }
    }

    @ViewBuilder
    private func shortValue(_ item: WidgetModuleContent) -> some View {
        if let referenceDate = item.timerReferenceDate {
            Text(referenceDate, style: .timer)
        } else {
            Text(shortValueText(for: item))
        }
    }

    private func shortValueText(for item: WidgetModuleContent) -> String {
        if item.title.contains("计时"), let first = item.value.split(separator: ":").first {
            return String(first)
        }
        return item.value
    }

    private func moduleContent(for module: BabyDiaryWidgetModule) -> WidgetModuleContent {
        switch module {
        case .feed:
            return eventContent(
                module: module,
                event: entry.snapshot.lastFeed,
                empty: "暂无喂奶记录"
            )
        case .sleep:
            return eventContent(
                module: module,
                event: entry.snapshot.lastSleep,
                empty: "暂无睡眠记录"
            )
        case .diaper:
            return eventContent(
                module: module,
                event: entry.snapshot.lastDiaper,
                empty: "暂无尿布记录"
            )
        case .activeSleep:
            guard let activeSleep = entry.snapshot.activeSleep else {
                return WidgetModuleContent(
                    title: module.title,
                    systemImage: module.systemImage,
                    tint: module.tint,
                    value: "暂无计时",
                    rowValue: "暂无计时",
                    detail: "没有进行中的睡眠",
                    timerReferenceDate: nil,
                    date: nil
                )
            }
            return WidgetModuleContent(
                title: module.title,
                systemImage: module.systemImage,
                tint: module.tint,
                value: formatDuration(activeSleep.elapsed(at: entry.date)),
                rowValue: nil,
                detail: activeSleep.isRunning ? "正在睡觉" : "睡眠已暂停",
                timerReferenceDate: activeSleep.timerReferenceDate,
                date: "开始 \(timeText(activeSleep.startedAt))"
            )
        case .activeFeed:
            guard let activeFeed = entry.snapshot.activeFeed else {
                return WidgetModuleContent(
                    title: module.title,
                    systemImage: module.systemImage,
                    tint: module.tint,
                    value: "暂无计时",
                    rowValue: "暂无计时",
                    detail: "没有进行中的喂奶",
                    timerReferenceDate: nil,
                    date: nil
                )
            }
            return WidgetModuleContent(
                title: module.title,
                systemImage: module.systemImage,
                tint: module.tint,
                value: formatDuration(activeFeed.elapsed(at: entry.date)),
                rowValue: nil,
                detail: feedTitle(activeFeed),
                timerReferenceDate: activeFeed.timerReferenceDate,
                date: "开始 \(timeText(activeFeed.startedAt))"
            )
        }
    }

    private func eventContent(
        module: BabyDiaryWidgetModule,
        event: BabyDiaryWidgetEvent?,
        empty: String
    ) -> WidgetModuleContent {
        WidgetModuleContent(
            title: module.title,
            systemImage: module.systemImage,
            tint: module.tint,
            value: relativeText(since: event?.occurredAt, now: entry.date),
            rowValue: condensedRelativeText(since: event?.occurredAt, now: entry.date),
            detail: event.map(eventDetail) ?? empty,
            timerReferenceDate: nil,
            date: event.map { dateLine($0.occurredAt) }
        )
    }

    private func eventDetail(_ event: BabyDiaryWidgetEvent) -> String {
        if event.kind == .sleep {
            return event.title
        }
        guard let subtitle = event.subtitle, !subtitle.isEmpty else { return event.title }
        return "\(event.title) · \(subtitle)"
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
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BDColor.feedInk)
            } compactTrailing: {
                CompactDynamicIslandTimer(
                    referenceDate: context.state.timerReferenceDate,
                    accumulated: context.state.accumulated,
                    tint: BDColor.feedInk
                )
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
            } compactLeading: {
                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BDColor.sleepInk)
            } compactTrailing: {
                CompactDynamicIslandTimer(
                    referenceDate: context.state.timerReferenceDate,
                    accumulated: context.state.accumulated,
                    tint: BDColor.sleepInk
                )
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

private struct CompactDynamicIslandTimer: View {
    let referenceDate: Date?
    let accumulated: TimeInterval
    let tint: Color

    var body: some View {
        Group {
            if let referenceDate {
                Text(referenceDate, style: .timer)
            } else {
                Text(formatDuration(accumulated))
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .fontWidth(.compressed)
        .monospacedDigit()
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.45)
        .frame(width: 42, alignment: .trailing)
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
    static let diaperInk = Color(hex: 0x5598D6)
}

private struct WidgetModuleContent {
    let title: String
    let systemImage: String
    let tint: Color
    let value: String
    let rowValue: String?
    let detail: String
    let timerReferenceDate: Date?
    let date: String?
}

private struct ConfiguredModule: Identifiable {
    let slot: Int
    let module: BabyDiaryWidgetModule

    var id: String {
        "\(slot)-\(module.rawValue)"
    }
}

private extension BabyDiaryWidgetModule {
    var title: String {
        switch self {
        case .feed: return "上次喂奶"
        case .sleep: return "上次睡眠"
        case .diaper: return "上次尿布"
        case .activeSleep: return "睡眠计时"
        case .activeFeed: return "喂奶计时"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: return "drop.fill"
        case .sleep: return "moon.fill"
        case .diaper: return "wind"
        case .activeSleep: return "timer"
        case .activeFeed: return "timer"
        }
    }

    var tint: Color {
        switch self {
        case .feed, .activeFeed: return BDColor.feedInk
        case .sleep, .activeSleep: return BDColor.sleepInk
        case .diaper: return BDColor.diaperInk
        }
    }

    var destination: BabyDiaryDestination {
        switch self {
        case .feed, .activeFeed:
            return .feed
        case .sleep, .activeSleep:
            return .sleep
        case .diaper:
            return .diaper
        }
    }
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
    lastSleep: BabyDiaryWidgetEvent(
        kind: .sleep,
        occurredAt: Date().addingTimeInterval(-90 * 60),
        startedAt: Date().addingTimeInterval(-3 * 60 * 60),
        endedAt: Date().addingTimeInterval(-90 * 60),
        title: "睡眠 1时30分",
        subtitle: "13:10 - 14:40"
    ),
    lastDiaper: BabyDiaryWidgetEvent(
        kind: .diaper,
        occurredAt: Date().addingTimeInterval(-40 * 60),
        startedAt: Date().addingTimeInterval(-40 * 60),
        endedAt: nil,
        title: "尿布",
        subtitle: "小便"
    ),
    activeSleep: BabyDiaryWidgetSleepTimer(
        startedAt: Date().addingTimeInterval(-50 * 60),
        accumulated: 20 * 60,
        resumedAt: Date().addingTimeInterval(-30 * 60)
    ),
    activeFeed: BabyDiaryFeedAttributes.ContentState(
        mode: .breast,
        startedAt: Date().addingTimeInterval(-18 * 60),
        accumulated: 9 * 60,
        resumedAt: Date().addingTimeInterval(-9 * 60),
        updatedAt: Date(),
        activeSide: .right,
        breastLeftDuration: 5 * 60,
        breastRightDuration: 4 * 60,
        milliliters: nil
    )
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

private func condensedRelativeText(since date: Date?, now: Date) -> String {
    guard let date else { return "暂无记录" }
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 { return "刚刚" }
    if seconds < 3600 { return "\(seconds / 60)分前" }
    if seconds < 86_400 {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return minutes >= 10 ? "\(hours)时\(minutes)分前" : "\(hours)小时前"
    }
    return "\(seconds / 86_400)天前"
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

#Preview(as: .systemMedium) {
    LastFeedWidget()
} timeline: {
    LastFeedEntry(date: Date(), snapshot: sampleSnapshot)
}

#Preview(as: .systemLarge) {
    LastFeedWidget()
} timeline: {
    LastFeedEntry(date: Date(), snapshot: sampleSnapshot)
}
