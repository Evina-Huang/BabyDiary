import SwiftUI

struct VaccineScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var editing: Vaccine? = nil
    @State private var completing: Vaccine? = nil
    @State private var editingCompleted: Vaccine? = nil
    @State private var showAddPlan = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "接种表", onBack: onBack) {
                Button { showAddPlan = true } label: {
                    HStack(spacing: 6) {
                        AppIcon.Plus(size: 15, color: store.theme.primary600)
                        Text("添加")
                            .appFont(size: 14, weight: .heavy)
                    }
                    .foregroundStyle(store.theme.primary600)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(store.theme.primaryTint, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            ScreenBody {
                let plan = store.vaccines
                let upcoming = plan.filter { !$0.done }
                let completed = plan.filter { $0.done }
                let overdue = upcoming.filter { $0.status() == .overdue }
                let dueSoon = upcoming.filter { $0.status() == .due }
                let later = upcoming.filter { $0.status() == .upcoming }

                reminderHero(
                    overdue: overdue,
                    dueSoon: dueSoon,
                    upcoming: upcoming,
                    completedCount: completed.count,
                    totalCount: plan.count
                )
                .padding(.top, 4)

                sectionHeader(title: "待接种计划", countLabel: "\(upcoming.count) 项",
                              ink: Palette.pinkInk, bg: store.theme.primaryTint)
                    .padding(.top, 24)

                if upcoming.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(plan.isEmpty ? "还没有接种计划" : "待接种已清空")
                                .appFont(size: 16, weight: .heavy)
                                .foregroundStyle(Palette.ink)
                            Text(plan.isEmpty ? "从右上角「添加」进入，先选疫苗名称，再选择具体剂次。" : "可以继续添加后续月龄的疫苗，或查看下方已完成记录。")
                                .appFont(size: 13, weight: .semibold)
                                .foregroundStyle(Palette.ink3)
                            Button { showAddPlan = true } label: {
                                HStack(spacing: 8) {
                                    AppIcon.Plus(size: 15, color: .white)
                                    Text("添加疫苗")
                                        .appFont(size: 14, weight: .heavy)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(store.theme.primary, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                                .shadowPill(tint: store.theme.primary600)
                            }
                            .buttonStyle(PressableStyle())
                            .padding(.top, 2)
                        }
                    }
                    .padding(.top, 10)
                } else {
                    pendingGroup(title: "已逾期", vaccines: overdue, tint: Palette.dangerTint, ink: Palette.dangerInk)
                    pendingGroup(title: "近 30 天", vaccines: dueSoon, tint: Palette.yellow, ink: Palette.yellowInk)
                    pendingGroup(title: "稍后接种", vaccines: later, tint: Palette.mintTint, ink: Palette.mint600)
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
        .sheet(item: $completing) { v in
            VaccineCompleteSheet(vaccine: v) { completing = nil }
                .environment(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddPlan) {
            VaccineAddPlanSheet { showAddPlan = false }
                .environment(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
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

    private func reminderHero(
        overdue: [Vaccine],
        dueSoon: [Vaccine],
        upcoming: [Vaccine],
        completedCount: Int,
        totalCount: Int
    ) -> some View {
        let total = max(totalCount, 1)
        let pct = Double(completedCount) / Double(total)
        let focus = overdue.first ?? dueSoon.first ?? upcoming.first
        let alert = !overdue.isEmpty
        let heroTint = alert ? Palette.dangerTint : Palette.mintTint
        let heroInk = alert ? Palette.dangerInk : Palette.mint600
        let title: String = {
            if !overdue.isEmpty { return "有 \(overdue.count) 项已逾期" }
            if !dueSoon.isEmpty { return "近 30 天有 \(dueSoon.count) 项待接种" }
            if focus != nil { return "下一针已安排" }
            if totalCount == 0 { return "还没有接种计划" }
            return "接种计划已完成"
        }()
        let subtitle: String = {
            guard let focus else {
                return totalCount == 0 ? "添加疫苗后，这里会提示下一针和逾期项。" : "已完成 \(completedCount) / \(totalCount)"
            }
            let date = focus.scheduledDate.map { formatDate($0) } ?? focus.ageLabel
            return "\(focus.name) · \(date)"
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                .fill(heroTint)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                            .fill(Palette.card.opacity(0.7))
                        AppIcon.Shield(size: 32, color: heroInk)
                    }
                    .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert ? "需要处理" : "接种提醒")
                            .appText(.captionEmphasis)
                            .foregroundStyle(heroInk)
                        Text(title)
                            .appText(.heroTitle)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                        Text(subtitle)
                            .appText(.caption)
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(3)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.card.opacity(0.6))
                        Capsule().fill(Palette.mint600)
                            .frame(width: max(0, geo.size.width * pct))
                    }
                }
                .frame(height: 10)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func pendingGroup(title: String, vaccines: [Vaccine], tint: Color, ink: Color) -> some View {
        if !vaccines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(ink).frame(width: 8, height: 8)
                    Text(title)
                        .appFont(size: 13, weight: .heavy)
                        .foregroundStyle(Palette.ink)
                    Text("\(vaccines.count) 项")
                        .appFont(size: 11, weight: .heavy)
                        .foregroundStyle(ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tint, in: Capsule())
                    Spacer()
                }
                ForEach(vaccines) { v in
                    VaccineCard(vaccine: v,
                                onEdit: { editing = v },
                                onComplete: { completing = v })
                }
            }
            .padding(.top, 14)
        }
    }

    private func sectionHeader(title: String, countLabel: String,
                               ink: Color, bg: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .appFont(size: 15, weight: .heavy)
            Text(countLabel)
                .appFont(size: 11, weight: .heavy)
                .foregroundStyle(ink)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(bg, in: Capsule())
            Spacer()
        }
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
        let bg: Color = overdue ? Palette.dangerTint
                        : dueNow ? Palette.yellow : Palette.card
        let iconBg: Color = overdue ? Palette.card
                        : dueNow ? Palette.card.opacity(0.6) : Palette.mintTint
        let iconColor: Color = overdue ? Palette.dangerInk
                        : dueNow ? Palette.yellowInk : Palette.mint600

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous).fill(iconBg)
                AppIcon.Syringe(size: 22, color: iconColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(vaccine.name)
                    .appFont(size: 15, weight: .heavy)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    if let d = vaccine.scheduledDate {
                        Text("计划 \(formatDate(d))")
                            .appFont(size: 12, weight: .bold)
                            .foregroundStyle(Palette.ink3)
                    } else {
                        Text(vaccine.ageLabel)
                            .appFont(size: 12, weight: .bold)
                            .foregroundStyle(Palette.ink3)
                    }
                    if overdue { tag(text: "已逾期", tint: Palette.dangerInk) }
                    if dueNow  { tag(text: "近30天", tint: Palette.yellowInk) }
                    if vaccine.isCustom { tag(text: "自定义", tint: Palette.ink3) }
                }
            }
            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Button(action: onComplete) {
                    HStack(spacing: 6) {
                        AppIcon.Check(size: 14, color: .white)
                        Text("记录")
                            .appFont(size: 13, weight: .heavy)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Palette.mint, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                }
                .buttonStyle(PressableStyle())

                Button(action: onEdit) {
                    Text("编辑")
                        .appFont(size: 11, weight: .heavy)
                        .foregroundStyle(Palette.ink3)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Palette.bg2, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(16)
        .background(bg, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
        .shadowCard()
        .contentShape(Rectangle())
    }

    private func tag(text: String, tint: Color) -> some View {
        Text(text)
            .appText(.micro)
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Palette.card, in: Capsule())
    }
}

