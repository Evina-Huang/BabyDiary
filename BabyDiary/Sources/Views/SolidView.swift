import SwiftUI

struct SolidScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    enum Unit: String, Hashable { case g, ml }

    private let quick = ["米糊", "南瓜泥", "苹果泥", "胡萝卜", "香蕉", "鸡蛋黄"]

    @State private var selectedNames: [String] = []
    @State private var observationDaysMap: [String: Int] = [:]
    @State private var customInput: String = ""
    @State private var amount: String = ""
    @State private var unit: Unit = .g
    @State private var time: Date = .now
    @State private var notes: String = ""
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "辅食记录", onBack: onBack)
            ScreenBody {
                observationStrip
                nameBlock.padding(.top, 8)
                amountBlock.padding(.top, 22)
                timePicker.padding(.top, 22)
                notesBlock.padding(.top, 22)
                saveButton.padding(.top, 22)
                historySection.padding(.top, 26)
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
            quickChips
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

    private var quickChips: some View {
        let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(quick, id: \.self) { q in
                let on = selectedNames.contains(q)
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        if on {
                            selectedNames.removeAll { $0 == q }
                            observationDaysMap.removeValue(forKey: q)
                        } else {
                            selectedNames.append(q)
                            observationDaysMap[q] = 3
                        }
                    }
                } label: {
                    Text(q)
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(-0.13)
                        .foregroundStyle(on ? Palette.yellowInk : Palette.ink2)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(on ? Palette.yellow : Palette.bg2, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "时间")
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white)
                    AppIcon.Clock(size: 20, color: store.theme.primary600)
                }
                .frame(width: 36, height: 36)
                Text(formatTime(time))
                    .font(.system(size: 16, weight: .heavy))
                    .tracking(-0.16)
                Spacer(minLength: 0)
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(store.theme.primary600)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
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
        let bg: Color = saved ? Palette.mint : (enabled ? store.theme.primary : Palette.bg2)
        let fg: Color = (enabled || saved) ? .white : Palette.ink3
        return Button(action: submit) {
            Text(saved ? "✓ 已保存" : "保存记录")
                .font(.system(size: 17, weight: .heavy))
                .tracking(-0.17)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadowPill(tint: (enabled || saved) ? bg.opacity(0.9) : .clear)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private var historySection: some View {
        let history = Array(store.events.filter { $0.kind == .solid }.prefix(20))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近记录")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                Spacer()
                Text("共 \(history.count) 条")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.ink3)
            }
            Card(padding: 0) {
                VStack(spacing: 0) {
                    if history.isEmpty {
                        EmptyStateView(title: "还没有辅食记录",
                                       subtitle: "记录第一次尝试的新食物，留住成长的小里程碑")
                    } else {
                        ForEach(Array(history.enumerated()), id: \.element.id) { i, e in
                            EventRow(event: e, last: i == history.count - 1, onDelete: { store.deleteEvent($0) })
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
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
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { saved = false }
        }
        selectedNames = []; observationDaysMap = [:]; customInput = ""; amount = ""; notes = ""
        time = Date()
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
