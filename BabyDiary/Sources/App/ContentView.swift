import SwiftUI

fileprivate enum FloatingDockMetrics {
    static let width: CGFloat = 208
    static let horizontalInset: CGFloat = 18
    static let topInset: CGFloat = 12
    static let bottomInset: CGFloat = 92
}

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: MainTab = .home
    @State private var sub: SubScreen? = nil
    @State private var dockSide: FloatingDockSide = .right
    @State private var dockY: CGFloat? = nil
    @State private var dockSize: CGSize = .zero
    @State private var suppressDockOpen = false
    @GestureState private var dockDragTranslation: CGSize = .zero

    var body: some View {
        Group {
            switch tab {
            case .home:    HomeView(onOpen: { sub = $0 })
            case .records: RecordsView()
            case .growth:  GrowthView(onOpen: { sub = $0 }, onOpenHealth: { tab = .health })
            case .health:  HealthView(onOpen: { sub = $0 })
            case .stats:   StatsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .onAppear(perform: registerShortcutHandling)
        .overlay {
            GeometryReader { proxy in
                if hasFloatingDock {
                    let displayedOrigin = displayedDockOrigin(in: proxy.size)
                    VStack(alignment: .trailing, spacing: 10) {
                        if let feedDraft = store.feedDraft,
                           feedDraft.hasActiveState,
                           sub != .feed {
                            ActiveFeedDock(draft: feedDraft,
                                           theme: store.theme,
                                           onOpen: {
                                               guard !suppressDockOpen else { return }
                                               sub = .feed
                                           },
                                           onClose: { store.syncFeedDraft(nil) })
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        if let timer = store.activeTimer,
                           timer.kind == .sleep,
                           sub != .sleep {
                            ActiveSleepDock(timer: timer,
                                            theme: store.theme,
                                            onOpen: {
                                                guard !suppressDockOpen else { return }
                                                sub = .sleep
                                            },
                                            onClose: { store.stopTimer() })
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: FloatingDockSizeKey.self, value: geo.size)
                        }
                    )
                    .onPreferenceChange(FloatingDockSizeKey.self) { newSize in
                        dockSize = newSize
                        dockY = clampedDockOrigin(
                            CGPoint(x: 0, y: dockY ?? defaultDockOrigin(in: proxy.size).y),
                            in: proxy.size
                        ).y
                    }
                    .offset(x: displayedOrigin.x, y: displayedOrigin.y)
                    .highPriorityGesture(dockDragGesture(in: proxy.size))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .onAppear {
                        dockY = clampedDockOrigin(
                            CGPoint(x: 0, y: dockY ?? defaultDockOrigin(in: proxy.size).y),
                            in: proxy.size
                        ).y
                    }
                    .onChange(of: proxy.size) { _, newSize in
                        dockY = clampedDockOrigin(
                            CGPoint(x: 0, y: dockY ?? defaultDockOrigin(in: newSize).y),
                            in: newSize
                        ).y
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(tab: $tab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $sub) { s in
            subContent(for: s)
                .environment(store)
                .presentationDragIndicator(.hidden)
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
        case .sleep:    SleepScreen(onBack:    { sub = nil })
        case .feed:     FeedScreen(onBack:     { sub = nil })
        case .diaper:   DiaperScreen(onBack:   { sub = nil })
        case .solid:    SolidScreen(onBack:    { sub = nil })
        case .vaccine:  VaccineScreen(onBack:  { sub = nil })
        case .medication: MedicationScreen(onBack: { sub = nil })
        case .foodList: FoodListScreen(onBack: { sub = nil })
        case .teeth:    TeethScreen(onBack:    { sub = nil })
        case .settings: SettingsScreen(onBack: { sub = nil })
        case .backup:   BackupScreen(onBack:   { sub = nil })
        }
    }

    private func openDeepLink(_ url: URL) {
        guard url.scheme == "babydiary" else { return }
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
        case BabyDiaryDestination.sleep.rawValue:
            sub = .sleep
        case BabyDiaryDestination.feed.rawValue:
            sub = .feed
        case BabyDiaryDestination.diaper.rawValue:
            sub = .diaper
        case BabyDiaryDestination.records.rawValue:
            tab = .records
            sub = nil
        default:
            tab = .home
            sub = nil
        }
    }

    private var hasFloatingDock: Bool {
        (store.feedDraft?.hasActiveState == true && sub != .feed) ||
        ((store.activeTimer?.kind == .sleep) && sub != .sleep)
    }

    private func displayedDockOrigin(in containerSize: CGSize) -> CGPoint {
        let base = clampedDockOrigin(
            CGPoint(
                x: dockSide == .left ? horizontalLimits(in: containerSize).lowerBound : horizontalLimits(in: containerSize).upperBound,
                y: dockY ?? defaultDockOrigin(in: containerSize).y
            ),
            in: containerSize
        )
        return clampedDockOrigin(
            CGPoint(x: base.x + dockDragTranslation.width,
                    y: base.y + dockDragTranslation.height),
            in: containerSize
        )
    }

    private func dockDragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($dockDragTranslation) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                if isDockDrag(value.translation) {
                    suppressDockOpen = true
                }
            }
            .onEnded { value in
                let base = clampedDockOrigin(
                    CGPoint(
                        x: dockSide == .left ? horizontalLimits(in: containerSize).lowerBound : horizontalLimits(in: containerSize).upperBound,
                        y: dockY ?? defaultDockOrigin(in: containerSize).y
                    ),
                    in: containerSize
                )
                let clamped = clampedDockOrigin(
                    CGPoint(
                        x: base.x + value.translation.width,
                        y: base.y + value.translation.height
                    ),
                    in: containerSize
                )
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    dockSide = snappedDockSide(in: containerSize, origin: clamped)
                    dockY = clamped.y
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

    private func isDockDrag(_ translation: CGSize) -> Bool {
        max(abs(translation.width), abs(translation.height)) > 8
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
        let maxX = max(minX, containerSize.width - FloatingDockMetrics.width - FloatingDockMetrics.horizontalInset)
        return minX...maxX
    }

    private func verticalLimits(in containerSize: CGSize) -> ClosedRange<CGFloat> {
        let minY = FloatingDockMetrics.topInset
        let maxY = max(minY, containerSize.height - dockSize.height - FloatingDockMetrics.bottomInset)
        return minY...maxY
    }
}

private enum FloatingDockSide {
    case left
    case right
}

private struct ActiveSleepDock: View {
    let timer: RunningTimer
    let theme: AppTheme
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let accent = timer.isRunning ? Palette.lavenderInk : Palette.ink2
            let title = timer.isRunning ? "睡觉中" : "已暂停"
            let duration = timer.isRunning ? timer.elapsed(at: ctx.date) : timer.accumulated

            ZStack(alignment: .topTrailing) {
                Button(action: onOpen) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.65))
                            AppIcon.Moon(size: 18, color: accent)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if timer.isRunning {
                                    DockPulseDot(color: accent)
                                }
                                Text(title)
                                    .font(.system(size: 11, weight: .heavy))
                                    .tracking(0.66)
                                    .textCase(.uppercase)
                            }
                            .foregroundStyle(accent)

                            Text(formatDur(duration))
                                .font(.system(size: 16, weight: .black))
                                .tracking(-0.32)
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                        }

                        Spacer(minLength: 14)
                            .frame(width: 14)
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 36)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [Color(hex: 0xE8DCF7), Color(hex: 0xF7F1FC)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: theme.primary.opacity(0.12), radius: 18, x: 0, y: 10)
                    .frame(width: FloatingDockMetrics.width, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.ink3)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.78), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 7)
                .padding(.trailing, 7)
            }
            .frame(width: FloatingDockMetrics.width, alignment: .leading)
        }
    }
}

