import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: MainTab = .home
    @State private var sub: SubScreen? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.bg.ignoresSafeArea()

            Group {
                switch tab {
                case .home:    HomeView(onOpen: { sub = $0 })
                case .records: RecordsView()
                case .growth:  GrowthView(onOpenVaccines: { sub = .vaccine })
                case .stats:   StatsView()
                }
            }
            .padding(.bottom, 72)      // reserve space for the floating tab bar

            AppTabBar(tab: $tab)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
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
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Palette.line, lineWidth: 0.5)
        )
        .shadowSurface()
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
