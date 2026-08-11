import SwiftUI

struct FoodListScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var editing: FoodItem? = nil
    @State private var filter: FoodFilter = .all

    private var dueFoods: [FoodItem] {
        store.foods
            .filter(\.isObservationDue)
            .sorted { $0.firstUsedAt < $1.firstUsedAt }
    }

    private var observingFoods: [FoodItem] {
        store.foods.filter { $0.status == .observing && !$0.isObservationDue }
    }

    private var filteredFoods: [FoodItem] {
        store.foods
            .filter(filter.includes)
            .sorted { lhs, rhs in
                let lhsPriority = FoodFilter.priority(for: lhs)
                let rhsPriority = FoodFilter.priority(for: rhs)
                if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
                return lhs.firstUsedAt > rhs.firstUsedAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "食材排敏", onBack: onBack)
            ScreenBody {
                if store.foods.isEmpty {
                    EmptyStateView(
                        title: "还没有食材记录",
                        subtitle: "在辅食记录里添加新食材，这里会自动开始观察"
                    )
                    .padding(.top, 8)
                } else {
                    if !dueFoods.isEmpty {
                        dueSection
                            .padding(.top, 4)
                    }

                    progressOverview
                        .padding(.top, dueFoods.isEmpty ? 4 : 22)

                    foodList
                        .padding(.top, 22)
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

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("需要确认")
                    .appFont(size: 15, weight: .heavy)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(dueFoods.count) 种待处理")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(Palette.yellowInk)
            }

            Card(padding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .fill(Palette.yellow)
                            AppIcon.Bowl(size: 26, color: Palette.yellowInk)
                        }
                        .frame(width: 50, height: 50)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("观察期已经结束")
                                .appText(.cardTitle)
                                .foregroundStyle(Palette.ink)
                            Text("根据这几天的情况，为食材标记最终结果。")
                                .appFont(size: 13, weight: .semibold)
                                .foregroundStyle(Palette.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ForEach(Array(dueFoods.enumerated()), id: \.element.id) { index, food in
                        if index > 0 {
                            Rectangle()
                                .fill(Palette.line)
                                .frame(height: 1)
                        }

                        VStack(alignment: .leading, spacing: 11) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(food.name)
                                    .appFont(size: 16, weight: .heavy)
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Text("已观察 \(food.observationDays) 天")
                                    .appFont(size: 12, weight: .bold)
                                    .foregroundStyle(Palette.ink3)
                            }

                            HStack(spacing: 10) {
                                resultButton(
                                    "确认安全",
                                    background: Palette.mintTint,
                                    foreground: Palette.mint600
                                ) {
                                    withAnimation { store.updateFoodStatus(food.id, .safe) }
                                }

                                resultButton(
                                    "标记过敏",
                                    background: Palette.pink,
                                    foreground: Palette.pinkInk
                                ) {
                                    withAnimation { store.updateFoodStatus(food.id, .allergic) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func resultButton(
        _ title: String,
        background: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(size: 14, weight: .heavy)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(background, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("排敏进度")
                .appFont(size: 15, weight: .heavy)
                .foregroundStyle(Palette.ink)

            Card(padding: 0) {
                HStack(spacing: 0) {
                    statusCount(title: "待确认", count: dueFoods.count, color: Palette.yellowInk)
                    divider
                    statusCount(title: "观察中", count: observingFoods.count, color: Palette.blueInk)
                    divider
                    statusCount(title: "已安全", count: store.foods.filter { $0.status == .safe }.count, color: Palette.mint600)
                    divider
                    statusCount(title: "已过敏", count: store.foods.filter { $0.status == .allergic }.count, color: Palette.pinkInk)
                }
                .padding(.vertical, 17)
            }
        }
    }

    private func statusCount(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Text("\(count)")
                .appFont(size: 20, weight: .black)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .appFont(size: 11, weight: .bold)
                .foregroundStyle(Palette.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 1, height: 34)
    }

    private var foodList: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("全部食材")
                    .appFont(size: 15, weight: .heavy)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("共 \(store.foods.count) 种")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(Palette.ink3)
            }

            filterBar

            if filteredFoods.isEmpty {
                Card {
                    Text("这里还没有食材")
                        .appFont(size: 14, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            } else {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredFoods.enumerated()), id: \.element.id) { index, food in
                            FoodListRow(
                                food: food,
                                last: index == filteredFoods.count - 1,
                                onTap: { editing = food }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 5) {
            ForEach(FoodFilter.allCases) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { filter = option }
                } label: {
                    Text(option.label)
                        .appFont(size: 13, weight: .bold)
                        .foregroundStyle(filter == option ? Palette.ink : Palette.ink3)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if filter == option {
                                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                                    .fill(Palette.card)
                                    .shadowCard()
                            }
                        }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(4)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
    }
}

private enum FoodFilter: String, CaseIterable, Identifiable {
    case all, observing, safe, allergic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "全部"
        case .observing: return "观察"
        case .safe: return "安全"
        case .allergic: return "过敏"
        }
    }

    func includes(_ food: FoodItem) -> Bool {
        switch self {
        case .all: return true
        case .observing: return food.status == .observing
        case .safe: return food.status == .safe
        case .allergic: return food.status == .allergic
        }
    }

    static func priority(for food: FoodItem) -> Int {
        if food.isObservationDue { return 0 }
        switch food.status {
        case .observing: return 1
        case .allergic: return 2
        case .safe: return 3
        }
    }
}

private struct FoodListRow: View {
    let food: FoodItem
    let last: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .appFont(size: 15, weight: .bold)
                            .foregroundStyle(Palette.ink)
                        Text(detailText)
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(status.title)
                        .appFont(size: 12, weight: .heavy)
                        .foregroundStyle(status.foreground)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(status.background, in: Capsule())
                }
                .frame(minHeight: 68)

                if !last {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var status: (title: String, foreground: Color, background: Color) {
        if food.isObservationDue {
            return ("待确认", Palette.yellowInk, Palette.yellow)
        }
        switch food.status {
        case .observing:
            return ("剩 \(food.daysRemaining) 天", Palette.blueInk, Palette.blue)
        case .safe:
            return ("安全", Palette.mint600, Palette.mintTint)
        case .allergic:
            return ("过敏", Palette.pinkInk, Palette.pink)
        }
    }

    private var detailText: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: food.firstUsedAt)
        let day = calendar.component(.day, from: food.firstUsedAt)
        let base = "\(month)月\(day)日首次 · 已吃 \(food.timesEaten) 次"
        if let notes = food.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return "\(base) · \(notes)"
        }
        return base
    }
}