// MARK: — 添加疫苗

private enum VaccineAddScope: Hashable {
    case current, all, free, paid
}

private struct VaccineAddPlanSheet: View {
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var scope: VaccineAddScope = .current
    @State private var query = ""
    @State private var selectedGroup: VaccineTemplateGroup? = nil
    @State private var showAddCustom = false

    private var currentAgeMonths: Int {
        Int(store.ageMonths(on: Date()).rounded(.down))
    }

    private var filteredGroups: [VaccineTemplateGroup] {
        let base = VaccineCatalog.groupedPresets.compactMap { group -> VaccineTemplateGroup? in
            let scoped = scopedTemplates(in: group)
            let searched = scoped.filter { template in
                query.trimmingCharacters(in: .whitespaces).isEmpty
                || group.name.localizedCaseInsensitiveContains(query)
                || template.name.localizedCaseInsensitiveContains(query)
            }
            guard !searched.isEmpty else { return nil }
            return VaccineTemplateGroup(id: group.id, name: group.name, templates: searched)
        }

        let sorted = base.sorted { a, b in
            let aJoined = a.templates.allSatisfy { store.hasVaccineTemplate($0) }
            let bJoined = b.templates.allSatisfy { store.hasVaccineTemplate($0) }
            if aJoined != bJoined { return !aJoined && bJoined }

            let aDistance = a.templates.map { abs($0.ageMonths - currentAgeMonths) }.min() ?? 999
            let bDistance = b.templates.map { abs($0.ageMonths - currentAgeMonths) }.min() ?? 999
            if aDistance != bDistance { return aDistance < bDistance }

            let aMin = a.templates.map(\.ageMonths).min() ?? 0
            let bMin = b.templates.map(\.ageMonths).min() ?? 0
            if aMin != bMin { return aMin < bMin }
            return a.name < b.name
        }

        if scope == .current, sorted.isEmpty, query.trimmingCharacters(in: .whitespaces).isEmpty {
            return VaccineCatalog.groupedPresets.filter { group in
                group.templates.contains { !store.hasVaccineTemplate($0) }
            }
        }
        return sorted
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: selectedGroup == nil ? "添加疫苗" : selectedGroup!.name,
                         onBack: selectedGroup == nil ? onClose : { selectedGroup = nil }) {
                Button(action: onClose) {
                    AppIcon.Close(size: 14, color: Palette.ink2)
                        .frame(width: 38, height: 38)
                        .background(Palette.bg2, in: Circle())
                }
                .buttonStyle(PressableStyle())
            }

