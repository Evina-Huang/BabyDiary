import SwiftUI

struct SolidScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    enum Unit: String, Hashable { case g, ml }

    static let defaultFoodPresets = ["米糊", "蛋黄", "南瓜泥", "胡萝卜泥", "香蕉泥", "苹果泥"]

    @State private var selectedNames: [String] = []
    @State private var observationDaysMap: [String: Int] = [:]
    @State private var customInput: String = ""
    @State private var amount: String = ""
    @State private var unit: Unit = .g
    @State private var time: Date = .now
    @State private var notes: String = ""
    @State private var showObservationDetails = false
    @State private var showDetails = false
    @State private var showExitConfirmation = false
    @State private var showSaved = false
    @State private var saveCompleted = false
    @State private var initialDraft: SolidDraft?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "辅食记录", onBack: requestClose)
            ScreenBody {
                lastSolidContext.padding(.top, 8)

                foodSelectionCard.padding(.top, 16)
                observationOverview.padding(.top, 14)

                if !selectedNames.isEmpty {
                    selectionNotice.padding(.top, 12)
                    AdjustmentDetails(
                        isExpanded: $showDetails,
                        summary: "份量、记录时间与备注"
                    ) {
                        solidDetails
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RecordSaveBar(status: saveStatus, theme: store.theme, action: submit)
        }
        .overlay(alignment: .top) {
            RecordSuccessToast(isPresented: showSaved, title: "辅食记录已保存")
                .padding(.top, 12)
        }
        .recordExitProtection(
            exitProtection,
            isPresented: $showExitConfirmation,
            onDiscard: resetDraft,
            onDismiss: onBack
        )
        .onAppear {
            if initialDraft == nil { initialDraft = currentDraft }
        }
    }

    private var observingFoods: [FoodItem] {
        store.foods.filter { $0.status == .observing }
    }

    @ViewBuilder
    private var lastSolidContext: some View {
        if let lastAt = store.mostRecentEvent(kind: .solid)?.occurredAt {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let seconds = max(0, Int(context.date.timeIntervalSince(lastAt)))
                let hours = seconds / 3600
                let minutes = (seconds % 3600) / 60
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("距上次辅食")
                        .appFont(size: 13, weight: .bold)
                        .foregroundStyle(Palette.yellowInk.opacity(0.78))
                    Spacer(minLength: 8)
                    Text(hours > 0 ? "\(hours)时\(minutes)分" : "\(minutes)分")
                        .appFont(size: 20, weight: .black)
                        .monospacedDigit()
                        .foregroundStyle(Palette.yellowInk)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(
                    Palette.yellow.opacity(0.78),
                    in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var frequentFoodNames: [String] {
        let recentCustomNames = store.foods
            .filter { $0.status != .allergic }
            .sorted {
                if $0.timesEaten == $1.timesEaten { return $0.name < $1.name }
                return $0.timesEaten > $1.timesEaten
            }
            .map(\.name)
            .filter { !Self.defaultFoodPresets.contains($0) }
        return Array(recentCustomNames.prefix(2)) + Self.defaultFoodPresets
    }

    private var amountPresets: [Int] {
        switch unit {
        case .g: return [10, 20, 30, 50]
        case .ml: return [30, 60, 90, 120]
        }
    }

    @ViewBuilder
    private var observationOverview: some View {
        if !observingFoods.isEmpty {
            let dueCount = observingFoods.filter(\.isObservationDue).count
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showObservationDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("排敏进度")
                                .appFont(size: 15, weight: .bold)
                                .foregroundStyle(Palette.ink)
                            Text(dueCount > 0
                                 ? "有 \(dueCount) 种食材等待确认"
                                 : "\(observingFoods.count) 种食材正在观察")
                                .appFont(size: 12, weight: .semibold)
                                .foregroundStyle(dueCount > 0 ? Palette.yellowInk : Palette.ink3)
                        }

                        Spacer(minLength: 8)

                        Text(showObservationDetails ? "收起" : "查看")
                            .appFont(size: 12, weight: .bold)
                            .foregroundStyle(Palette.yellowInk)
                        AppIcon.Chevron(size: 14, color: Palette.yellowInk)
                            .rotationEffect(.degrees(showObservationDetails ? 90 : 0))
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("排敏进度，\(observingFoods.count) 种食材，\(dueCount) 种待确认")
                .accessibilityValue(showObservationDetails ? "已展开" : "已收起")

                if showObservationDetails {
                    Rectangle()
                        .fill(Palette.yellowInk.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 14)

                    VStack(spacing: 8) {
                        ForEach(observingFoods) { food in
                            ObservationChip(food: food)
                        }
                    }
                    .padding(14)
                    .transition(.opacity)
                }
            }
            .background(
                Palette.yellow.opacity(0.52),
                in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                    .stroke(Palette.yellowInk.opacity(0.12), lineWidth: 1)
            }
        }
    }

    private var foodSelectionCard: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    CategoryIcon(kind: .solid, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("这次吃了什么？")
                            .appFont(size: 17, weight: .bold)
                            .foregroundStyle(Palette.ink)
                        Text(selectedNames.isEmpty
                             ? "可以选择多种食物"
                             : "已选择 \(selectedNames.count) 种")
                            .appFont(size: 12, weight: .medium)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                }

                if !selectedNames.isEmpty {
                    selectedFoodsCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                foodInput

                quickFoods

                if !store.recipes.isEmpty {
                    recipeRow
                }
            }
        }
    }

    private var foodInput: some View {
        HStack(spacing: 10) {
            TextField("输入食物名称", text: $customInput)
                .appFont(size: 16, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .submitLabel(.done)
                .onSubmit(addCustom)

            if !customInput.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("添加", action: addCustom)
                    .appFont(size: 13, weight: .bold)
                    .foregroundStyle(store.theme.primary600)
                    .frame(minWidth: 52, minHeight: 44)
                    .background(store.theme.primaryTint, in: Capsule())
                    .buttonStyle(PressableStyle())
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 52)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var quickFoods: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("常用食物")
                .appText(.micro)
                .foregroundStyle(Palette.ink3)

            let columns = [GridItem(.adaptive(minimum: 86), spacing: 8)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(frequentFoodNames, id: \.self) { foodName in
                    quickFoodButton(foodName)
                }
            }
        }
    }

    private func quickFoodButton(_ foodName: String) -> some View {
        let isSelected = selectedNames.contains(foodName)
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                toggleFood(foodName)
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    AppIcon.Check(size: 13, color: Palette.yellowInk)
                }
                Text(foodName)
                    .appFont(size: 13, weight: .bold)
                    .foregroundStyle(isSelected ? Palette.yellowInk : Palette.ink2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .background(
                isSelected ? Palette.yellow : Palette.bg2,
                in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                    .stroke(isSelected ? Palette.yellowInk.opacity(0.14) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var recipeRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("我的食谱")
                .appText(.micro)
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
        let isSelected = selectedNames.contains(allOf: recipe.foodNames)
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                applyRecipe(recipe)
            }
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    AppIcon.Check(size: 13, color: .white)
                }
                Text(recipe.name)
                    .appFont(size: 13, weight: .bold)
                    .foregroundStyle(isSelected ? .white : Palette.ink2)
                Text("\(recipe.foodNames.count) 种")
                    .appFont(size: 11, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white.opacity(0.78) : Palette.ink3)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isSelected ? store.theme.primary : Palette.bg2, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedFoodsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(selectedNames.enumerated()), id: \.element) { index, foodName in
                let existing = store.foods.first { $0.name == foodName }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(foodName)
                            .appFont(size: 14, weight: .bold)
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
                            AppIcon.Close(size: 14, color: Palette.ink3)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("移除\(foodName)")
                    }

                    if existing == nil {
                        HStack(spacing: 10) {
                            Text("排敏观察")
                                .appFont(size: 12, weight: .semibold)
                                .foregroundStyle(Palette.ink3)
                            Spacer(minLength: 0)
                            SegPill<Int>(
                                selection: daysBinding(for: foodName),
                                options: [(3, "3天"), (5, "5天"), (7, "7天")]
                            )
                            .frame(minHeight: 44)
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 4)
                .padding(.vertical, 6)

                if index < selectedNames.count - 1 {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                        .padding(.horizontal, 14)
                }
            }
        }
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    @ViewBuilder
    private func statusBadge(for food: FoodItem) -> some View {
        switch food.status {
        case .observing:
            Text(food.isObservationDue ? "待确认" : "排敏中")
                .foregroundStyle(Palette.yellowInk)
                .background(Palette.yellow, in: Capsule())
                .modifier(FoodStatusBadgeStyle())
        case .safe:
            Text("已安全")
                .foregroundStyle(Palette.mint600)
                .background(Palette.mintTint, in: Capsule())
                .modifier(FoodStatusBadgeStyle())
        case .allergic:
            Text("已过敏")
                .foregroundStyle(Palette.pinkInk)
                .background(Palette.pink, in: Capsule())
                .modifier(FoodStatusBadgeStyle())
        }
    }

    private var solidDetails: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    FieldLabel(text: "份量")
                    Spacer(minLength: 0)
                    SegPill<Unit>(
                        selection: $unit,
                        options: [(.g, "克 g"), (.ml, "毫升 ml")]
                    )
                    .frame(minHeight: 44)
                }

                HStack(spacing: 8) {
                    TextField("少量", text: $amount)
                        .appFont(size: 17, weight: .medium)
                        .foregroundStyle(Palette.ink)
                        .keyboardType(.numberPad)
                    Text(unit.rawValue)
                        .appText(.label)
                        .foregroundStyle(Palette.ink3)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                HStack(spacing: 8) {
                    amountPresetButton(nil)
                    ForEach(amountPresets, id: \.self) { value in
                        amountPresetButton(value)
                    }
                }
            }

            InlineWheelTimePicker(time: $time, theme: store.theme)

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "备注")
                TextField("例如：第一次吃南瓜，很喜欢", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .appFont(size: 16, weight: .medium)
                    .foregroundStyle(Palette.ink)
                    .padding(14)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            }
        }
    }

    private func amountPresetButton(_ value: Int?) -> some View {
        let presetAmount = value.map(String.init) ?? ""
        let isSelected = amount.trimmingCharacters(in: .whitespaces) == presetAmount
        let label = value.map { "\($0)\(unit.rawValue)" } ?? "少量"

        return Button {
            amount = presetAmount
        } label: {
            Text(label)
                .appFont(size: 12, weight: .bold)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Palette.yellowInk : Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    isSelected ? Palette.yellow : Palette.bg2,
                    in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var selectionNotice: some View {
        let needsObservation = selectedNames.filter { name in
            if let food = store.foods.first(where: { $0.name == name }) {
                return food.status == .observing
            }
            return true
        }
        let allergic = selectedNames.filter { name in
            store.foods.first(where: { $0.name == name })?.status == .allergic
        }

        if !needsObservation.isEmpty || !allergic.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !needsObservation.isEmpty {
                    warningLine(
                        "\(needsObservation.joined(separator: "、"))仍在排敏观察",
                        tint: Palette.yellow,
                        ink: Palette.yellowInk
                    )
                }
                if !allergic.isEmpty {
                    warningLine(
                        "含已过敏食材：\(allergic.joined(separator: "、"))",
                        tint: Palette.pink,
                        ink: Palette.pinkInk
                    )
                }
            }
        }
    }

    private func warningLine(_ text: String, tint: Color, ink: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("!")
                .appText(.captionEmphasis)
                .foregroundStyle(ink)
                .frame(width: 22, height: 22)
                .background(Palette.card.opacity(0.62), in: Circle())
            Text(text)
                .appFont(size: 12, weight: .bold)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(tint.opacity(0.58), in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
    }

    private var saveStatus: RecordSaveStatus {
        if saveCompleted { return .success }
        guard !selectedNames.isEmpty else { return .disabledQuietly }
        return .ready("保存")
    }

    private func toggleFood(_ name: String) {
        if selectedNames.contains(name) {
            selectedNames.removeAll { $0 == name }
            observationDaysMap.removeValue(forKey: name)
        } else {
            selectedNames.append(name)
            if store.foods.first(where: { $0.name == name }) == nil {
                observationDaysMap[name] = 3
            }
        }
    }

    private func addCustom() {
        let trimmed = customInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if !selectedNames.contains(trimmed) {
            withAnimation(.easeOut(duration: 0.18)) {
                selectedNames.append(trimmed)
                if store.foods.first(where: { $0.name == trimmed }) == nil {
                    observationDaysMap[trimmed] = 3
                }
            }
        }
        customInput = ""
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
                if store.foods.first(where: { $0.name == name }) == nil {
                    observationDaysMap[name] = 3
                }
            }
        }
    }

    private func daysBinding(for name: String) -> Binding<Int> {
        Binding(
            get: { observationDaysMap[name] ?? 3 },
            set: { observationDaysMap[name] = $0 }
        )
    }

    private func submit() {
        guard !selectedNames.isEmpty, !saveCompleted else { return }
        let trimmedAmount = amount.trimmingCharacters(in: .whitespaces)
        let amountText = trimmedAmount.isEmpty ? "少量" : "\(trimmedAmount)\(unit.rawValue)"
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let subtitle = trimmedNotes.isEmpty ? amountText : "\(amountText) · \(trimmedNotes)"
        let title = selectedNames.joined(separator: " · ")

        store.addEvent(.init(kind: .solid, at: time, title: title, sub: subtitle))
        for foodName in selectedNames {
            store.recordSolidFood(
                foodName,
                at: time,
                observationDays: observationDaysMap[foodName] ?? 3
            )
        }
        saveCompleted = true
        RecordSaveFeedback.complete(isPresented: $showSaved, then: onBack)
    }

    private var currentDraft: SolidDraft {
        SolidDraft(
            selectedNames: selectedNames,
            observationDaysMap: observationDaysMap,
            customInput: customInput,
            amount: amount,
            unit: unit,
            time: time,
            notes: notes
        )
    }

    private var exitProtection: RecordExitProtection {
        guard !saveCompleted, let initialDraft, currentDraft != initialDraft else { return .none }
        return .unsaved
    }

    private func requestClose() {
        if exitProtection.requiresConfirmation {
            showExitConfirmation = true
        } else {
            onBack()
        }
    }

    private func resetDraft() {
        guard let initialDraft else { return }
        selectedNames = initialDraft.selectedNames
        observationDaysMap = initialDraft.observationDaysMap
        customInput = initialDraft.customInput
        amount = initialDraft.amount
        unit = initialDraft.unit
        time = initialDraft.time
        notes = initialDraft.notes
        showDetails = false
    }
}

