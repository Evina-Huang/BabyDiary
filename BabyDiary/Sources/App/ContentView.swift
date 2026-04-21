import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: MainTab = .home
    @State private var sub: SubScreen? = nil

    var body: some View {
        Group {
            switch tab {
            case .home:    HomeView(onOpen: { sub = $0 })
            case .records: RecordsView()
            case .growth:  GrowthView(onOpen: { sub = $0 })
            case .stats:   StatsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(tab: $tab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $sub) { s in
            subContent(for: s)
                .environment(store)
                .presentationDragIndicator(.hidden)
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
        case .foodList: FoodListScreen(onBack: { sub = nil })
        case .backup:   BackupScreen(onBack:   { sub = nil })
        }
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
            case .stats:   AppIcon.Chart(size: 24, color: c)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppStore.preview)
}