private struct ActiveFeedDock: View {
    let draft: FeedDraft
    let theme: AppTheme
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let status = feedDockStatus(at: ctx.date)

            ZStack(alignment: .topTrailing) {
                Button(action: onOpen) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.65))
                            AppIcon.Bottle(size: 18, color: status.ink)
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if status.running {
                                    DockPulseDot(color: status.ink)
                                }
                                Text(status.title)
                                    .font(.system(size: 11, weight: .heavy))
                                    .tracking(0.66)
                                    .textCase(.uppercase)
                            }
                            .foregroundStyle(status.ink)

                            Text(formatDur(status.duration))
                                .font(.system(size: 16, weight: .black))
                                .tracking(-0.32)
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                        }

                        Spacer(minLength: 14)
                            .frame(width: 14)
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 36)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [Color(hex: 0xFDE0EA), Color(hex: 0xFFF4F8)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: theme.primary.opacity(0.12), radius: 18, x: 0, y: 10)
                    .frame(width: FloatingDockMetrics.width, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.ink3)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.78), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 7)
                .padding(.trailing, 7)
            }
            .frame(width: FloatingDockMetrics.width, alignment: .leading)
        }
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
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(on ? 0.4 : 1.0)
            .scaleEffect(on ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
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
    @Binding var tab: MainTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases) { t in
                TabButton(tab: t, selected: tab == t, theme: store.theme) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { tab = t }
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
                        .scaleEffect(selected ? 1.06 : 1.0)
                        .offset(y: selected ? -2 : 0)
                        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)
                    Text(tab.label)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(selected ? theme.primary600 : Palette.ink3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6).padding(.bottom, 2)
            }
            .buttonStyle(.plain)
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
            case .stats:   AppIcon.Chart(size: 24, color: c)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppStore.preview)
}
