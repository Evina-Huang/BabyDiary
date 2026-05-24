import SwiftUI

struct RecipeListScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var editing: RecipeEditTarget? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "我的食谱", onBack: onBack)
            ScreenBody {
                newRecipeButton
                if store.recipes.isEmpty {
                    EmptyStateView(
                        title: "还没有食谱",
                        subtitle: "把常一起吃的食材组合成食谱，下次记录一键带出"
                    )
                    .padding(.top, 18)
                } else {
                    recipesCard.padding(.top, 18)
                }
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
        }
    }

    private var newRecipeButton: some View {
        Button {
            editing = RecipeEditTarget(recipe: nil)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(store.theme.primaryTint)
                    AppIcon.Plus(size: 16, color: store.theme.primary600)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("新建食谱")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    Text("组合常用食材，方便下次一键记录")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
                AppIcon.Chevron(size: 14, color: Palette.ink3)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadowCard()
        }
        .buttonStyle(PressableStyle())
    }

    private var recipesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(store.theme.primary600)
                    .frame(width: 8, height: 8)
                Text("已保存")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.52)
                    .foregroundStyle(Palette.ink2)
                Text("\(store.recipes.count) 个")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 4)

            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(store.recipes.enumerated()), id: \.element.id) { i, recipe in
                        RecipeRow(
                            recipe: recipe,
                            last: i == store.recipes.count - 1,
                            theme: store.theme,
                            onEdit: { editing = RecipeEditTarget(recipe: recipe) },
                            onDelete: { store.deleteRecipe(recipe.id) }
                        )
                        .padding(.horizontal, 16)
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

private struct RecipeRow: View {
    let recipe: Recipe
    let last: Bool
    let theme: AppTheme
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(theme.primary600.opacity(0.65))
                        .frame(width: 9, height: 9)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(recipe.name)
                            .font(.system(size: 15, weight: .bold))
                            .tracking(-0.15)
                            .foregroundStyle(Palette.ink)
                        Text(foodPreview)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text("\(recipe.foodNames.count) 种")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.primary600)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(theme.primaryTint, in: Capsule())
                }
                .padding(.vertical, 14)

                if !last {
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button("编辑食谱", action: onEdit)
            Button("删除食谱", role: .destructive, action: onDelete)
        }
    }

    private var foodPreview: String {
        recipe.foodNames.joined(separator: " · ")
    }
}

#Preview("食谱管理") {
    RecipeListScreen(onBack: {})
        .environment(AppStore.preview)
}
