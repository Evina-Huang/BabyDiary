import SwiftUI

fileprivate enum FloatingDockMetrics {
    static let width: CGFloat = 228
    static let horizontalInset: CGFloat = 18
    static let topInset: CGFloat = 12
    static let bottomInset: CGFloat = 92
    static let estimatedHeight: CGFloat = 64
}

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: MainTab = .home
    @State private var sub: SubScreen? = nil

    var body: some View {
        Group {
            switch tab {
            case .home:    HomeView(onOpen: { sub = $0 })
            case .records: RecordsView(onOpen: { sub = $0 })
            case .growth:  GrowthView(onOpen: { sub = $0 }, onOpenHealth: { tab = .health })
            case .health:  HealthView(
                onOpen: { sub = $0 },
                onOpenGrowth: {
                    sub = nil
                    tab = .growth
                }
            )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .respectReduceMotion()
        .onAppear(perform: registerShortcutHandling)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(tab: $tab)
        }
        .overlay {
            FloatingDockLayer(tab: tab, sub: $sub)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $sub) { s in
            subContent(for: s)
                .environment(store)
                .respectReduceMotion()
                .presentationDragIndicator(s.isQuickRecord ? .visible : .hidden)
        }
        .onOpenURL(perform: openDeepLink)
        .onReceive(NotificationCenter.default.publisher(for: .babyDiaryNotificationDestination)) { notification in
            openNotificationDestination(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .babyDiaryShortcutDestination)) { notification in
            openShortcutDestination(notification)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            registerShortcutHandling()
        }
    }

    @ViewBuilder
    private func subContent(for s: SubScreen) -> some View {
        switch s {
        case .nightQuick:
            NightQuickRecordScreen(onBack: { sub = nil })
                .presentationDetents([.large])
        case .sleep:    SleepScreen(onBack:    { sub = nil })
        case .feed:     FeedScreen(onBack:     { sub = nil })
        case .diaper:   DiaperScreen(onBack:   { sub = nil })
        case .solid:    SolidScreen(onBack:    { sub = nil })
        case .vaccine:  VaccineScreen(onBack:  { sub = nil })
        case .medication: MedicationScreen(onBack: { sub = nil })
        case .foodList: FoodListScreen(onBack: { sub = nil })
        case .recipeList: RecipeListScreen(onBack: { sub = nil })
        case .teeth:    TeethScreen(onBack:    { sub = nil })
        case .settings: SettingsScreen(onBack: { sub = nil })
        case .backup:   BackupScreen(onBack:   { sub = nil })
        }
    }

    private func openDeepLink(_ url: URL) {
        guard url.scheme == "babydiary" else { return }
        if url.host == "theme",
           let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "value" })?.value,
           let theme = AppTheme(rawValue: value) {
            store.updateTheme(theme)
            tab = .home
            sub = nil
            return
        }
        let destination = url.host ?? url.pathComponents.dropFirst().first
        openDestination(destination)
    }

    private func openNotificationDestination(_ notification: Notification) {
        openDestination(notification.userInfo?["destination"] as? String)
    }

    private func openShortcutDestination(_ notification: Notification) {
        _ = BabyDiaryShortcutCoordinator.consumePendingDestination()
        openDestination(notification.userInfo?["destination"] as? String)
    }

    private func registerShortcutHandling() {
        BabyDiaryShortcutCoordinator.register(store)
        openPendingShortcutDestination()
    }

    private func openPendingShortcutDestination() {
        guard let destination = BabyDiaryShortcutCoordinator.consumePendingDestination() else { return }
        _ = store.loadFromDisk()
        openDestination(destination.rawValue)
    }

    private func openDestination(_ destination: String?) {
        switch destination {
        case "night":
            tab = .home
            sub = .nightQuick
        case BabyDiaryDestination.sleep.rawValue:
            sub = .sleep
        case BabyDiaryDestination.feed.rawValue:
            sub = .feed
        case BabyDiaryDestination.solid.rawValue:
            sub = .solid
        case BabyDiaryDestination.diaper.rawValue:
            sub = .diaper
        case BabyDiaryDestination.records.rawValue:
            tab = .records
            sub = nil
        case BabyDiaryDestination.health.rawValue:
            tab = .health
            sub = nil
        case "growth":
            tab = .growth
            sub = nil
        default:
            tab = .home
            sub = nil
        }
    }
}

