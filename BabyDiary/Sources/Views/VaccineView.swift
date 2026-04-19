import SwiftUI

struct VaccineScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "疫苗记录", onBack: onBack)
            ScreenBody {
                progressHero.padding(.top, 4)

                let upcoming = store.vaccines.filter { !$0.done }
                let completed = store.vaccines.filter { $0.done }

                sectionHeader(title: "待接种", countLabel: "\(upcoming.count) 项",
                              ink: Palette.pinkInk, bg: store.theme.primaryTint)
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    ForEach(upcoming) { v in
                        VaccineCard(vaccine: v) { store.toggleVaccine(v.id) }
                    }
                }
                .padding(.top, 10)

                if !completed.isEmpty {
                    sectionHeader(title: "已完成", countLabel: "\(completed.count) 项",
                                  ink: Palette.mint600, bg: Palette.mintTint)
                        .padding(.top, 24)

                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(completed.enumerated()), id: \.element.id) { i, v in
                                CompletedRow(vaccine: v, last: i == completed.count - 1) {
                                    store.toggleVaccine(v.id)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .background(Palette.bg)
    }

    private var progressHero: some View {
        let completedCount = store.vaccines.filter(\.done).count
        let total = max(store.vaccines.count, 1)
        let pct = Double(completedCount) / Double(total)
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0xDEF3E9), Color(hex: 0xF1FAF5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                        AppIcon.Shield(size: 32, color: Palette.mint600)
                    }
                    .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("接种进度")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(0.72)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.mint600)
                        Text("已完成 \(completedCount) / \(store.vaccines.count)")
                            .font(.system(size: 22, weight: .black))
                            .tracking(-0.44)
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.6))
                        Capsule().fill(Palette.mint600)
                            .frame(width: max(0, geo.size.width * pct))
                    }
                }
                .frame(height: 10)
            }
            .padding(20)
        }
    }

    private func sectionHeader(title: String, countLabel: String,
                               ink: Color, bg: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .tracking(-0.15)
            Text(countLabel)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(ink)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(bg, in: Capsule())
            Spacer()
        }
    }
}

private struct VaccineCard: View {
    let vaccine: Vaccine
    let onToggle: () -> Void

    var body: some View {
        let overdue = vaccine.status == .overdue
        let dueNow  = vaccine.status == .due
        let bg: Color = overdue ? Color(hex: 0xFFE8E0)
                        : dueNow ? Palette.yellow : .white
        let iconBg: Color = overdue ? .white
                        : dueNow ? Color.white.opacity(0.6) : Palette.mintTint
        let iconColor: Color = overdue ? Color(hex: 0xFF7F64)
                        : dueNow ? Palette.yellowInk : Palette.mint600

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(iconBg)
                AppIcon.Syringe(size: 22, color: iconColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(vaccine.name)
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Text("推荐 \(vaccine.age)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ink3)
                    if overdue { tag(text: "已逾期", tint: Color(hex: 0xFF7F64)) }
                    if dueNow  { tag(text: "本月",   tint: Palette.yellowInk) }
                }
            }
            Spacer(minLength: 0)

            Button(action: onToggle) {
                HStack(spacing: 6) {
                    AppIcon.Check(size: 14, color: .white)
                    Text("完成")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(-0.13)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Palette.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Palette.mint600.opacity(0.35), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(16)
        .background(bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadowCard()
    }

    private func tag(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Color.white, in: Capsule())
    }
}

private struct CompletedRow: View {
    let vaccine: Vaccine
    let last: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Palette.mint)
                        AppIcon.Check(size: 18, color: .white)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vaccine.name)
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(-0.15)
                            .foregroundStyle(Palette.ink)
                            .strikethrough(true, color: Palette.ink3)
                        if let dd = vaccine.doneDate {
                            Text("\(vaccine.age) · 已于 \(dd) 接种")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                if !last {
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview("疫苗") {
    VaccineScreen(onBack: {})
        .environment(AppStore.preview)
}