private struct FoodEditSheet: View {
    let food: FoodItem
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var name: String = ""
    @State private var status: FoodStatus = .observing
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "编辑食材", onBack: onClose)
            ScreenBody {
                VStack(spacing: 18) {
                    Card {
                        VStack(spacing: 18) {
                            FormField(label: "食材名称") {
                                TextField("食材名称", text: $name)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                FieldLabel(text: "排敏状态")
                                SegPill(selection: $status, options: [
                                    (.observing, "观察中"),
                                    (.safe, "已安全"),
                                    (.allergic, "已过敏"),
                                ])
                            }
                        }
                    }

                    CTAButton(title: "保存修改", theme: store.theme) {
                        store.renameFood(food.id, to: name)
                        store.updateFoodStatus(food.id, status)
                        onClose()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button { showDeleteConfirm = true } label: {
                        Text("删除此食材")
                            .appFont(size: 14, weight: .heavy)
                            .foregroundStyle(Palette.pinkInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Palette.pink, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.top, 4)
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
                    message: "删除后食材记录将不可恢复。",
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
                    .appFont(size: 17, weight: .heavy)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .appFont(size: 13, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("取消")
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(Palette.ink2)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())

                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Palette.pinkInk, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
            .shadowCard()
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}

#Preview("食材排敏") {
    FoodListScreen(onBack: {})
        .environment(AppStore.preview)
}