private struct FloatingDockLayer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: MainTab
    @Binding var sub: SubScreen?
    @State private var dockSide: FloatingDockSide = .right
    @State private var dockY: CGFloat? = nil
    @State private var dockSize: CGSize = .zero
    @State private var suppressDockOpen = false
    @State private var dragStartOrigin: CGPoint? = nil
    @State private var dragOrigin: CGPoint? = nil

    var body: some View {
        GeometryReader { proxy in
            if hasFloatingDock {
                let displayedOrigin = displayedDockOrigin(in: proxy.size)
                let placementSize = effectiveDockSize
                dockContent
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: FloatingDockSizeKey.self, value: geo.size)
                        }
                    )
                    .onPreferenceChange(FloatingDockSizeKey.self) { newSize in
                        syncDockSize(newSize, in: proxy.size)
                    }
                    .contentShape(Rectangle())
                    .position(
                        x: displayedOrigin.x + placementSize.width / 2,
                        y: displayedOrigin.y + placementSize.height / 2
                    )
                    .highPriorityGesture(dockDragGesture(in: proxy.size))
                    .onAppear {
                        clampDockY(in: proxy.size)
                    }
                    .onChange(of: proxy.size) { _, newSize in
                        clampDockY(in: newSize)
                    }
            }
        }
        .allowsHitTesting(hasFloatingDock)
    }

    @ViewBuilder
    private var dockContent: some View {
        switch activeDockState {
        case .feed(let draft):
            ActiveFeedDock(draft: draft,
                           onOpen: {
                               guard !suppressDockOpen else { return }
                               sub = .feed
                           })
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .sleep(let timer):
            ActiveSleepDock(timer: timer,
                            onOpen: {
                                guard !suppressDockOpen else { return }
                                sub = .sleep
                            })
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case nil:
            EmptyView()
        }
    }

    private var hasFloatingDock: Bool {
        activeDockState != nil
    }

    private var activeDockState: ActiveCareState? {
        // Home owns the prominent status card. Keep the dock global on the
        // other tabs without presenting the same action twice on Home.
        guard tab != .home,
              let state = store.activeCareState,
              sub != state.destination else { return nil }
        return state
    }

    private func displayedDockOrigin(in containerSize: CGSize) -> CGPoint {
        clampedDockOrigin(dragOrigin ?? dockOrigin(in: containerSize), in: containerSize)
    }

    private func dockOrigin(in containerSize: CGSize) -> CGPoint {
        clampedDockOrigin(
            CGPoint(
                x: dockSide == .left ? horizontalLimits(in: containerSize).lowerBound : horizontalLimits(in: containerSize).upperBound,
                y: dockY ?? defaultDockOrigin(in: containerSize).y
            ),
            in: containerSize
        )
    }

    private func dockDragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let start = dragStartOrigin ?? dockOrigin(in: containerSize)
                if dragStartOrigin == nil {
                    dragStartOrigin = start
                }
                let nextOrigin = clampedDockOrigin(
                    CGPoint(
                        x: start.x + value.translation.width,
                        y: start.y + value.translation.height
                    ),
                    in: containerSize
                )
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragOrigin = nextOrigin
                }

                if isDockDrag(value.translation), !suppressDockOpen {
                    suppressDockOpen = true
                }
            }
            .onEnded { value in
                let currentOrigin = dragOrigin ?? {
                    let start = dragStartOrigin ?? dockOrigin(in: containerSize)
                    return clampedDockOrigin(
                        CGPoint(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        ),
                        in: containerSize
                    )
                }()
                let snappedSide = snappedDockSide(in: containerSize, origin: currentOrigin)

                dragStartOrigin = nil
                let updateDockPosition = {
                    dockSide = snappedSide
                    dockY = currentOrigin.y
                    dragOrigin = nil
                }
                if reduceMotion {
                    updateDockPosition()
                } else {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88), updateDockPosition)
                }

                if isDockDrag(value.translation) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        suppressDockOpen = false
                    }
                } else {
                    suppressDockOpen = false
                }
        }
    }

    private var effectiveDockSize: CGSize {
        CGSize(
            width: dockSize.width > 0 ? dockSize.width : FloatingDockMetrics.width,
            height: dockSize.height > 0 ? dockSize.height : FloatingDockMetrics.estimatedHeight
        )
    }

    private func isDockDrag(_ translation: CGSize) -> Bool {
        max(abs(translation.width), abs(translation.height)) > 8
    }

    private func syncDockSize(_ newSize: CGSize, in containerSize: CGSize) {
        guard newSize != .zero else { return }
        if dockSize != newSize {
            dockSize = newSize
        }
        guard dragStartOrigin == nil else { return }
        clampDockY(in: containerSize)
    }

    private func clampDockY(in containerSize: CGSize) {
        let nextY = clampedDockOrigin(
            CGPoint(x: 0, y: dockY ?? defaultDockOrigin(in: containerSize).y),
            in: containerSize
        ).y
        guard dockY.map({ abs($0 - nextY) > 0.5 }) ?? true else { return }
        dockY = nextY
    }

    private func defaultDockOrigin(in containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: horizontalLimits(in: containerSize).upperBound,
            y: verticalLimits(in: containerSize).upperBound
        )
    }

    private func clampedDockOrigin(_ origin: CGPoint, in containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(horizontalLimits(in: containerSize).upperBound, max(horizontalLimits(in: containerSize).lowerBound, origin.x)),
            y: min(verticalLimits(in: containerSize).upperBound, max(verticalLimits(in: containerSize).lowerBound, origin.y))
        )
    }

    private func snappedDockSide(in containerSize: CGSize, origin: CGPoint) -> FloatingDockSide {
        let xLimits = horizontalLimits(in: containerSize)
        return origin.x <= (xLimits.lowerBound + xLimits.upperBound) / 2 ? .left : .right
    }

    private func horizontalLimits(in containerSize: CGSize) -> ClosedRange<CGFloat> {
        let minX = FloatingDockMetrics.horizontalInset
        let maxX = max(minX, containerSize.width - effectiveDockSize.width - FloatingDockMetrics.horizontalInset)
        return minX...maxX
    }

    private func verticalLimits(in containerSize: CGSize) -> ClosedRange<CGFloat> {
        let minY = FloatingDockMetrics.topInset
        let maxY = max(minY, containerSize.height - effectiveDockSize.height - FloatingDockMetrics.bottomInset)
        return minY...maxY
    }
}

