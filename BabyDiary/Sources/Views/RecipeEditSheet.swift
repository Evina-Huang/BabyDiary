import SwiftUI

struct RecipeEditSheet: View {
    let original: Recipe?
    let onCancel: () -> Void
    let onSave: (Recipe) -> Void
    let onDelete: ((String) -> Void)?

    @Environment(AppStore.self) private var store

    @State private var name: String
    @State private var foodNames: [String]
    @State private var customInput: String = ""
    @State private var showDeleteConfirm = false

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
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCustomInput: String {
        customInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !foodNames.isEmpty
    }

    private var suggestions: [String] {
        var result: [String] = []
        var seen = Set(foodNames)
        let recordedFoods = store.foods.map(\.name)

        for food in recordedFoods + suggestionPool where seen.insert(food).inserted {
            result.append(food)
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: original == nil ? "新建食谱" : "编辑食谱",
                onBack: onCancel
            )

            ScreenBody {
                recipeInfo
                    .padding(.top, 4)

                ingredientEditor
                    .padding(.top, 22)

                CTAButton(
                    title: original == nil ? "保存食谱" : "保存修改",
                    variant: canSave ? .primary : .ghost,
                    theme: store.theme,
                    action: save
                )
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.55)
                .padding(.top, 20)

                if original != nil, onDelete != nil {
                    Button { showDeleteConfirm = true } label: {
                        Text("删除这个食谱")
                            .appFont(size: 14, weight: .heavy)
                            .foregroundStyle(Palette.pinkInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                Palette.pink,
                                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                            )
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 10)
                }
            }
        }
        .background(Palette.bg)
        .confirmationDialog(
            "确定删除「\(original?.name ?? "这个食谱")」？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除食谱", role: .destructive) {
                guard let id = original?.id, let onDelete else { return }
                onDelete(id)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，但不会影响已经保存的辅食记录。")
        }
    }

    private var recipeInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("食谱信息")
                .appFont(size: 15, weight: .heavy)
                .tracking(-0.15)
                .foregroundStyle(Palette.ink)

            Card {
                FormField(label: "食谱名称") {
                    TextField("例如：南瓜米糊", text: $name)
                }
            }
        }
    }

    private var ingredientEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("食材组合")
                    .appFont(size: 15, weight: .heavy)
                    .tracking(-0.15)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(foodNames.isEmpty ? "至少添加 1 种" : "已选 \(foodNames.count) 种")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(foodNames.isEmpty ? Palette.yellowInk : Palette.ink3)
            }

            Card {
                VStack(alignment: .leading, spacing: 18) {
                    selectedFoods

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "添加其他食材")
                        customInputRow
                    }

                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "从常用食材添加")
                            suggestionChips
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectedFoods: some View {
        if foodNames.isEmpty {
            Text("选择下方食材，或输入一个新的食材名称。")
                .appFont(size: 13, weight: .semibold)
                .foregroundStyle(Palette.ink3)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 16)
                .background(
                    Palette.bg2,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(foodNames.enumerated()), id: \.element) { index, food in
                    HStack(spacing: 12) {
                        Text(food)
                            .appFont(size: 14, weight: .bold)
                            .foregroundStyle(Palette.ink)

                        Spacer(minLength: 0)

                        Button("移除") {
                            withAnimation(.easeOut(duration: 0.16)) {
                                foodNames.removeAll { $0 == food }
                            }
                        }
                        .appFont(size: 12, weight: .heavy)
                        .foregroundStyle(Palette.pinkInk)
                        .frame(minWidth: 52, minHeight: 44)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)

                    if index < foodNames.count - 1 {
                        Rectangle()
                            .fill(Palette.line)
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(
                Palette.bg2,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }

    private var customInputRow: some View {
        HStack(spacing: 8) {
            TextField("输入食材名称", text: $customInput)
                .appFont(size: 16, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .onSubmit(addCustom)

            Button("添加", action: addCustom)
                .appFont(size: 14, weight: .heavy)
                .foregroundStyle(store.theme.primary600)
                .frame(minWidth: 52, minHeight: 44)
                .disabled(trimmedCustomInput.isEmpty)
                .opacity(trimmedCustomInput.isEmpty ? 0.4 : 1)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
        .background(
            Palette.bg2,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var suggestionChips: some View {
        let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(suggestions, id: \.self) { food in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        foodNames.append(food)
                    }
                } label: {
                    Text(food)
                        .appFont(size: 13, weight: .heavy)
                        .tracking(-0.13)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            Palette.bg2,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func addCustom() {
        guard !trimmedCustomInput.isEmpty else { return }
        guard !foodNames.contains(trimmedCustomInput) else {
            customInput = ""
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            foodNames.append(trimmedCustomInput)
        }
        customInput = ""
    }

    private func save() {
        guard canSave else { return }
        if var recipe = original {
            recipe.name = trimmedName
            recipe.foodNames = foodNames
            onSave(recipe)
        } else {
            onSave(Recipe(name: trimmedName, foodNames: foodNames))
        }
    }
}
