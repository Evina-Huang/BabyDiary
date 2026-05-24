import SwiftUI

struct SolidScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    enum Unit: String, Hashable { case g, ml }

    @State private var selectedNames: [String] = []
    @State private var observationDaysMap: [String: Int] = [:]
    @State private var customInput: String = ""
    @State private var amount: String = ""
    @State private var unit: Unit = .g
    @State private var time: Date = .now
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "辅食记录", onBack: onBack)
            ScreenBody {
                observationStrip
                nameBlock.padding(.top, 8)
                amountBlock.padding(.top, 22)
                timePicker.padding(.top, 22)
                notesBlock.padding(.top, 22)
                selectionNotice.padding(.top, 18)
                saveButton.padding(.top, 12)
            }
        }
        .background(Palette.bg)
    }

    @ViewBuilder
    private var observationStrip: some View {
        let obs = store.foods.filter { $0.status == .observing }
        if !obs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Palette.yellowInk)
                        .frame(width: 7, height: 7)
                    Text("排敏中")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.72)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.yellowInk)
                }
                VStack(spacing: 8) {
                    ForEach(obs) { food in
                        ObservationChip(food: food)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.yellow.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.yellowInk.opacity(0.12), lineWidth: 1)
            )
            .padding(.top, 8)
        }
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "食物名称（可多选）")
            if !selectedNames.isEmpty {
                selectedFoodsCard
            }
            HStack(spacing: 10) {
                TextField("输入其他食物名称", text: $customInput)
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
            if !store.recipes.isEmpty {
                recipeRow
            }
        }
    }

    private var recipeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的食谱")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.66)
                .textCase(.uppercase)
                .foregroundStyle(Palette.ink3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.recipes) { recipe in
                        recipeChip(recipe)
                    }
                }
            }
        }
    }

    private func recipeChip(_ recipe: Recipe) -> some View {
        let on = selectedNames.contains(allOf: recipe.foodNames)
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                applyRecipe(recipe)
            }
        } label: {
            HStack(spacing: 6) {
                Text(recipe.name)
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(-0.13)
                    .foregroundStyle(on ? .white : Palette.ink2)
                Text("· \(recipe.foodNames.count)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(on ? .white.opacity(0.78) : Palette.ink3)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(on ? store.theme.primary : Palette.bg2, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func applyRecipe(_ recipe: Recipe) {
        let allSelected = selectedNames.contains(allOf: recipe.foodNames)
        if allSelected {
            for name in recipe.foodNames {
                selectedNames.removeAll { $0 == name }
                observationDaysMap.removeValue(forKey: name)
            }
        } else {
            for name in recipe.foodNames where !selectedNames.contains(name) {
                selectedNames.append(name)
                observationDaysMap[name] = 3
            }
        }
    }

    @ViewBuilder
    private var selectionNotice: some View {
        let needsObservation = selectedNames.filter { name in
            if let f = store.foods.first(where: { $0.name == name }) {
                return f.status == .observing
            }
            return true
        }
        let allergic = selectedNames.filter { name in
            store.foods.first(where: { $0.name == name })?.status == .allergic
        }
        if !needsObservation.isEmpty || !allergic.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !needsObservation.isEmpty {
                    Label("包含 \(needsObservation.count) 项未排敏食材：\(needsObservation.joined(separator: "、"))",
                          systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Palette.yellowInk)
                }
                if !allergic.isEmpty {
                    Label("含已过敏食材：\(allergic.joined(separator: "、"))",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color(hex: 0xD44E3A))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Palette.yellow.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // Each selected food gets its own observation-days picker (only for new foods)
    private var selectedFoodsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedNames.enumerated()), id: \.element) { i, foodName in
                let existing = store.foods.first { $0.name == foodName }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(foodName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                        if let existing {
                            statusBadge(for: existing)
                        }
                        Button {
                            withAnimation(.easeOut(duration: 0.16)) {
                                selectedNames.removeAll { $0 == foodName }
                                observationDaysMap.removeValue(forKey: foodName)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    if existing == nil {
                        SegPill<Int>(
                            selection: daysBinding(for: foodName),
                            options: [(3, "3天"), (5, "5天"), (7, "7天")]
                        )
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                if i < selectedNames.count - 1 {
                    Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 16)
                }
            }
        }
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func statusBadge(for food: FoodItem) -> some View {
        switch food.status {
        case .observing:
            Text(food.isObservationDue ? "待确认" : "排敏中")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Palette.yellowInk)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Palette.yellow, in: Capsule())
        case .safe:
            Text("已安全")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Palette.mint600)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Palette.mintTint, in: Capsule())
        case .allergic:
            Text("已过敏")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color(hex: 0xD44E3A))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(hex: 0xFFDDD8), in: Capsule())
        }
    }

    private func daysBinding(for name: String) -> Binding<Int> {
        Binding(
            get: { observationDaysMap[name] ?? 3 },
            set: { observationDaysMap[name] = $0 }
        )
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                FieldLabel(text: "份量")
                Spacer()
                SegPill<Unit>(selection: $unit,
                              options: [(.g, "克 (g)"), (.ml, "毫升 (ml)")])
            }
            HStack {
                TextField("填入份量", text: $amount)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .keyboardType(.numberPad)
                Text(unit.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var timePicker: some View {
        InlineWheelTimePicker(time: $time, theme: store.theme)
    }

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "备注（可选）")
            TextField("例如：第一次吃南瓜，很喜欢", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var saveButton: some View {
        let enabled = !selectedNames.isEmpty
        let bg: Color = enabled ? store.theme.primary : Palette.bg2
        let fg: Color = enabled ? .white : Palette.ink3
        return Button(action: submit) {
            Text("保存记录")
                .font(.system(size: 17, weight: .heavy))
                .tracking(-0.17)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadowPill(tint: enabled ? bg.opacity(0.9) : .clear)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private func addCustom() {
        let trimmed = customInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selectedNames.contains(trimmed) else {
            customInput = ""
            return
        }
        withAnimation(.easeOut(duration: 0.16)) {
            selectedNames.append(trimmed)
            observationDaysMap[trimmed] = 3
        }
        customInput = ""
    }

    private func submit() {
        guard !selectedNames.isEmpty else { return }
        let amt = amount.trimmingCharacters(in: .whitespaces)
        let amountStr = amt.isEmpty ? "少量" : "\(amt)\(unit.rawValue)"
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let sub = trimmedNotes.isEmpty ? amountStr : "\(amountStr) · \(trimmedNotes)"
        let title = selectedNames.joined(separator: " · ")
        store.addEvent(.init(kind: .solid, at: time, title: title, sub: sub))
        for foodName in selectedNames {
            store.recordSolidFood(foodName, at: time, observationDays: observationDaysMap[foodName] ?? 3)
        }
        onBack()
    }
}

private extension Array where Element: Equatable {
    func contains(allOf others: [Element]) -> Bool {
        guard !others.isEmpty else { return false }
        return others.allSatisfy { contains($0) }
    }
}

// MARK: — Observation chip inside the排敏 strip

private struct ObservationChip: View {
    let food: FoodItem
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            Text(food.name)
                .font(.system(size: 14, weight: .heavy))
                .tracking(-0.14)
                .foregroundStyle(Palette.yellowInk)
            Spacer(minLength: 0)
            if food.isObservationDue {
                HStack(spacing: 8) {
                    chipButton("没有反应 → 安全", bg: Palette.mintTint, fg: Palette.mint600) {
                        withAnimation { store.updateFoodStatus(food.id, .safe) }
                    }
                    chipButton("有反应 → 过敏", bg: Color(hex: 0xFFDDD8), fg: Color(hex: 0xD44E3A)) {
                        withAnimation { store.updateFoodStatus(food.id, .allergic) }
                    }
                }
            } else {
                Text("还剩 \(food.daysRemaining) 天")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.yellowInk.opacity(0.75))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.white.opacity(0.65),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func chipButton(_ label: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(fg)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(bg, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview("辅食记录") {
    SolidScreen(onBack: {})
        .environment(AppStore.preview)
}