private struct SolidDraft: Equatable {
    let selectedNames: [String]
    let observationDaysMap: [String: Int]
    let customInput: String
    let amount: String
    let unit: SolidScreen.Unit
    let time: Date
    let notes: String
}

private struct FoodStatusBadgeStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .appFont(size: 11, weight: .heavy)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}

private extension Array where Element: Equatable {
    func contains(allOf others: [Element]) -> Bool {
        guard !others.isEmpty else { return false }
        return others.allSatisfy { contains($0) }
    }
}

private struct ObservationChip: View {
    let food: FoodItem
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(food.name)
                    .appFont(size: 14, weight: .bold)
                    .foregroundStyle(Palette.yellowInk)
                Spacer(minLength: 0)
                if food.isObservationDue {
                    Text("待确认")
                        .appFont(size: 11, weight: .heavy)
                        .foregroundStyle(Palette.yellowInk)
                } else {
                    Text("还剩 \(food.daysRemaining) 天")
                        .appFont(size: 12, weight: .bold)
                        .monospacedDigit()
                        .foregroundStyle(Palette.yellowInk.opacity(0.8))
                }
            }

            if food.isObservationDue {
                HStack(spacing: 8) {
                    observationButton(
                        "没有反应",
                        suffix: "标记安全",
                        background: Palette.mintTint,
                        foreground: Palette.mint600
                    ) {
                        withAnimation { store.updateFoodStatus(food.id, .safe) }
                    }
                    observationButton(
                        "出现反应",
                        suffix: "标记过敏",
                        background: Palette.pink,
                        foreground: Palette.pinkInk
                    ) {
                        withAnimation { store.updateFoodStatus(food.id, .allergic) }
                    }
                }
            }
        }
        .padding(12)
        .background(
            Palette.card.opacity(0.68),
            in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
        )
    }

    private func observationButton(
        _ title: String,
        suffix: String,
        background: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .appFont(size: 12, weight: .bold)
                Text(suffix)
                    .appFont(size: 10, weight: .semibold)
                    .opacity(0.8)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(background, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview("辅食记录") {
    SolidScreen(onBack: {})
        .environment(AppStore.preview)
}
