import SwiftUI

// 新增/编辑食谱。一个食谱 = 名字 + 一组食材名。
struct RecipeEditSheet: View {
    let original: Recipe?
    let onCancel: () -> Void
    let onSave: (Recipe) -> Void
    let onDelete: ((String) -> Void)?

    @Environment(AppStore.self) private var store

    @State private var name: String
    @State private var foodNames: [String]
    @State private var customInput: String = ""

    private let suggestionPool = [
        "米糊", "南瓜泥", "苹果泥", "胡萝卜", "香蕉", "鸡蛋黄",
        "牛肉泥", "三文鱼", "西兰花", "豆腐", "土豆泥", "藕粉"
    ]

    init(
        original: Recipe? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (Recipe) -> Void,
        onDelete: ((String) -> Void)? = nil
    ) {
        self.original = original
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: original?.name ?? "")
        _foodNames = State(initialValue: original?.foodNames ?? [])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !foodNames.isEmpty
    }

    private var suggestions: [String] {
        let known = Set(store.foods.map { $0.name }).union(foodNames)
        let primary = suggestionPool.filter { !known.contains($0) }
        let extras = store.foods.map { $0.name }.filter { !foodNames.contains($0) }
        var combined: [String] = []
        var seen = Set<String>()
        for n in primary + extras where seen.insert(n).inserted {
            combined.append(n)
        }
        return combined
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: original == nil ? "新增食谱" : "编辑食谱",
                         onBack: onCancel)
            ScreenBody {
                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        FormField(label: "食谱名") {
                            TextField("例如：南瓜米糊", text: $name)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "食材")
                            if foodNames.isEmpty {
                                Text("还没有食材，点击下方添加")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.ink3)
                            } else {
                                selectedFoodsCard
                            }
                            customInputRow
                            if !suggestions.isEmpty {
                                Text("常用食材")
                                    .font(.system(size: 11, weight: .heavy))
                                    .tracking(0.66)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Palette.ink3)
                                    .padding(.top, 4)
                                suggestionChips
                            }
                        }
                    }
                }

                CTAButton(title: "保存",
                          variant: canSave ? .primary : .ghost,
                          theme: store.theme,
                          action: save)
                    .padding(.top, 18)
                    .disabled(!canSave)

                if let id = original?.id, let onDelete {
                    Button {
                        onDelete(id)
                    } label: {
                        Text("删除这个食谱")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFF7F64))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 4)
                }

                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .background(Palette.bg)
    }

    private var selectedFoodsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(foodNames.enumerated()), id: \.element) { i, food in
                HStack {
                    Text(food)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            foodNames.removeAll { $0 == food }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.ink3)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                if i < foodNames.count - 1 {
                    Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 16)
                }
            }
        }
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var customInputRow: some View {
        HStack(spacing: 10) {
            TextField("输入其他食材", text: $customInput)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .onSubmit { addCustom() }
            if !customInput.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("添加") { addCustom() }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(store.theme.primary600)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var suggestionChips: some View {
        let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(suggestions, id: \.self) { name in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        foodNames.append(name)
                    }
                } label: {
                    HStack(spacing: 4) {
                        AppIcon.Plus(size: 11, color: Palette.ink2)
                        Text(name)
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(-0.13)
                            .foregroundStyle(Palette.ink2)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Palette.bg2, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func addCustom() {
        let trimmed = customInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !foodNames.contains(trimmed) else {
            customInput = ""
            return
        }
        withAnimation(.easeOut(duration: 0.16)) {
            foodNames.append(trimmed)
        }
        customInput = ""
    }

    private func save() {
        guard canSave else { return }
        if var r = original {
            r.name = trimmedName
            r.foodNames = foodNames
            onSave(r)
        } else {
            onSave(Recipe(name: trimmedName, foodNames: foodNames))
        }
    }
}
