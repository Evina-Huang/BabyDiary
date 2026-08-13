import SwiftUI
import UIKit

/// A low-attention recorder that deliberately exposes only the four everyday
/// care categories. Opening the sheet is step one; sleep/feed start on the next
/// tap, while diaper and solids add one explicit verification tap.
struct NightQuickRecordScreen: View {
    let onBack: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pendingConfirmation: PendingConfirmation?
    @State private var diaperType: DiaperEventType = .wet
    @State private var solidName = "米糊"
    @State private var showSaved = false
    @State private var isCompleting = false

    private enum PendingConfirmation: Equatable {
        case diaper
        case solid
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "夜间快速记录", onBack: onBack)

            ScreenBody {
                if dynamicTypeSize.isAccessibilitySize {
                    actionGrid
                        .padding(.top, 4)
                    intro
                        .padding(.top, 16)
                } else {
                    intro
                        .padding(.top, 4)
                    actionGrid
                        .padding(.top, 18)
                }

                if let pendingConfirmation {
                    confirmationCard(for: pendingConfirmation)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(Palette.bg)
        .overlay(alignment: .top) {
            RecordSuccessToast(isPresented: showSaved, title: savedTitle)
                .padding(.top, 12)
        }
        .onAppear {
            diaperType = store.preferredNightDiaperType
            solidName = store.preferredNightSolidName
        }
    }

    private var actionColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var actionGrid: some View {
        LazyVGrid(columns: actionColumns, spacing: 12) {
            quickAction(kind: .sleep, detail: sleepDetail, action: startSleep)
            quickAction(kind: .feed, detail: feedDetail, action: startFeed)
            quickAction(kind: .diaper, detail: "确认类型后保存") {
                pendingConfirmation = .diaper
            }
            quickAction(kind: .solid, detail: "确认常用食物后保存") {
                pendingConfirmation = .solid
            }
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(Palette.lavender)
                AppIcon.Moon(size: 28, color: Palette.lavenderInk)
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("少看、少选、快速完成")
                    .appText(.cardTitle)
                    .foregroundStyle(Palette.ink)
                Text("睡眠和喂奶会立即开始计时；尿布与辅食会在保存前让你确认。")
                    .appText(.body)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func quickAction(kind: EventKind, detail: String, action: @escaping () -> Void) -> some View {
        let style = CategoryStyle.forKind(kind, iconSize: 26)
        let selected = confirmationKind == kind

        return Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(Palette.card.opacity(0.72))
                    style.icon
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(actionTitle(for: kind))
                            .appText(.cardTitle)
                            .foregroundStyle(style.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if selected {
                            AppIcon.Check(size: 14, color: style.ink)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(detail)
                        .appText(.caption)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(selected ? style.tint : Palette.card,
                        in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                    .stroke(selected ? style.ink.opacity(0.42) : Palette.line,
                            lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(isCompleting)
        .accessibilityLabel(actionTitle(for: kind))
        .accessibilityValue(selected ? "已选择，等待确认" : detail)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var confirmationKind: EventKind? {
        switch pendingConfirmation {
        case .diaper: return .diaper
        case .solid: return .solid
        case nil: return nil
        }
    }

    private func actionTitle(for kind: EventKind) -> String {
        switch kind {
        case .sleep:
            return store.activeTimer?.kind == .sleep ? "继续睡眠" : "开始睡眠"
        case .feed:
            return store.feedDraft?.hasActiveState == true ? "继续喂奶" : "开始喂奶"
        case .diaper:
            return "记录尿布"
        case .solid:
            return "记录辅食"
        }
    }

    private var sleepDetail: String {
        store.activeTimer?.kind == .sleep ? "已有计时，回到进行中记录" : "一键开始计时"
    }

    private var feedDetail: String {
        store.feedDraft?.hasActiveState == true ? "已有计时，回到进行中记录" : "从建议侧开始计时"
    }

    @ViewBuilder
    private func confirmationCard(for confirmation: PendingConfirmation) -> some View {
        Card(padding: 16, surfaceStyle: .elevated) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    AppIcon.Check(size: 20, color: confirmationInk)
                        .frame(width: 28, height: 28)
                        .background(confirmationTint, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("保存前确认")
                            .appText(.cardTitle)
                            .foregroundStyle(Palette.ink)
                        Text(confirmationPrompt)
                            .appText(.body)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                switch confirmation {
                case .diaper:
                    diaperPicker
                case .solid:
                    solidConfirmation
                }

                CTAButton(title: confirmationButtonTitle, theme: store.theme) {
                    confirmAndSave(confirmation)
                }
                .disabled(isCompleting)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var diaperPicker: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { diaperButtons }
            VStack(spacing: 8) { diaperButtons }
        }
    }

    @ViewBuilder
    private var diaperButtons: some View {
        ForEach(DiaperEventType.allCases, id: \.self) { option in
            let selected = diaperType == option
            Button {
                diaperType = option
            } label: {
                HStack(spacing: 6) {
                    if selected {
                        AppIcon.Check(size: 13, color: Palette.blueInk)
                    }
                    Text(option.label)
                        .appText(.label)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(selected ? Palette.blueInk : Palette.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(selected ? Palette.blue : Palette.bg2,
                            in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                        .stroke(selected ? Palette.blueInk.opacity(0.35) : Palette.line, lineWidth: 1)
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(option.label)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private var solidConfirmation: some View {
        HStack(spacing: 12) {
            CategoryIcon(kind: .solid, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(solidName)
                    .appText(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                Text("常用食物 · 少量")
                    .appText(.caption)
                    .foregroundStyle(Palette.ink3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.yellow.opacity(0.62),
                    in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("辅食，\(solidName)，少量")
    }

    private var confirmationPrompt: String {
        switch pendingConfirmation {
        case .diaper: return "已预选上次使用的类型，可更改后确认保存。"
        case .solid: return "将使用最近记录的常用食物，并按少量保存。"
        case nil: return ""
        }
    }

    private var confirmationButtonTitle: String {
        switch pendingConfirmation {
        case .diaper: return "确认记录\(diaperType.label)"
        case .solid: return "确认记录\(solidName)"
        case nil: return "确认保存"
        }
    }

    private var confirmationTint: Color {
        pendingConfirmation == .diaper ? Palette.blue : Palette.yellow
    }

    private var confirmationInk: Color {
        pendingConfirmation == .diaper ? Palette.blueInk : Palette.yellowInk
    }

    private var savedTitle: String {
        switch pendingConfirmation {
        case .diaper: return "尿布记录已保存"
        case .solid: return "辅食记录已保存"
        case nil: return "记录已保存"
        }
    }

    private func startSleep() {
        let status = store.startSleepFromShortcut()
        let message = status == .started ? "睡眠计时已开始" : "睡眠计时正在进行，继续记录"
        finishImmediateAction(message)
    }

    private func startFeed() {
        let status = store.startFeedFromShortcut()
        let message = status == .started ? "喂奶计时已开始" : "喂奶计时正在进行，继续记录"
        finishImmediateAction(message)
    }

    private func finishImmediateAction(_ message: String) {
        guard !isCompleting else { return }
        isCompleting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            AppAccessibility.announce(message)
        }
    }

    private func confirmAndSave(_ confirmation: PendingConfirmation) {
        guard !isCompleting else { return }
        isCompleting = true
        switch confirmation {
        case .diaper:
            store.recordDiaperFromShortcut(type: diaperType)
        case .solid:
            store.recordSolidFromShortcut(foodName: solidName)
        }
        RecordSaveFeedback.complete(isPresented: $showSaved, delay: 0.7, then: onBack)
    }
}
