import SwiftUI

struct HealthView: View {
    let onOpen: (SubScreen) -> Void
    @Environment(AppStore.self) private var store

    private var latestGrowth: GrowthPoint? {
        store.growth.sorted { $0.ageMonths < $1.ageMonths }.last
    }

    var body: some View {
        VStack(spacing: 0) {
            TabTitleHeader(kicker: "\(store.baby.name) · \(store.baby.ageLabel)",
                           title: "健康")
            ScreenBody {
                latestMeasureCard
                VStack(spacing: 10) {
                    EntryCard(
                        title: "疫苗接种",
                        subtitle: vaccineSubtitle,
                        iconBg: Palette.mintTint,
                        icon: { AppIcon.Shield(size: 24, color: Palette.mint600) },
                        onTap: { onOpen(.vaccine) }
                    )
                    EntryCard(
                        title: "食物与过敏",
                        subtitle: foodSubtitle,
                        iconBg: Palette.yellow,
                        icon: { AppIcon.Bowl(size: 24, color: Palette.yellowInk) },
                        onTap: { onOpen(.foodList) }
                    )
                }
                .padding(.top, 14)
            }
        }
        .background(Palette.bg)
    }

    // MARK: — 最新体检摘要(纯展示)

    @ViewBuilder
    private var latestMeasureCard: some View {
        if let g = latestGrowth {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.mintTint)
                    AppIcon.Growth(size: 24, color: Palette.mint600, fill: .clear)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("最新测量")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.66)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.ink3)
                    Text("\(String(format: "%.1f", g.weightKg)) kg · \(String(format: "%.1f", g.heightCm)) cm")
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(-0.16)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    Text("\(Int(g.ageMonths)) 月龄 · \(isoDate(g.date))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadowCard()
        }
    }

    // MARK: — Subtitles

    private var vaccineSubtitle: String {
        let done = store.vaccines.filter(\.done).count
        let total = store.vaccines.count
        if total == 0 { return "添加接种计划与进度" }

        let upcoming = store.vaccines
            .filter { !$0.done }
            .compactMap { v -> Date? in v.scheduledDate }
            .sorted()
            .first
        if let d = upcoming {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M 月 d 日"
            return "已完成 \(done) / \(total) · 下次 \(f.string(from: d))"
        }
        return "已完成 \(done) / \(total)"
    }

    private var foodSubtitle: String {
        let safe      = store.foods.filter { $0.status == .safe }.count
        let allergic  = store.foods.filter { $0.status == .allergic }.count
        let observing = store.foods.filter { $0.status == .observing }.count
        var parts: [String] = []
        if safe      > 0 { parts.append("已排敏 \(safe)") }
        if allergic  > 0 { parts.append("过敏 \(allergic)") }
        if observing > 0 { parts.append("观察中 \(observing)") }
        return parts.isEmpty ? "暂无记录" : parts.joined(separator: " · ")
    }

    private func isoDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

#Preview("健康") {
    HealthView(onOpen: { _ in })
        .environment(AppStore.preview)
}