            if let group = selectedGroup {
                detail(group)
            } else {
                groupList
            }
        }
        .background(Palette.bg)
        .sheet(isPresented: $showAddCustom) {
            VaccineAddCustomSheet { showAddCustom = false }
                .environment(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var groupList: some View {
        ScreenBody {
            Card {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous).fill(Palette.mintTint)
                        AppIcon.Shield(size: 26, color: Palette.mint600)
                    }
                    .frame(width: 50, height: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(store.baby.name) 约 \(vaccineAgeLabel(months: currentAgeMonths))")
                            .appText(.cardTitle)
                            .foregroundStyle(Palette.ink)
                        Text("默认展示当前月龄附近、还没加入计划的疫苗。")
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                }
            }

            searchField.padding(.top, 14)

            SegPill(selection: $scope, options: [
                (.current, "适龄"),
                (.all, "全部"),
                (.free, "免费"),
                (.paid, "自费")
            ])
            .padding(.top, 12)

            VStack(spacing: 10) {
                ForEach(filteredGroups) { group in
                    VaccineTemplateGroupRow(
                        group: group,
                        joinedCount: group.templates.filter { store.hasVaccineTemplate($0) }.count,
                        totalCount: group.templates.count,
                        currentAgeMonths: currentAgeMonths,
                        onTap: {
                            selectedGroup = VaccineCatalog.groupedPresets.first { $0.id == group.id } ?? group
                        }
                    )
                }
            }
            .padding(.top, 16)

            Button { showAddCustom = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous).fill(store.theme.primaryTint)
                        AppIcon.Plus(size: 18, color: store.theme.primary600)
                    }
                    .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("没有找到？新增自定义疫苗")
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(Palette.ink)
                        Text("用于医生单独安排或本地计划外项目")
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                    AppIcon.Chevron(size: 14, color: Palette.ink3)
                }
                .padding(16)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
                .shadowCard()
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 12)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            AppIcon.Syringe(size: 18, color: Palette.ink3)
            TextField("搜索疫苗名称", text: $query)
                .appFont(size: 15, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    AppIcon.Close(size: 12, color: Palette.ink3)
                        .frame(width: 28, height: 28)
                        .background(Palette.bg2, in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
        .shadowCard()
    }

    private func detail(_ group: VaccineTemplateGroup) -> some View {
        ScreenBody {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(group.costSummary)
                            .appFont(size: 11, weight: .heavy)
                            .foregroundStyle(group.costSummary.contains("自费") ? Palette.yellowInk : Palette.mint600)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(group.costSummary.contains("自费") ? Palette.yellow : Palette.mintTint, in: Capsule())
                        Text(group.ageRangeLabel)
                            .appFont(size: 11, weight: .heavy)
                            .foregroundStyle(Palette.ink3)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Palette.bg2, in: Capsule())
                    }
                    Text("选择需要加入计划的剂次")
                        .appText(.sectionTitle)
                        .foregroundStyle(Palette.ink)
                    Text("每一针都会按宝宝生日自动推算推荐日期，也可以稍后在接种表中编辑。")
                        .appFont(size: 13, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                }
            }

            VStack(spacing: 10) {
                ForEach(group.templates) { template in
                    VaccineDoseTemplateRow(
                        template: template,
                        recommendedDate: store.recommendedDate(forMonths: template.ageMonths),
                        joined: store.hasVaccineTemplate(template),
                        statusText: doseStatusText(for: template),
                        statusTint: doseStatusTint(for: template),
                        statusInk: doseStatusInk(for: template),
                        onAdd: { store.addVaccineFromTemplate(template) }
                    )
                }
            }
            .padding(.top, 14)
        }
    }

    private func scopedTemplates(in group: VaccineTemplateGroup) -> [VaccineTemplate] {
        switch scope {
        case .current:
            return group.templates.filter { template in
                !store.hasVaccineTemplate(template) && template.ageMonths <= currentAgeMonths + 2
            }
        case .all:
            return group.templates
        case .free:
            return group.templates.filter(\.isProgramVaccine)
        case .paid:
            return group.templates.filter { !$0.isProgramVaccine }
        }
    }

    private func doseStatusText(for template: VaccineTemplate) -> String {
        if store.hasVaccineTemplate(template) { return "已加入" }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: store.recommendedDate(forMonths: template.ageMonths))
        ).day ?? 0
        if days < 0 { return "已到月龄" }
        if days <= 30 { return "近 30 天" }
        return "稍后"
    }

    private func doseStatusTint(for template: VaccineTemplate) -> Color {
        let status = doseStatusText(for: template)
        if status == "已加入" { return Palette.mintTint }
        if status == "已到月龄" { return Palette.dangerTint }
        if status == "近 30 天" { return Palette.yellow }
        return Palette.bg2
    }

    private func doseStatusInk(for template: VaccineTemplate) -> Color {
        let status = doseStatusText(for: template)
        if status == "已加入" { return Palette.mint600 }
        if status == "已到月龄" { return Palette.dangerInk }
        if status == "近 30 天" { return Palette.yellowInk }
        return Palette.ink3
    }
}

