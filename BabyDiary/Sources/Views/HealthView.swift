import SwiftUI

struct HealthView: View {
    let onOpen: (SubScreen) -> Void
    let onOpenGrowth: () -> Void
    @Environment(AppStore.self) private var store

    init(
        onOpen: @escaping (SubScreen) -> Void,
        onOpenGrowth: @escaping () -> Void = {}
    ) {
        self.onOpen = onOpen
        self.onOpenGrowth = onOpenGrowth
    }

    private var tasks: [HealthTask] {
        store.healthTasks()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenBody {
                pageHeader
                    .padding(.bottom, 18)

                if let highestPriorityTask = tasks.first {
                    taskHero(highestPriorityTask)

                    let remainingTasks = Array(tasks.dropFirst().prefix(3))
                    if !remainingTasks.isEmpty {
                        taskList(remainingTasks)
                            .padding(.top, 20)
                    }
                } else {
                    calmState
                }

                toolsHeader
                    .padding(.top, 28)
                    .padding(.bottom, 10)

                healthDirectory
            }
        }
        .background(Palette.bg)
    }

    private var pageHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Text("健康")
                .appText(.pageTitle)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            if !tasks.isEmpty {
                Text("\(tasks.count) 项待办")
                    .appText(.captionEmphasis)
                    .monospacedDigit()
                    .foregroundStyle(highestPriorityStyle.ink)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(highestPriorityStyle.tint, in: Capsule())
                    .accessibilityLabel("共有\(tasks.count)项健康待办")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highestPriorityStyle: HealthTaskVisualStyle {
        tasks.first.map(taskStyle) ?? .calm
    }

    private func taskHero(_ task: HealthTask) -> some View {
        let style = taskStyle(task)
        return Button { open(task.destination) } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    taskIcon(task, size: 24, color: style.ink)
                        .frame(width: 48, height: 48)
                        .background(Palette.card.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(style.label)
                            .appText(.captionEmphasis)
                            .foregroundStyle(style.ink)
                        Text(task.title)
                            .appText(.cardTitle)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Text(task.detail)
                    .appText(.body)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(task.actionTitle)
                        .appText(.button)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(style.ink)
                .frame(minHeight: 44)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(style.ink.opacity(0.14))
                        .frame(height: 1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.tint, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                    .stroke(style.ink.opacity(0.16), lineWidth: 1)
            }
            .appSurface(.elevated)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.label)，\(task.title)，\(task.detail)")
        .accessibilityHint(task.actionTitle)
    }

    private func taskList(_ items: [HealthTask]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("接下来")
                .appText(.sectionTitle)
                .foregroundStyle(Palette.ink)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                    if index > 0 {
                        Rectangle()
                            .fill(Palette.line)
                            .frame(height: 1)
                            .padding(.leading, 60)
                    }
                    taskRow(task)
                }
            }
            .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            }
        }
    }

    private func taskRow(_ task: HealthTask) -> some View {
        let style = taskStyle(task)
        return Button { open(task.destination) } label: {
            HStack(alignment: .top, spacing: 12) {
                taskIcon(task, size: 20, color: style.ink)
                    .frame(width: 40, height: 40)
                    .background(style.tint, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(style.label)
                        .appText(.captionEmphasis)
                        .foregroundStyle(style.ink)
                    Text(task.title)
                        .appText(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(task.detail)
                        .appText(.caption)
                        .foregroundStyle(Palette.ink3)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Text(task.actionTitle)
                    .appText(.captionEmphasis)
                    .foregroundStyle(style.ink)
                    .multilineTextAlignment(.trailing)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.label)，\(task.title)，\(task.detail)")
        .accessibilityHint(task.actionTitle)
    }

    private var calmState: some View {
        HStack(alignment: .top, spacing: 14) {
            AppIcon.Check(size: 23, color: Palette.mint600)
                .frame(width: 44, height: 44)
                .background(Palette.mintTint, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))

            Text("当前没有需要处理的健康事项")
                .appText(.cardTitle)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var toolsHeader: some View {
        Text("健康工具")
            .appText(.sectionTitle)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var healthDirectory: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.line).frame(height: 1)
            healthRecordRow(
                title: "疫苗接种",
                subtitle: vaccineSubtitle,
                tint: Palette.mintTint,
                icon: { AppIcon.Shield(size: 21, color: Palette.mint600) },
                onTap: { onOpen(.vaccine) }
            )
            directoryDivider
            healthRecordRow(
                title: "用药记录",
                subtitle: medicationSubtitle,
                tint: Palette.blue,
                icon: { AppIcon.Pill(size: 21, color: Palette.blueInk) },
                onTap: { onOpen(.medication) }
            )
            directoryDivider
            healthRecordRow(
                title: "食物与过敏",
                subtitle: foodSubtitle,
                tint: Palette.yellow,
                icon: { AppIcon.Bowl(size: 21, color: Palette.yellowInk) },
                onTap: { onOpen(.foodList) }
            )
            directoryDivider
            healthRecordRow(
                title: "我的食谱",
                subtitle: recipeSubtitle,
                tint: Palette.pink,
                icon: { AppIcon.Bowl(size: 21, color: Palette.pinkInk) },
                onTap: { onOpen(.recipeList) }
            )
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }

    private func healthRecordRow<Icon: View>(
        title: String,
        subtitle: String?,
        tint: Color,
        @ViewBuilder icon: () -> Icon,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                icon()
                    .frame(width: 40, height: 40)
                    .background(tint, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .appText(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .appText(.caption)
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 6)
                AppIcon.Chevron(size: 14, color: Palette.ink3)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("打开\(title)")
    }

    private var directoryDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 1)
            .padding(.leading, 68)
    }

    @ViewBuilder
    private func taskIcon(_ task: HealthTask, size: CGFloat, color: Color) -> some View {
        switch task.kind {
        case .foodAllergy, .foodObservationDue:
            AppIcon.Bowl(size: size, color: color)
        case .medicationAllergy, .medicationReview:
            AppIcon.Pill(size: size, color: color)
        case .overdueVaccine, .upcomingVaccine:
            AppIcon.Shield(size: size, color: color)
        case .growthCheck:
            AppIcon.Chart(size: size, color: color)
        }
    }

    private func taskStyle(_ task: HealthTask) -> HealthTaskVisualStyle {
        switch task.priority {
        case .critical:
            return .init(label: "重要提醒", tint: Palette.dangerTint, ink: Palette.dangerInk)
        case .overdue:
            return .init(label: "已逾期", tint: Palette.pink, ink: Palette.pinkInk)
        case .today:
            return .init(label: "今日确认", tint: Palette.yellow, ink: Palette.yellowInk)
        case .upcoming:
            return .init(label: "即将到期", tint: Palette.blue, ink: Palette.blueInk)
        case .recommendation:
            let label = task.kind == .medicationReview ? "建议复查" : "建议记录"
            return .init(label: label, tint: Palette.mintTint, ink: Palette.mint600)
        }
    }

    private func open(_ destination: HealthTaskDestination) {
        switch destination {
        case .vaccine: onOpen(.vaccine)
        case .foodList: onOpen(.foodList)
        case .medication: onOpen(.medication)
        case .growth: onOpenGrowth()
        }
    }

    private var vaccineSubtitle: String {
        let done = store.vaccines.filter(\.done).count
        let total = store.vaccines.count
        if total == 0 { return "添加接种计划与进度" }
        return "已完成 \(done) / \(total)"
    }

    private var foodSubtitle: String {
        let total = store.foods.count
        let observing = store.foods.filter { $0.status == .observing }.count
        guard total > 0 else { return "暂无记录" }
        var parts = ["\(total) 种食材"]
        if observing > 0 { parts.append("观察中 \(observing)") }
        return parts.joined(separator: " · ")
    }

    private var recipeSubtitle: String? {
        let count = store.recipes.count
        return count == 0 ? nil : "\(count) 个食谱"
    }

    private var medicationSubtitle: String {
        let total = store.medications.count
        guard total > 0 else { return "记录药名、剂量与用药反应" }
        return "\(total) 条记录"
    }
}

private struct HealthTaskVisualStyle {
    let label: String
    let tint: Color
    let ink: Color

    static let calm = HealthTaskVisualStyle(
        label: "状态安心",
        tint: Palette.mintTint,
        ink: Palette.mint600
    )
}

#Preview("健康") {
    HealthView(onOpen: { _ in })
        .environment(AppStore.preview)
}