private enum FloatingDockSide {
    case left
    case right
}

private struct ActiveSleepDock: View {
    let timer: RunningTimer
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            content(at: ctx.date)
        }
    }

    private func content(at date: Date) -> some View {
        let accent = timer.isRunning ? Palette.lavenderInk : Palette.ink2
        let title = timer.isRunning ? "睡觉中" : "已暂停"
        let duration = timer.isRunning ? timer.elapsed(at: date) : timer.accumulated

        return Button(action: onOpen) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                        .fill(Palette.card.opacity(0.78))
                    AppIcon.Moon(size: 20, color: accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if timer.isRunning {
                            DockPulseDot(color: accent)
                        }
                        Text(title)
                            .appFont(size: 12, weight: .bold)
                    }
                    .foregroundStyle(accent)

                    Text(formatDur(duration))
                        .appFont(size: 17, weight: .bold)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }

                Spacer(minLength: 6)

                Text("继续")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 34)
                    .background(Palette.card.opacity(0.78), in: Capsule())
            }
            .padding(.horizontal, 10)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 300 : FloatingDockMetrics.width, alignment: .leading)
            .frame(minHeight: 64)
            .background(Palette.lavender, in: Capsule())
            .overlay {
                Capsule().stroke(Palette.lavenderInk.opacity(0.12), lineWidth: 1)
            }
            .appSurface(.elevated)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title)，\(formatDur(duration))")
        .accessibilityHint("打开睡眠记录")
    }
}