private struct VaccineTemplateGroupRow: View {
    let group: VaccineTemplateGroup
    let joinedCount: Int
    let totalCount: Int
    let currentAgeMonths: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous).fill(iconTint)
                    AppIcon.Syringe(size: 22, color: iconInk)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .appFont(size: 16, weight: .heavy)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        chip(group.ageRangeLabel, ink: Palette.ink3, bg: Palette.bg2)
                        chip(group.costSummary, ink: group.costSummary.contains("自费") ? Palette.yellowInk : Palette.mint600,
                             bg: group.costSummary.contains("自费") ? Palette.yellow : Palette.mintTint)
                        if joinedCount > 0 {
                            chip("已加 \(joinedCount)/\(totalCount)", ink: Palette.mint600, bg: Palette.mintTint)
                        }
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                AppIcon.Chevron(size: 15, color: Palette.ink3)
            }
            .padding(16)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
            .shadowCard()
        }
        .buttonStyle(PressableStyle())
    }

    private var iconTint: Color {
        if group.templates.contains(where: { abs($0.ageMonths - currentAgeMonths) <= 1 }) {
            return Palette.yellow
        }
        return Palette.mintTint
    }

    private var iconInk: Color {
        if group.templates.contains(where: { abs($0.ageMonths - currentAgeMonths) <= 1 }) {
            return Palette.yellowInk
        }
        return Palette.mint600
    }

    private func chip(_ text: String, ink: Color, bg: Color) -> some View {
        Text(text)
            .appFont(size: 10, weight: .heavy)
            .foregroundStyle(ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
    }
}

