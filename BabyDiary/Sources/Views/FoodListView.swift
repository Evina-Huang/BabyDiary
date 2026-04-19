import SwiftUI

struct FoodListScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "食物清单", onBack: onBack)
            ScreenBody {
                let observing = store.foods.filter { $0.status == .observing }
                let safe      = store.foods.filter { $0.status == .safe }
                let allergic  = store.foods.filter { $0.status == .allergic }

                if store.foods.isEmpty {
                    EmptyStateView(
                        title: "还没有食物记录",
                        subtitle: "在辅食模块记录第一次尝试，自动开始 3 天观察期"
                    )
                } else {
                    if !observing.isEmpty {
                        FoodSection(
                            title: "观察中",
                            dotColor: Palette.yellowInk,
                            tint: Palette.yellow,
                            foods: observing
                        )
                        .padding(.top, 8)
                    }
                    if !safe.isEmpty {
                        FoodSection(
                            title: "安全",
                            dotColor: Palette.mint600,
                            tint: Palette.mintTint,
                            foods: safe
                        )
                        .padding(.top, 18)
                    }
                    if !allergic.isEmpty {
                        FoodSection(
                            title: "过敏",
                            dotColor: Color(hex: 0xD44E3A),
                            tint: Color(hex: 0xFFDDD8),
                            foods: allergic
                        )
                        .padding(.top, 18)
                    }
                }
            }
        }
        .background(Palette.bg)
    }
}

// MARK: — Section

private struct FoodSection: View {
    let title: String
    let dotColor: Color
    let tint: Color
    let foods: [FoodItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.52)
                    .foregroundStyle(Palette.ink2)
                Text("\(foods.count) 种")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 4)

            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(foods.enumerated()), id: \.element.id) { i, food in
                        FoodRow(food: food, tint: tint, dotColor: dotColor, last: i == foods.count - 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

// MARK: — Row

private struct FoodRow: View {
    let food: FoodItem
    let tint: Color
    let dotColor: Color
    let last: Bool
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(dotColor.opacity(food.isObservationDue ? 1 : 0.65))
                    .frame(width: 9, height: 9)

                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    Text(subtext)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                }

                Spacer(minLength: 0)

                badge
            }
            .padding(.vertical, 14)

            if !last {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if food.isObservationDue {
            HStack(spacing: 8) {
                actionButton("安全", bg: Palette.mintTint, fg: Palette.mint600) {
                    withAnimation { store.updateFoodStatus(food.id, .safe) }
                }
                actionButton("过敏", bg: Color(hex: 0xFFDDD8), fg: Color(hex: 0xD44E3A)) {
                    withAnimation { store.updateFoodStatus(food.id, .allergic) }
                }
            }
        } else if food.status == .observing {
            Text("还剩 \(food.daysRemaining) 天")
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.yellowInk)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Palette.yellow, in: Capsule())
        }
    }

    private func actionButton(_ label: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(fg)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(bg, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private var subtext: String {
        let cal = Calendar.current
        let mm = cal.component(.month, from: food.firstUsedAt)
        let dd = cal.component(.day, from: food.firstUsedAt)
        let base = "\(mm)月\(dd)日初次 · 共 \(food.timesEaten) 次"
        if let notes = food.notes, !notes.isEmpty { return "\(base) · \(notes)" }
        return base
    }
}

#Preview("食物清单") {
    FoodListScreen(onBack: {})
        .environment(AppStore.preview)
}