private struct ActiveFeedDock: View {
    let draft: FeedDraft
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            content(at: ctx.date)
        }
    }

    private func content(at date: Date) -> some View {
        let status = feedDockStatus(at: date)

        return Button(action: onOpen) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                        .fill(Palette.card.opacity(0.78))
                    AppIcon.Bottle(size: 20, color: status.ink)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if status.running {
                            DockPulseDot(color: status.ink)
                        }
                        Text(status.title)
                            .appFont(size: 12, weight: .bold)
                    }
                    .foregroundStyle(status.ink)

                    Text(formatDur(status.duration))
                        .appFont(size: 17, weight: .bold)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }

                Spacer(minLength: 6)

                Text("继续")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(status.ink)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 34)
                    .background(Palette.card.opacity(0.78), in: Capsule())
            }
            .padding(.horizontal, 10)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 300 : FloatingDockMetrics.width, alignment: .leading)
            .frame(minHeight: 64)
            .background(Palette.pink, in: Capsule())
            .overlay {
                Capsule().stroke(Palette.pinkInk.opacity(0.12), lineWidth: 1)
            }
            .appSurface(.elevated)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(status.title)，\(formatDur(status.duration))")
        .accessibilityHint("打开喂奶记录")
    }

    private func feedDockStatus(at now: Date) -> (title: String, duration: TimeInterval, running: Bool, ink: Color) {
        if draft.mode == .breast {
            let leftLive = draft.breastPhase == .running &&
                draft.breastActiveSide == .left &&
                draft.breastSegmentStart != nil
                ? draft.breastLeftDuration + now.timeIntervalSince(draft.breastSegmentStart!)
                : draft.breastLeftDuration
            let rightLive = draft.breastPhase == .running &&
                draft.breastActiveSide == .right &&
                draft.breastSegmentStart != nil
                ? draft.breastRightDuration + now.timeIntervalSince(draft.breastSegmentStart!)
                : draft.breastRightDuration
            let running = draft.breastPhase == .running
            return (running ? "母乳中" : "母乳暂停",
                    leftLive + rightLive,
                    running,
                    Palette.pinkInk)
        }

        let live = draft.formulaPhase == .running && draft.formulaSegmentStart != nil
            ? draft.formulaDuration + now.timeIntervalSince(draft.formulaSegmentStart!)
            : draft.formulaDuration
        let running = draft.formulaPhase == .running
        return (running ? "奶粉中" : "奶粉暂停",
                live,
                running,
                Palette.pinkInk)
    }
}

private struct DockPulseDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

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

private struct FloatingDockSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: — Custom frosted tab bar matching .tabbar styling

struct AppTabBar: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var tab: MainTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MainTab.allCases) { t in
                TabButton(tab: t, selected: tab == t, theme: store.theme) {
                    if reduceMotion {
                        tab = t
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { tab = t }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 0.5)
        }
    }

    private struct TabButton: View {
        let tab: MainTab
        let selected: Bool
        let theme: AppTheme
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 3) {
                    icon
                        .frame(width: 52, height: 32)
                        .background(selected ? theme.primaryTint : Color.clear,
                                    in: Capsule())
                    Text(tab.label)
                        .appFont(size: 11, weight: .bold)
                        .foregroundStyle(selected ? theme.primary600 : Palette.ink3)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tab.label)标签")
            .accessibilityValue(selected ? "已选中" : "")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        @ViewBuilder
        private var icon: some View {
            let c = selected ? theme.primary600 : Palette.ink3
            let f = selected ? theme.primaryTint : Color.clear
            switch tab {
            case .home:    AppIcon.Home(size: 24, color: c, fill: f)
            case .records: AppIcon.Book(size: 24, color: c, fill: f)
            case .growth:  AppIcon.Growth(size: 24, color: c, fill: f)
            case .health:  AppIcon.Shield(size: 24, color: c, fill: f)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppStore.preview)
}
