import SwiftUI

// The big feed-tracking sheet. Two modes — 母乳 (breast) with L/R
// alternating timers, and 奶粉 (formula) with a single timer or manual
// ml entry. Matches feed.jsx beat-for-beat.
struct FeedScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    enum Mode: String, Hashable { case breast, formula }
    enum FormulaSub: String, Hashable { case timer, manual }
    enum Phase: String, Hashable { case idle, running, paused, stopped }
    enum Side: String, Hashable { case L, R }

    @State private var mode: Mode = .breast

    // Breast sub-mode (timer vs manual)
    @State private var bSub: FormulaSub = .timer
    @State private var bManualMinL: Int = 10
    @State private var bManualMinR: Int = 0
    @State private var bManualTime: Date = .now
    @State private var bManualFirstSide: Side = .L

    // Breast timer state
    @State private var bPhase: Phase = .idle
    @State private var bActive: Side = .L
    @State private var bFirstSide: Side? = nil
    @State private var bLeftMs: TimeInterval = 0
    @State private var bRightMs: TimeInterval = 0
    @State private var bSegStart: Date? = nil
    @State private var bSessionStart: Date? = nil
    @State private var bSessionEnd: Date? = nil

    // Formula state
    @State private var fSub: FormulaSub = .manual
    @State private var fPhase: Phase = .idle
    @State private var fDurMs: TimeInterval = 0
    @State private var fSegStart: Date? = nil
    @State private var fSessionStart: Date? = nil
    @State private var fSessionEnd: Date? = nil
    @State private var ml: Int = 210
    @State private var time: Date = .now

    private let formulaPresetValues = [120, 150, 180, 210, 240]

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "喂奶记录", onBack: onBack)
            ScreenBody {
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    content(now: ctx.date)
                }
            }
        }
        .background(Palette.bg)
        .onAppear {
            restoreDraft()
        }
        .onChange(of: currentDraft) { _, _ in
            syncDraftToStore()
        }
        .onDisappear(perform: syncDraftToStore)
    }

    private var lastFeed: Event? {
        store.mostRecentEvent(kind: .feed)
    }

    private var lastBreastFeed: Event? {
        store.mostRecentBreastFeedEvent()
    }

    private var recommendedBreastSide: Side {
        guard let endingSide = lastBreastFeed?.breastEndingSide else { return .L }
        return endingSide == .right ? .R : .L
    }

    private func restoredFirstSide(from draft: FeedDraft) -> Side? {
        if let firstSide = draft.breastFirstSide {
            return firstSide == .left ? .L : .R
        }
        if draft.breastLeftDuration == 0, draft.breastRightDuration == 0 {
            return draft.breastActiveSide == .left ? .L : .R
        }
        if draft.breastLeftDuration == 0 {
            return .R
        }
        if draft.breastRightDuration == 0 {
            return .L
        }
        return nil
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let isIdle = bPhase == .idle && fPhase == .idle

        SegPill(selection: $mode, options: [(.breast, "母乳"), (.formula, "奶粉")])
            .frame(maxWidth: .infinity)
            .disabled(!isIdle)
            .opacity(isIdle ? 1 : 0.65)

        if mode == .breast {
            breastSection(now: now)
        } else {
            formulaSection(now: now)
        }
    }

    // MARK: — Breast mode

    @ViewBuilder
    private func breastSection(now: Date) -> some View {
        let liveL = bPhase == .running && bActive == .L && bSegStart != nil
            ? bLeftMs + now.timeIntervalSince(bSegStart!) : bLeftMs
        let liveR = bPhase == .running && bActive == .R && bSegStart != nil
            ? bRightMs + now.timeIntervalSince(bSegStart!) : bRightMs
        let total = liveL + liveR

        VStack(spacing: 14) {
            SegPill(selection: $bSub, options: [(.timer, "计时"), (.manual, "手动输入")])
                .disabled(bPhase != .idle)

            if bSub == .manual {
                breastManualForm
            } else {
                breastTimerBlock(liveL: liveL, liveR: liveR, total: total)
            }
        }
        .padding(.top, 22)
    }

    private var breastManualForm: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                FieldLabel(text: "左侧(分钟)")
                StepperInput(value: $bManualMinL, step: 1, min: 0, max: 120, suffix: "分")
            }
            VStack(alignment: .leading, spacing: 10) {
                FieldLabel(text: "右侧(分钟)")
                StepperInput(value: $bManualMinR, step: 1, min: 0, max: 120, suffix: "分")
            }
            breastManualOrderPicker
            InlineWheelTimePicker(time: $bManualTime, theme: store.theme)
            CTAButton(title: "保存记录",
                      variant: .primary,
                      theme: store.theme,
                      action: saveBreastManual)
                .padding(.top, 4)
        }
    }

    private var breastManualOrderPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "双侧顺序")
            HStack(spacing: 8) {
                manualOrderButton(side: .L, title: "先左后右")
                manualOrderButton(side: .R, title: "先右后左")
            }
        }
    }

    private func manualOrderButton(side: Side, title: String) -> some View {
        Button {
            bManualFirstSide = side
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .foregroundStyle(bManualFirstSide == side ? .white : Palette.ink2)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(bManualFirstSide == side ? store.theme.primary : Palette.bg2,
                            in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func breastTimerBlock(liveL: TimeInterval, liveR: TimeInterval, total: TimeInterval) -> some View {
        let lastEndedSide = lastBreastFeed?.breastEndingSide
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                SideButton(side: .L, label: "左边", ms: liveL,
                           active: bActive == .L && bPhase != .idle,
                           phase: bPhase,
                           showsLastEndedHint: bPhase == .idle && lastEndedSide == .left) { startOn(.L) }
                SideButton(side: .R, label: "右边", ms: liveR,
                           active: bActive == .R && bPhase != .idle,
                           phase: bPhase,
                           showsLastEndedHint: bPhase == .idle && lastEndedSide == .right) { startOn(.R) }
            }

            if bPhase == .idle {
                Text("轻触任一侧开始计时")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            } else {
                Text(String(format: "共 %d 分 %d 秒", Int(total / 60), Int(total) % 60))
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.52)
                    .foregroundStyle(Palette.ink3)
            }

            if bPhase != .idle {
                CTAButton(title: "完成,保存",
                          variant: .primary, theme: store.theme,
                          action: saveBreast)
                Button("清空重来") { resetBreast() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.ink3)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private struct SideButton: View {
        let side: Side
        let label: String
        let ms: TimeInterval
        let active: Bool
        let phase: Phase
        let showsLastEndedHint: Bool
        let action: () -> Void

        var body: some View {
            let isPaused = active && phase == .paused
            let sideInk = side == .L ? Palette.blueInk : Palette.pinkInk
            let sideTint = side == .L ? Palette.blue : Palette.pink
            let accent = isPaused ? Palette.yellowInk : sideInk
            let background = isPaused ? Palette.yellow : active ? sideTint : sideTint.opacity(0.45)
            let border = active ? accent.opacity(0.78) : sideInk.opacity(0.28)
            Button(action: action) {
                VStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(active ? accent : sideInk)
                    Text(formatMMSS(ms))
                        .font(.system(size: 34, weight: .black))
                        .tracking(-0.68)
                        .monospacedDigit()
                        .foregroundStyle(active ? accent : Palette.ink)
                    statusLabel(accent: accent)
                        .frame(height: 18)
                }
                .frame(maxWidth: .infinity, minHeight: 132)
                .padding(.vertical, 24).padding(.horizontal, 14)
                .background(background,
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(border, lineWidth: active ? 2.5 : 1.5)
                )
                .shadowCard()
            }
            .buttonStyle(PressableStyle())
        }

        @ViewBuilder
        private func statusLabel(accent: Color) -> some View {
            if active, phase == .running {
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text("计时中")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                }
                .foregroundStyle(accent)
            } else if active, phase == .paused {
                Text("已暂停")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.yellowInk)
            } else if showsLastEndedHint {
                Text("上次从\(side == .L ? "左" : "右")边结束")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.2)
                    .foregroundStyle(accent.opacity(0.78))
            } else {
                Text("计时中")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(.clear)
            }
        }
    }

    // MARK: — Formula mode

    @ViewBuilder
    private func formulaSection(now: Date) -> some View {
        let live = fPhase == .running && fSegStart != nil
            ? fDurMs + now.timeIntervalSince(fSegStart!) : fDurMs

        VStack(spacing: 16) {
            SegPill(selection: $fSub, options: [(.timer, "计时"), (.manual, "手动输入")])
                .disabled(fPhase != .idle)
                .opacity(fPhase == .idle ? 1 : 0.65)

            if fSub == .timer {
                VStack(spacing: 14) {
                    VStack(spacing: 4) {
                        Text(formatMMSS(live))
                            .font(.system(size: 46, weight: .black))
                            .tracking(-1.38)
                            .monospacedDigit()
                            .foregroundStyle(timerInk(for: fPhase))
                        if fPhase == .running {
                            HStack(spacing: 6) {
                                Circle().fill(Palette.pinkInk).frame(width: 6, height: 6)
                                Text("计时中")
                                    .font(.system(size: 11, weight: .heavy))
                                    .tracking(0.66)
                                    .textCase(.uppercase)
                            }
                            .foregroundStyle(Palette.pinkInk)
                        } else if fPhase == .paused {
                            Text("已暂停")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(0.66)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.yellowInk)
                        } else if fPhase == .stopped, let s = fSessionStart, let e = fSessionEnd {
                            Text("\(hhmm(s)) - \(hhmm(e))")
                                .font(.system(size: 13, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(Palette.pinkInk.opacity(0.75))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16).padding(.vertical, 22)
                    .background(timerTint(for: fPhase),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    formulaActionRow
                }
            } else {
                mlInput
                manualTimePicker
                CTAButton(title: "保存记录",
                          variant: .primary,
                          theme: store.theme,
                          action: saveFormulaManual)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 22)
    }

    @ViewBuilder
    private var formulaActionRow: some View {
        switch fPhase {
        case .idle:
            CTAButton(title: "▶ 开始计时", theme: store.theme, action: startFormula)
        case .running:
            HStack(spacing: 10) {
                CTAButton(title: "⏸ 暂停", variant: .ghost, theme: store.theme, action: pauseFormula)
                    .frame(maxWidth: .infinity)
                CTAButton(title: "✓ 停止", theme: store.theme, action: stopFormula)
                    .frame(maxWidth: .infinity)
            }
        case .paused:
            HStack(spacing: 10) {
                CTAButton(title: "▶ 继续", variant: .ghost, theme: store.theme, action: resumeFormula)
                    .frame(maxWidth: .infinity)
                CTAButton(title: "✓ 停止", theme: store.theme, action: stopFormula)
                    .frame(maxWidth: .infinity)
            }
        case .stopped:
            mlInput
            HStack(spacing: 10) {
                CTAButton(title: "重来", variant: .ghost, theme: store.theme, action: resetFormula)
                    .frame(maxWidth: .infinity)
                CTAButton(title: "保存记录",
                          variant: .primary,
                          theme: store.theme,
                          action: saveFormulaTimer)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var mlInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel(text: "奶量 (ml)")
            StepperInput(value: $ml, step: 10, min: 10, max: 300, suffix: "ml")
            HStack(spacing: 8) {
                ForEach(formulaPresetValues, id: \.self) { v in
                    Button {
                        ml = v
                    } label: {
                        Text("\(v) ml")
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                            .foregroundStyle(ml == v ? .white : Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6).padding(.vertical, 10)
                            .background(ml == v ? store.theme.primary : Palette.bg2,
                                        in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var manualTimePicker: some View {
        InlineWheelTimePicker(time: $time, theme: store.theme)
    }

    private func timerInk(for phase: Phase) -> Color {
        switch phase {
        case .idle:
            return Palette.ink3
        case .paused:
            return Palette.yellowInk
        case .running, .stopped:
            return Palette.pinkInk
        }
    }

    private func timerTint(for phase: Phase) -> Color {
        switch phase {
        case .idle:
            return Palette.bg2
        case .paused:
            return Palette.yellow
        case .running, .stopped:
            return Palette.pink
        }
    }

    // MARK: — Actions

    private func startOn(_ side: Side) {
        let now = Date()
        switch bPhase {
        case .idle:
            bActive = side
            bFirstSide = side
            bSegStart = now
            bSessionStart = now
            bSessionEnd = nil
            bPhase = .running
        case .running:
            if side == bActive {
                pauseBreast(at: now)
            } else {
                _ = bankBreast(at: now)
                bActive = side
                bSegStart = now
            }
        case .paused:
            bActive = side; bSegStart = now; bSessionEnd = nil; bPhase = .running
        case .stopped: break
        }
    }

    @discardableResult
    private func bankBreast(at now: Date = Date()) -> (TimeInterval, TimeInterval) {
        guard bPhase == .running, let start = bSegStart else { return (bLeftMs, bRightMs) }
        let add = now.timeIntervalSince(start)
        if bActive == .L { bLeftMs += add } else { bRightMs += add }
        return (bLeftMs, bRightMs)
    }

    private func pauseBreast(at now: Date = Date()) {
        _ = bankBreast(at: now)
        bSegStart = nil
        bSessionEnd = now
        bPhase = .paused
    }
    private func resumeBreast() {
        bSegStart = Date()
        bSessionEnd = nil
        bPhase = .running
    }
    private func resetBreast() {
        bPhase = .idle
        bActive = recommendedBreastSide
        bFirstSide = nil
        bLeftMs = 0
        bRightMs = 0
        bSegStart = nil
        bSessionStart = nil
        bSessionEnd = nil
    }
    private func saveBreast() {
        let now = Date()
        let (l, r) = bankBreast(at: now)
        let end = bPhase == .running ? now : (bSessionEnd ?? now)
        guard l + r >= 1, let start = bSessionStart else { return }
        let lMin = max(1, Int((l / 60).rounded()))
        let rMin = max(1, Int((r / 60).rounded()))
        let tot = max(1, Int(((l + r) / 60).rounded()))
        let title: String; let sub: String
        if l > 0 && r > 0 {
            let firstSide: BreastFeedSide = (bFirstSide ?? .L) == .L ? .left : .right
            title = "母乳 · 双侧"
            sub = orderedBreastFeedSummary(leftMinutes: lMin, rightMinutes: rMin, firstSide: firstSide)
        } else if l > 0 {
            title = "母乳 · 左侧"; sub = "\(tot)分"
        } else {
            title = "母乳 · 右侧"; sub = "\(tot)分"
        }
        let correctedEnd = correctedBreastTimerEnd(start: start, end: end, activeDuration: l + r)
        store.addEvent(.init(kind: .feed, at: start, endAt: correctedEnd, title: title, sub: sub))
        resetBreast()
        onBack()
    }

    private func saveBreastManual() {
        let l = bManualMinL, r = bManualMinR
        guard l + r > 0 else { return }
        let tot = l + r
        let title: String; let sub: String
        if l > 0 && r > 0 {
            let firstSide: BreastFeedSide = bManualFirstSide == .L ? .left : .right
            title = "母乳 · 双侧"
            sub = orderedBreastFeedSummary(leftMinutes: l, rightMinutes: r, firstSide: firstSide)
        } else if l > 0 {
            title = "母乳 · 左侧"; sub = "\(tot)分"
        } else {
            title = "母乳 · 右侧"; sub = "\(tot)分"
        }
        store.addEvent(.init(kind: .feed, at: bManualTime, endAt: bManualTime, title: title, sub: sub))
        onBack()
    }

    private func startFormula() {
        let now = Date()
        fSessionStart = now; fSessionEnd = nil
        fSegStart = now; fDurMs = 0; fPhase = .running
    }
    @discardableResult
    private func bankFormula(at now: Date = Date()) -> TimeInterval {
        guard fPhase == .running, let start = fSegStart else { return fDurMs }
        fDurMs += now.timeIntervalSince(start)
        return fDurMs
    }
    private func pauseFormula() { _ = bankFormula(); fSegStart = nil; fPhase = .paused }
    private func resumeFormula() { fSegStart = Date(); fPhase = .running }
    private func stopFormula() { _ = bankFormula(); fSessionEnd = Date(); fSegStart = nil; fPhase = .stopped }
    private func resetFormula() {
        fPhase = .idle; fDurMs = 0; fSegStart = nil; fSessionStart = nil; fSessionEnd = nil
    }
    private func saveFormulaTimer() {
        guard fPhase == .stopped, let s = fSessionStart, let e = fSessionEnd else { return }
        store.addEvent(.init(kind: .feed, at: s,
                             endAt: e,
                             title: "奶粉",
                             sub: "\(ml) ml · \(hhmm(s)) - \(hhmm(e))"))
        resetFormula()
        onBack()
    }
    private func saveFormulaManual() {
        store.addEvent(.init(kind: .feed, at: time, title: "奶粉", sub: "\(ml) ml"))
        onBack()
    }

    private var currentDraft: FeedDraft {
        FeedDraft(
            mode: mode == .breast ? .breast : .formula,
            breastSubMode: bSub == .timer ? .timer : .manual,
            breastManualLeftMinutes: bManualMinL,
            breastManualRightMinutes: bManualMinR,
            breastManualTime: bManualTime,
            breastPhase: draftPhase(from: bPhase),
            breastActiveSide: bActive == .L ? .left : .right,
            breastFirstSide: bFirstSide.map { $0 == .L ? .left : .right },
            breastLeftDuration: bLeftMs,
            breastRightDuration: bRightMs,
            breastSegmentStart: bSegStart,
            breastSessionStart: bSessionStart,
            breastSessionEnd: bSessionEnd,
            formulaSubMode: fSub == .timer ? .timer : .manual,
            formulaPhase: draftPhase(from: fPhase),
            formulaDuration: fDurMs,
            formulaSegmentStart: fSegStart,
            formulaSessionStart: fSessionStart,
            formulaSessionEnd: fSessionEnd,
            formulaMilliliters: ml,
            formulaTime: time
        )
    }

    private func restoreDraft() {
        if let draft = store.feedDraft, draft.hasActiveState {
            mode = draft.mode == .breast ? .breast : .formula
            bSub = draft.breastSubMode == .timer ? .timer : .manual
            bManualMinL = draft.breastManualLeftMinutes
            bManualMinR = draft.breastManualRightMinutes
            bManualTime = draft.breastManualTime
            bPhase = phase(from: draft.breastPhase)
            bActive = draft.breastActiveSide == .left ? .L : .R
            let restoredSide = restoredFirstSide(from: draft)
            bFirstSide = restoredSide
            bManualFirstSide = restoredSide ?? bActive
            bLeftMs = draft.breastLeftDuration
            bRightMs = draft.breastRightDuration
            bSegStart = draft.breastSegmentStart
            bSessionStart = draft.breastSessionStart
            bSessionEnd = draft.breastSessionEnd

            fSub = draft.formulaSubMode == .timer ? .timer : .manual
            fPhase = phase(from: draft.formulaPhase)
            fDurMs = draft.formulaDuration
            fSegStart = draft.formulaSegmentStart
            fSessionStart = draft.formulaSessionStart
            fSessionEnd = draft.formulaSessionEnd
            ml = draft.formulaMilliliters
            time = draft.formulaTime
            return
        }

        if let last = lastFeed {
            mode = last.isFormulaFeed ? .formula : .breast
        }
        bActive = recommendedBreastSide
        bManualFirstSide = recommendedBreastSide
    }

    private func syncDraftToStore() {
        store.syncFeedDraft(currentDraft.hasActiveState ? currentDraft : nil)
    }

    private func draftPhase(from phase: Phase) -> FeedDraftPhase {
        switch phase {
        case .idle: return .idle
        case .running: return .running
        case .paused: return .paused
        case .stopped: return .stopped
        }
    }

    private func phase(from phase: FeedDraftPhase) -> Phase {
        switch phase {
        case .idle: return .idle
        case .running: return .running
        case .paused: return .paused
        case .stopped: return .stopped
        }
    }

    private func correctedBreastTimerEnd(start: Date, end: Date, activeDuration: TimeInterval) -> Date {
        let measuredEnd = start.addingTimeInterval(max(0, activeDuration))
        guard end.timeIntervalSince(measuredEnd) > Event.staleFeedTimerTolerance else { return end }
        return measuredEnd
    }
}

// MARK: — Reusable stepper input

struct StepperInput: View {
    @Binding var value: Int
    var step: Int = 1
    var min: Int = 0
    var max: Int = 999
    var suffix: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            StepBtn(symbol: "−") { value = Swift.max(min, value - step) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(value)")
                    .font(.system(size: 30, weight: .black))
                    .tracking(-0.6)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.ink3)
                }
            }
            .frame(maxWidth: .infinity)
            StepBtn(symbol: "+") { value = Swift.min(max, value + step) }
        }
        .padding(6)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private struct StepBtn: View {
        let symbol: String
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Text(symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
            }
            .buttonStyle(PressableStyle())
        }
    }
}

// MARK: — Shared helpers

private func formatMMSS(_ s: TimeInterval) -> String {
    let total = Int(max(0, s))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
private func hhmm(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
}

#Preview("喂奶记录") {
    FeedScreen(onBack: {})
        .environment(AppStore.preview)
}
