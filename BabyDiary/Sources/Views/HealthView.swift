import SwiftUI

struct HealthView: View {
    let onOpen: (SubScreen) -> Void
    @Environment(AppStore.self) private var store

    private var latestGrowth: GrowthPoint? {
        store.growth.sorted { $0.ageMonths < $1.ageMonths }.last
    }

    private var pendingVaccines: [Vaccine] {
        store.vaccines
            .filter { !$0.done }
            .sorted {
                ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture)
            }
    }

    private var focusVaccine: Vaccine? { pendingVaccines.first }

    private var overdueVaccineCount: Int {
        pendingVaccines.filter { $0.status() == .overdue }.count
    }

    private var dueVaccineCount: Int {
        pendingVaccines.filter { $0.status() == .due }.count
    }

    private var allergyAlertCount: Int {
        store.foods.filter { $0.status == .allergic }.count +
            store.medications.filter { $0.reaction == .allergic }.count
    }

    private var attentionCount: Int {
        overdueVaccineCount + dueVaccineCount + allergyAlertCount
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenBody {
                pageHeader
                    .padding(.bottom, 18)

                vaccineFocusCard

                latestMeasureCard
                    .padding(.top, 12)

                recordsHeader
                    .padding(.top, 24)
                    .padding(.bottom, 10)

                recordDirectory
            }
        }
        .background(Palette.bg)
    }

    private var pageHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("健康")
                    .appFont(size: 28, weight: .bold)
                    .tracking(-0.7)
                    .foregroundStyle(Palette.ink)
                Text("集中查看需要留意的健康事项")
                    .appFont(size: 13, weight: .medium)
                    .foregroundStyle(Palette.ink3)
            }
            Spacer(minLength: 8)
            Text(attentionCount > 0 ? "\(attentionCount) 项需留意" : "暂无待办")
                .appFont(size: 13, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(attentionCount > 0 ? Palette.pinkInk : Palette.mint600)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(attentionCount > 0 ? Palette.pink : Palette.mintTint, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vaccineFocusCard: some View {
        let style = vaccineAttentionStyle
        return Card(padding: 0, onTap: { onOpen(.vaccine) }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(style.tint)
                        AppIcon.Shield(size: 24, color: style.ink)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("接种提醒")
                            .appFont(size: 12, weight: .medium)
                            .foregroundStyle(Palette.ink3)
                        Text(vaccineFocusTitle)
                            .appFont(size: 16, weight: .bold)
                            .tracking(-0.2)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 6)
                    Text(style.label)
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(style.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(style.tint, in: Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Text(vaccineFocusDetail)
                        .appFont(size: 13, weight: .medium)
                        .foregroundStyle(Palette.ink2)
                    Spacer(minLength: 8)
                    Text("查看计划")
                        .appFont(size: 13, weight: .semibold)
                        .foregroundStyle(store.theme.primary600)
                    AppIcon.Chevron(size: 12, color: store.theme.primary600)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            }
        }
    }

    private var vaccineAttentionStyle: (label: String, tint: Color, ink: Color) {
        if store.vaccines.isEmpty {
            return ("未建立", Palette.mintTint, Palette.mint600)
        }
        if overdueVaccineCount > 0 {
            return ("\(overdueVaccineCount) 项逾期", Palette.pink, Palette.pinkInk)
        }
        if dueVaccineCount > 0 {
            return ("近期 \(dueVaccineCount)", Palette.yellow, Palette.yellowInk)
        }
        if pendingVaccines.isEmpty {
            return ("已完成", Palette.mintTint, Palette.mint600)
        }
        return ("已安排", Palette.blue, Palette.blueInk)
    }

    private var vaccineFocusTitle: String {
        if store.vaccines.isEmpty { return "建立宝宝的接种计划" }
        if pendingVaccines.isEmpty { return "当前计划已全部完成" }
        return focusVaccine?.name ?? "查看接种计划"
    }

    private var vaccineFocusDetail: String {
        guard let vaccine = focusVaccine else {
            return store.vaccines.isEmpty ? "添加疫苗和计划接种日期" : vaccineSubtitle
        }
        guard let date = vaccine.scheduledDate else { return vaccine.ageLabel }
        let dateText = shortDate(date)
        switch vaccine.status() {
        case .overdue: return "计划 \(dateText) · 已超过计划日期"
        case .due: return "计划 \(dateText) · 近期接种"
        case .upcoming: return "计划 \(dateText) · \(vaccine.ageLabel)"
        case .done: return "已完成"
        }
    }

    private var latestMeasureCard: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("最近测量")
                        .appFont(size: 15, weight: .bold)
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Text(latestMeasureDateLabel)
                        .appFont(size: 12, weight: .medium)
                        .foregroundStyle(Palette.ink3)
                }

                HStack(spacing: 10) {
                    measureCell(
                        label: "体重",
                        value: latestGrowth.map { String(format: "%.1f", $0.weightKg) } ?? "—",
                        unit: "kg",
                        tint: Palette.pink,
                        ink: Palette.pinkInk
                    )
                    measureCell(
                        label: "身高",
                        value: latestGrowth.map { String(format: "%.1f", $0.heightCm) } ?? "—",
                        unit: "cm",
                        tint: Palette.blue,
                        ink: Palette.blueInk
                    )
                }
            }
        }
    }

    private func measureCell(
        label: String,
        value: String,
        unit: String,
        tint: Color,
        ink: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .appFont(size: 11, weight: .medium)
                .foregroundStyle(ink)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .appFont(size: 22, weight: .bold)
                    .tracking(-0.45)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(unit)
                    .appFont(size: 11, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var latestMeasureDateLabel: String {
        guard let latestGrowth else { return "还没有记录" }
        return "\(formatDateLabel(latestGrowth.date)) · \(Int(latestGrowth.ageMonths)) 月龄"
    }

    private var recordsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("健康记录")
                .appFont(size: 16, weight: .bold)
                .tracking(-0.2)
                .foregroundStyle(Palette.ink)
            Spacer()
            Text("3 个入口")
                .appFont(size: 12, weight: .medium)
                .foregroundStyle(Palette.ink3)
        }
    }

    private var recordDirectory: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                healthRecordRow(
                    title: "用药记录",
                    subtitle: medicationSubtitle,
                    tint: Palette.blue,
                    icon: { AppIcon.Pill(size: 21, color: Palette.blueInk) },
                    onTap: { onOpen(.medication) }
                )
                directoryDivider
                healthRecordRow(
                    title: "食物与过敏",
                    subtitle: foodSubtitle,
                    tint: Palette.yellow,
                    icon: { AppIcon.Bowl(size: 21, color: Palette.yellowInk) },
                    onTap: { onOpen(.foodList) }
                )
                directoryDivider
                healthRecordRow(
                    title: "我的食谱",
                    subtitle: recipeSubtitle,
                    tint: Palette.pink,
                    icon: { AppIcon.Bowl(size: 21, color: Palette.pinkInk) },
                    onTap: { onOpen(.recipeList) }
                )
            }
        }
    }

    private func healthRecordRow<Icon: View>(
        title: String,
        subtitle: String,
        tint: Color,
        @ViewBuilder icon: () -> Icon,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint)
                    icon()
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .appFont(size: 15, weight: .semibold)
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .appFont(size: 12, weight: .medium)
                        .foregroundStyle(Palette.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                AppIcon.Chevron(size: 14, color: Palette.ink3)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var directoryDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 1)
            .padding(.leading, 68)
    }

    // MARK: — Subtitles

    private var vaccineSubtitle: String {
        let done = store.vaccines.filter(\.done).count
        let total = store.vaccines.count
        if total == 0 { return "添加接种计划与进度" }
        return "已完成 \(done) / \(total)"
    }

    private var foodSubtitle: String {
        let safe = store.foods.filter { $0.status == .safe }.count
        let allergic = store.foods.filter { $0.status == .allergic }.count
        let observing = store.foods.filter { $0.status == .observing }.count
        var parts: [String] = []
        if safe > 0 { parts.append("已排敏 \(safe)") }
        if allergic > 0 { parts.append("过敏 \(allergic)") }
        if observing > 0 { parts.append("观察中 \(observing)") }
        return parts.isEmpty ? "暂无记录" : parts.joined(separator: " · ")
    }

    private var recipeSubtitle: String {
        let count = store.recipes.count
        return count == 0 ? "组合常用食材，快速记录辅食" : "\(count) 个食谱"
    }

    private var medicationSubtitle: String {
        let total = store.medications.count
        let allergic = store.medications.filter { $0.reaction == .allergic }.count
        guard total > 0 else { return "记录药名、剂量与用药反应" }
        if allergic > 0 { return "\(total) 条记录 · 疑似过敏 \(allergic)" }
        return "\(total) 条记录 · 暂无药物过敏"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

#Preview("健康") {
    HealthView(onOpen: { _ in })
        .environment(AppStore.preview)
}
