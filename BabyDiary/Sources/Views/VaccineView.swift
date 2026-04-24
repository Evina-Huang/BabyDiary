import SwiftUI

struct VaccineScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var editing: Vaccine? = nil
    @State private var editingCompleted: Vaccine? = nil
    @State private var showAddCustom = false
    @State private var showRecommended = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "疫苗记录", onBack: onBack)
            ScreenBody {
                progressHero.padding(.top, 4)

                let plan = store.vaccines
                let upcoming = plan.filter { !$0.done }
                let completed = plan.filter { $0.done }
                let templates = store.availableVaccineTemplates

                sectionHeader(title: "我的接种计划 · 待接种", countLabel: "\(upcoming.count) 项",
                              ink: Palette.pinkInk, bg: store.theme.primaryTint)
                    .padding(.top, 24)

                if upcoming.isEmpty {
                    Card {
                        Text("还没有待接种的疫苗，从下方「推荐接种」中添加，或自定义新增。")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.ink3)
                    }
                    .padding(.top, 10)
                } else {
                    VStack(spacing: 10) {
                        ForEach(upcoming) { v in
                            VaccineCard(vaccine: v,
                                        onEdit: { editing = v },
                                        onComplete: { store.toggleVaccine(v.id) })
                        }
                    }
                    .padding(.top, 10)
                }

                addCustomButton.padding(.top, 12)

                if !templates.isEmpty {
                    recommendedHeader(count: templates.count)
                        .padding(.top, 24)

                    if showRecommended {
                        VStack(spacing: 10) {
                            ForEach(templates) { t in
                                TemplateCard(template: t) { store.addVaccineFromTemplate(t) }
                            }
                        }
                        .padding(.top, 10)
                    }
                }

                if !completed.isEmpty {
                    sectionHeader(title: "已完成", countLabel: "\(completed.count) 项",
                                  ink: Palette.mint600, bg: Palette.mintTint)
                        .padding(.top, 24)

                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(completed.enumerated()), id: \.element.id) { i, v in
                                CompletedRow(vaccine: v, last: i == completed.count - 1) {
                                    editingCompleted = v
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .background(Palette.bg)
        .sheet(item: $editing) { v in
            VaccineEditSheet(vaccine: v) { editing = nil }
                .environment(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAddCustom) {
            VaccineAddCustomSheet { showAddCustom = false }
                .environment(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if let vaccine = editingCompleted {
                CompletedVaccineEditor(vaccine: vaccine) {
                    editingCompleted = nil
                }
                .environment(store)
            }
        }
    }

    private var addCustomButton: some View {
        Button { showAddCustom = true } label: {
            HStack(spacing: 8) {
                AppIcon.Check(size: 14, color: store.theme.primary600)
                Text("新增自定义疫苗")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(-0.14)
                    .foregroundStyle(store.theme.primary600)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(store.theme.primaryTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var progressHero: some View {
        let completedCount = store.vaccines.filter(\.done).count
        let total = max(store.vaccines.count, 1)
        let pct = Double(completedCount) / Double(total)
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0xDEF3E9), Color(hex: 0xF1FAF5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                        AppIcon.Shield(size: 32, color: Palette.mint600)
                    }
                    .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("接种进度")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(0.72)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.mint600)
                        Text("已完成 \(completedCount) / \(store.vaccines.count)")
                            .font(.system(size: 22, weight: .black))
                            .tracking(-0.44)
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.6))
                        Capsule().fill(Palette.mint600)
                            .frame(width: max(0, geo.size.width * pct))
                    }
                }
                .frame(height: 10)
            }
            .padding(20)
        }
    }

    private func sectionHeader(title: String, countLabel: String,
                               ink: Color, bg: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .tracking(-0.15)
            Text(countLabel)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(ink)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(bg, in: Capsule())
            Spacer()
        }
    }

    private func recommendedHeader(count: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                showRecommended.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text("推荐接种")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                    .foregroundStyle(Palette.ink)
                Text("\(count) 项")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(store.theme.primary600)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(store.theme.primaryTint, in: Capsule())
                Spacer()
                Text(showRecommended ? "收起" : "展开")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(store.theme.primary600)
                Image(systemName: showRecommended ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(store.theme.primary600)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadowCard()
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: — 计划中的疫苗卡片

private struct VaccineCard: View {
    let vaccine: Vaccine
    let onEdit: () -> Void
    let onComplete: () -> Void

    var body: some View {
        let status = vaccine.status()
        let overdue = status == .overdue
        let dueNow  = status == .due
        let bg: Color = overdue ? Color(hex: 0xFFE8E0)
                        : dueNow ? Palette.yellow : .white
        let iconBg: Color = overdue ? .white
                        : dueNow ? Color.white.opacity(0.6) : Palette.mintTint
        let iconColor: Color = overdue ? Color(hex: 0xFF7F64)
                        : dueNow ? Palette.yellowInk : Palette.mint600

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(iconBg)
                AppIcon.Syringe(size: 22, color: iconColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(vaccine.name)
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    if let d = vaccine.scheduledDate {
                        Text("计划 \(formatDate(d))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.ink3)
                    } else {
                        Text(vaccine.ageLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.ink3)
                    }
                    if overdue { tag(text: "已逾期", tint: Color(hex: 0xFF7F64)) }
                    if dueNow  { tag(text: "本月",   tint: Palette.yellowInk) }
                    if vaccine.isCustom { tag(text: "自定义", tint: Palette.ink3) }
                }
            }
            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Button(action: onComplete) {
                    HStack(spacing: 6) {
                        AppIcon.Check(size: 14, color: .white)
                        Text("完成")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(-0.13)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Palette.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Palette.mint600.opacity(0.35), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(PressableStyle())

                Button(action: onEdit) {
                    Text("编辑")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Palette.ink3)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Palette.bg2, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(16)
        .background(bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadowCard()
        .contentShape(Rectangle())
    }

    private func tag(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Color.white, in: Capsule())
    }
}

// MARK: — 推荐模板卡片（尚未加入计划）

private struct TemplateCard: View {
    let template: VaccineTemplate
    let onAdd: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.bg2)
                AppIcon.Syringe(size: 22, color: Palette.ink3)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                    .foregroundStyle(Palette.ink)
                Text("推荐 \(template.ageLabel) · 约 \(formatDate(store.recommendedDate(forMonths: template.ageMonths)))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            Spacer(minLength: 0)

            Button(action: onAdd) {
                Text("加入计划")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(-0.13)
                    .foregroundStyle(store.theme.primary600)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(store.theme.primaryTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}

private struct CompletedRow: View {
    let vaccine: Vaccine
    let last: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Palette.mint)
                        AppIcon.Check(size: 18, color: .white)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vaccine.name)
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(-0.15)
                            .foregroundStyle(Palette.ink)
                        if let dd = vaccine.doneDate {
                            Text("\(vaccine.ageLabel) · 已于 \(formatDate(dd)) 接种")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("编辑")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Palette.ink3)
                }
                .padding(.vertical, 12)
                if !last {
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}

private struct CompletedVaccineEditor: View {
    let vaccine: Vaccine
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var name: String
    @State private var doneDate: Date
    @State private var showDeleteConfirm = false

    init(vaccine: Vaccine, onClose: @escaping () -> Void) {
        self.vaccine = vaccine
        self.onClose = onClose
        self._name = State(initialValue: vaccine.name)
        self._doneDate = State(initialValue: vaccine.doneDate ?? vaccine.scheduledDate ?? Date())
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                ScreenHeader(title: "编辑已接种记录", onBack: onClose)
                    .padding(.top, 8)

                ScreenBody {
                    VStack(spacing: 18) {
                        Card {
                            VStack(alignment: .leading, spacing: 16) {
                                FormField(label: "名称") {
                                    TextField("疫苗名称", text: $name)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    FieldLabel(text: "推荐月龄")
                                    Text(vaccine.ageLabel)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    FieldLabel(text: "接种日期")
                                    DatePicker("", selection: $doneDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .environment(\.locale, Locale(identifier: "zh_CN"))
                                        .datePickerStyle(.graphical)
                                        .padding(10)
                                        .frame(maxWidth: .infinity)
                                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }

                        CTAButton(title: "保存", theme: store.theme) {
                            var updated = vaccine
                            updated.name = name.trimmingCharacters(in: .whitespaces)
                            updated.doneDate = doneDate
                            store.updateVaccine(updated)
                            onClose()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button { showDeleteConfirm = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                Text(vaccine.isCustom ? "删除此疫苗" : "从我的计划中移除")
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
            .frame(maxWidth: 560)
            .background(Palette.bg)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadowSurface()
            .padding(.horizontal, 16)
            .padding(.vertical, 28)

            if showDeleteConfirm {
                VaccineConfirmDialog(
                    title: "确定删除「\(vaccine.name)」?",
                    message: "删除后这条疫苗记录将不可恢复。",
                    confirmLabel: "删除",
                    onConfirm: {
                        store.removeVaccine(vaccine.id)
                        onClose()
                    },
                    onCancel: { showDeleteConfirm = false }
                )
            }
        }
        .transition(.opacity)
    }
}

private struct VaccineConfirmDialog: View {
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

// MARK: — 编辑已有疫苗

private struct VaccineEditSheet: View {
    @State var vaccine: Vaccine
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var isDone: Bool
    @State private var scheduled: Date
    @State private var doneDate: Date

    init(vaccine: Vaccine, onClose: @escaping () -> Void) {
        self._vaccine = State(initialValue: vaccine)
        self.onClose = onClose
        self._isDone = State(initialValue: vaccine.done)
        self._scheduled = State(initialValue: vaccine.scheduledDate ?? Date())
        self._doneDate = State(initialValue: vaccine.doneDate ?? vaccine.scheduledDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("疫苗") {
                    TextField("名称", text: $vaccine.name)
                    HStack {
                        Text("推荐月龄")
                        Spacer()
                        Text(vaccine.ageLabel).foregroundStyle(.secondary)
                    }
                }

                Section("计划接种日期") {
                    DatePicker("日期", selection: $scheduled, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    Button("重置为推荐日期") {
                        scheduled = store.recommendedDate(forMonths: vaccine.ageMonths)
                    }
                }

                Section {
                    Toggle("已接种", isOn: $isDone)
                    if isDone {
                        DatePicker("接种日期", selection: $doneDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        store.removeVaccine(vaccine.id)
                        onClose()
                    } label: {
                        Text(vaccine.isCustom ? "删除此疫苗" : "从我的计划中移除")
                    }
                }
            }
            .navigationTitle("编辑疫苗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = vaccine
                        updated.scheduledDate = scheduled
                        updated.doneDate = isDone ? doneDate : nil
                        store.updateVaccine(updated)
                        onClose()
                    }
                    .disabled(vaccine.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: — 新增自定义疫苗

private struct VaccineAddCustomSheet: View {
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var name: String = ""
    @State private var ageMonths: Int = 6
    @State private var useCustomDate = false
    @State private var scheduled: Date = Date()
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("疫苗信息") {
                    TextField("疫苗名称", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                    Stepper(value: $ageMonths, in: 0...72) {
                        HStack {
                            Text("推荐月龄")
                            Spacer()
                            Text(vaccineAgeLabel(months: ageMonths)).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("计划接种日期") {
                    Toggle("自定义日期", isOn: $useCustomDate)
                    if useCustomDate {
                        DatePicker("日期", selection: $scheduled, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    } else {
                        HStack {
                            Text("将使用推荐日期")
                            Spacer()
                            Text(formatDate(store.recommendedDate(forMonths: ageMonths)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("新增自定义疫苗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", action: onClose) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        store.addCustomVaccine(
                            name: name.trimmingCharacters(in: .whitespaces),
                            ageMonths: ageMonths,
                            scheduledDate: useCustomDate ? scheduled : nil
                        )
                        onClose()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        nameFocused = false
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: — 日期格式化

private func formatDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "yyyy/MM/dd"
    return f.string(from: d)
}

#Preview("疫苗") {
    VaccineScreen(onBack: {})
        .environment(AppStore.preview)
}
