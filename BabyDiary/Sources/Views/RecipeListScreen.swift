import SwiftUI

struct RecipeListScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var editing: RecipeEditTarget? = nil

    private var recipes: [Recipe] {
        store.recipes.sorted { $0.createdAt > $1.createdAt }
    }

    private var uniqueFoodCount: Int {
        Set(store.recipes.flatMap(\.foodNames)).count
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "我的食谱", onBack: onBack)
            ScreenBody {
                overview
                    .padding(.top, 4)

                newRecipeButton
                    .padding(.top, 14)

                recipeCollection
                    .padding(.top, 22)
            }
        }
        .background(Palette.bg)
        .sheet(item: $editing) { target in
            RecipeEditSheet(
                original: target.recipe,
                onCancel: { editing = nil },
                onSave: { recipe in
                    if target.recipe == nil {
                        store.addRecipe(recipe)
                    } else {
                        store.updateRecipe(recipe)
                    }
                    editing = nil
                },
                onDelete: target.recipe == nil ? nil : { id in
                    store.deleteRecipe(id)
                    editing = nil
                }
            )
            .environment(store)
            .presentationDetents([.large])
        }
    }

    private var overview: some View {
        Card(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(Palette.yellow)
                    AppIcon.Bowl(size: 26, color: Palette.yellowInk)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.recipes.isEmpty ? "把常吃的食材存成组合" : "已保存 \(store.recipes.count) 个食谱")
                        .appText(.cardTitle)
                        .foregroundStyle(Palette.ink)

                    Text(overviewDescription)
                        .appFont(size: 13, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var overviewDescription: String {
        if store.recipes.isEmpty {
            return "记录辅食时可一键带入，不用重复选择食材。"
        }
        return "共整理 \(uniqueFoodCount) 种食材，记录辅食时可一键带入。"
    }

    private var newRecipeButton: some View {
        Button {
            editing = RecipeEditTarget(recipe: nil)
        } label: {
            HStack(spacing: 8) {
                AppIcon.Plus(size: 18, color: .white)
                Text("新建食谱")
                    .appFont(size: 15, weight: .heavy)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                store.theme.primary,
                in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
            )
            .shadowPill(tint: store.theme.primary600)
        }
        .buttonStyle(PressableStyle())
    }

    private var recipeCollection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("常用组合")
                    .appFont(size: 15, weight: .heavy)
                    .foregroundStyle(Palette.ink)

                Spacer()

                if !recipes.isEmpty {
                    Text("共 \(recipes.count) 个")
                        .appFont(size: 12, weight: .bold)
                        .foregroundStyle(Palette.ink3)
                }
            }

            if recipes.isEmpty {
                EmptyStateView(
                    title: "还没有食谱",
                    subtitle: "把常一起吃的食材组合起来，下次记录会更快"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(recipes) { recipe in
                        RecipeCard(
                            recipe: recipe,
                            theme: store.theme,
                            onEdit: { editing = RecipeEditTarget(recipe: recipe) }
                        )
                    }
                }
            }
        }
    }
}

struct RecipeEditTarget: Identifiable {
    let recipe: Recipe?
    var id: String { recipe?.id ?? "__new__" }
}

private struct RecipeCard: View {
    let recipe: Recipe
    let theme: AppTheme
    let onEdit: () -> Void

    var body: some View {
        Card(padding: 18, onTap: onEdit) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(recipe.name)
                        .appText(.cardTitle)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(recipe.foodNames.count) 种食材")
                        .appFont(size: 12, weight: .heavy)
                        .monospacedDigit()
                        .foregroundStyle(theme.primary600)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(theme.primaryTint, in: Capsule())
                }

                Text(foodPreview)
                    .appFont(size: 13, weight: .semibold)
                    .foregroundStyle(Palette.ink2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline) {
                    Text(createdLabel)
                        .appFont(size: 11, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                    Spacer()
                    Text("轻触编辑")
                        .appFont(size: 11, weight: .bold)
                        .foregroundStyle(Palette.ink3)
                }
            }
        }
    }

    private var foodPreview: String {
        recipe.foodNames.joined(separator: "  ·  ")
    }

    private var createdLabel: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: recipe.createdAt)
        let day = calendar.component(.day, from: recipe.createdAt)
        return "\(month)月\(day)日创建"
    }
}

#Preview("食谱管理") {
    RecipeListScreen(onBack: {})
        .environment(AppStore.preview)
}
