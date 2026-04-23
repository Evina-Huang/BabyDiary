import SwiftUI

struct FoodListScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var editing: FoodItem? = nil

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
                            foods: observing,
                            onEdit: { editing = $0 }
                        )
                        .padding(.top, 8)
                    }
                    if !safe.isEmpty {
                        FoodSection(
                            title: "安全",
                            dotColor: Palette.mint600,
                            tint: Palette.mintTint,
                            foods: safe,
                            onEdit: { editing = $0 }
                        )
                        .padding(.top, 18)
                    }
                    if !allergic.isEmpty {
                        FoodSection(
                            title: "过敏",
                            dotColor: Color(hex: 0xD44E3A),
                            tint: Color(hex: 0xFFDDD8),
                            foods: allergic,
                            onEdit: { editing = $0 }
                        )
                        .padding(.top, 18)
                    }
                }
            }
        }
        .background(Palette.bg)
        .sheet(item: $editing) { food in
            FoodEditSheet(food: food, onClose: { editing = nil })
                .environment(store)
                .presentationDetents([.medium])
        }
    }
}

// MARK: — Section

private struct FoodSection: View {
    let title: String
    let dotColor: Color
    let tint: Color
    let foods: [FoodItem]
    let onEdit: (FoodItem) -> Void

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
                        FoodRow(food: food, tint: tint, dotColor: dotColor, last: i == foods.count - 1, onEdit: { onEdit(food) })
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
    let onEdit: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        if food.isObservationDue {
            rowContent
        } else {
            Button(action: onEdit) {
                rowContent
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var rowContent: some View {
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

// MARK: — Edit sheet

private struct FoodEditSheet: View {
    let food: FoodItem
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var name: String = ""
    @State private var status: FoodStatus = .observing
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "编辑食物", onBack: onClose)
            ScreenBody {
                VStack(spacing: 18) {
                    FormField(label: "名称") {
                        TextField("食物名称", text: $name)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "状态")
                        SegPill(selection: $status, options: [
                            (.observing, "观察中"),
                            (.safe, "安全"),
                            (.allergic, "过敏"),
                        ])
                    }

                    CTAButton(title: "保存", theme: store.theme) {
                        store.renameFood(food.id, to: name)
                        store.updateFoodStatus(food.id, status)
                        onClose()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button { showDeleteConfirm = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .bold))
                            Text("删除此食物")
                                .font(.system(size: 14, weight: .heavy))
                                .tracking(-0.14)
                        }
                        .foregroundStyle(Color(hex: 0xD44E3A))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0xFFDDD8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.top, 6)
            }
        }
        .background(Palette.bg)
        .onAppear {
            name = food.name
            status = food.status
        }
        .overlay {
            if showDeleteConfirm {
                CustomConfirmDialog(
                    title: "确定删除「\(food.name)」?",
                    message: "删除后食物记录将不可恢复。",
                    confirmLabel: "删除",
                    onConfirm: {
                        store.deleteFood(food.id)
                        onClose()
                    },
                    onCancel: { showDeleteConfirm = false }
                )
            }
        }
    }
}

private struct CustomConfirmDialog: View {
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .tracking(-0.17)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())

                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: 0xD44E3A), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadowCard()
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}

#Preview("食物清单") {
    FoodListScreen(onBack: {})
        .environment(AppStore.preview)
}