private struct VaccineDoseTemplateRow: View {
    let template: VaccineTemplate
    let recommendedDate: Date
    let joined: Bool
    let statusText: String
    let statusTint: Color
    let statusInk: Color
    let onAdd: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .appText(.cardTitle)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                    if let dose = template.doseIndex {
                        chip("第 \(dose) 剂", ink: Palette.ink3, bg: Palette.bg2)
                    } else if let label = template.doseKindLabel {
                        chip(label, ink: Palette.ink3, bg: Palette.bg2)
                    }
                    chip(template.costLabel, ink: template.isProgramVaccine ? Palette.mint600 : Palette.yellowInk,
                         bg: template.isProgramVaccine ? Palette.mintTint : Palette.yellow)
                }
                Text("推荐接种日期：\(formatDate(recommendedDate)) · \(template.ageLabel)")
                    .appFont(size: 13, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
                chip(statusText, ink: statusInk, bg: statusTint)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Text(joined ? "已加入" : "加入")
                    .appFont(size: 13, weight: .heavy)
                    .foregroundStyle(joined ? Palette.ink3 : store.theme.primary600)
                    .padding(.horizontal, 13)
                    .frame(height: 38)
                    .background(joined ? Palette.bg2 : store.theme.primaryTint, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .disabled(joined)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                .strokeBorder(joined ? Palette.line : Color.clear, lineWidth: 1)
        )
        .shadowCard()
    }

    private func chip(_ text: String, ink: Color, bg: Color) -> some View {
        Text(text)
            .appFont(size: 10, weight: .heavy)
            .foregroundStyle(ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
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
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(Palette.ink)
                        if let dd = vaccine.doneDate {
                            Text("\(vaccine.ageLabel) · 已于 \(formatDate(dd)) 接种")
                                .appFont(size: 12, weight: .semibold)
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("编辑")
                        .appFont(size: 11, weight: .heavy)
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

private struct VaccineCompleteSheet: View {
    let vaccine: Vaccine
    let onClose: () -> Void
    @Environment(AppStore.self) private var store
    @State private var doneDate: Date

    init(vaccine: Vaccine, onClose: @escaping () -> Void) {
        self.vaccine = vaccine
        self.onClose = onClose
        self._doneDate = State(initialValue: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "记录接种", onBack: onClose)
            ScreenBody {
                Card {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous).fill(Palette.mintTint)
                            AppIcon.Syringe(size: 24, color: Palette.mint600)
                        }
                        .frame(width: 50, height: 50)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(vaccine.name)
                                .appText(.cardTitle)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(2)
                            Text("计划 \(vaccine.scheduledDate.map { formatDate($0) } ?? vaccine.ageLabel)")
                                .appFont(size: 13, weight: .semibold)
                                .foregroundStyle(Palette.ink3)
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 0)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        FieldLabel(text: "接种日期")
                        DatePicker("", selection: $doneDate, displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .datePickerStyle(.graphical)
                            .padding(8)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                }
                .padding(.top, 14)

                CTAButton(title: "保存接种记录", theme: store.theme) {
                    store.completeVaccine(vaccine.id, on: doneDate)
                    onClose()
                }
                .padding(.top, 18)
            }
        }
        .background(Palette.bg)
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
                                        .appFont(size: 16, weight: .semibold)
                                        .foregroundStyle(Palette.ink)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    FieldLabel(text: "接种日期")
                                    DatePicker("", selection: $doneDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .environment(\.locale, Locale(identifier: "zh_CN"))
                                        .datePickerStyle(.graphical)
                                        .padding(10)
                                        .frame(maxWidth: .infinity)
                                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
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
                                    .appFont(size: 13, weight: .bold)
                                Text(vaccine.isCustom ? "删除此疫苗" : "从我的计划中移除")
                                    .appFont(size: 14, weight: .heavy)
                            }
                            .foregroundStyle(Palette.dangerInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.dangerTint, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: 560)
            .background(Palette.bg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())

                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.dangerInk, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
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
