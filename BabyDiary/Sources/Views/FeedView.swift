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
    @State private var saved = false

    // Breast sub-mode (timer vs manual)
    @State private var bSub: FormulaSub = .timer
    @State private var bManualMinL: Int = 10
    @State private var bManualMinR: Int = 0
    @State private var bManualTime: Date = .now

    // Breast timer state
    @State private var bPhase: Phase = .idle
    @State private var bActive: Side = .L
    @State private var bLeftMs: TimeInterval = 0
    @State private var bRightMs: TimeInterval = 0
    @State private var bSegStart: Date? = nil
    @State private var bSessionStart: Date? = nil

    // Formula state
    @State private var fSub: FormulaSub = .timer
    @State private var fPhase: Phase = .idle
    @State private var fDurMs: TimeInterval = 0
    @State private var fSegStart: Date? = nil
    @State private var fSessionStart: Date? = nil
    @State private var fSessionEnd: Date? = nil
    @State private var ml: Int = 120
    @State private var time: Date = .now

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
            if let last = lastFeed {
                mode = last.title.contains("奶粉") ? .formula : .breast
                bActive = last.title.contains("右") ? .R : .L
            }
        }
    }

    private var lastFeed: Event? {
        store.events.filter { $0.kind == .feed }.max(by: { $0.at < $1.at })
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let isIdle = bPhase == .idle && fPhase == .idle

        if let last = lastFeed, isIdle {
            RepeatLastBar(last: last) { repeatLast(last) }
                .padding(.bottom, 14)
        }

        SegPill(selection: $mode, options: [(.breast, "母乳"), (.formula, "奶粉")])
            .frame(maxWidth: .infinity)

        if mode == .breast {
            breastSection(now: now)
        } else {
            formulaSection(now: now)
        }

        historySection.padding(.top, 26)
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
            InlineWheelTimePicker(time: $bManualTime, theme: store.theme)
            CTAButton(title: saved ? "✓ 已保存" : "保存记录",
                      variant: saved ? .secondary : .primary,
                      theme: store.theme,
                      action: saveBreastManual)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func breastTimerBlock(liveL: TimeInterval, liveR: TimeInterval, total: TimeInterval) -> some View {
        VStack(spacing: 14) {
            if lastFeed != nil, bPhase == .idle {
                Text("💡 上次从\(bActive == .R ? "右" : "左")边结束")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                SideButton(side: .L, label: "左边", ms: liveL,
                           active: bActive == .L && bPhase != .idle, phase: bPhase) { startOn(.L) }
                SideButton(side: .R, label: "右边", ms: liveR,
                           active: bActive == .R && bPhase != .idle, phase: bPhase) { startOn(.R) }
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
                HStack(spacing: 10) {
                    CTAButton(title: bPhase == .running ? "⏸ 暂停" : "▶ 继续",
                              variant: .ghost, theme: store.theme) {
                        bPhase == .running ? pauseBreast() : resumeBreast()
                    }
                    CTAButton(title: saved ? "✓ 已保存" : "完成,保存",
                              variant: saved ? .secondary : .primary, theme: store.theme,
                              action: saveBreast)
                        .layoutPriority(2)
                }
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
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(active ? Palette.pinkInk : Palette.ink2)
                    Text(formatMMSS(ms))
                        .font(.system(size: 28, weight: .black))
                        .tracking(-0.56)
                        .monospacedDigit()
                        .foregroundStyle(active ? Palette.pinkInk : Palette.ink)
                    if active, phase == .running {
                        HStack(spacing: 5) {
                            Circle().fill(Palette.pinkInk).frame(width: 6, height: 6)
                            Text("计时中")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.6)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(Palette.pinkInk)
                    } else if active, phase == .paused {
                        Text("已暂停")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.pinkInk)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20).padding(.horizontal, 12)
                .background(active ? Palette.pink : Palette.bg2,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }

    // MARK: — Formula mode

    @ViewBuilder
    private func formulaSection(now: Date) -> some View {
        let live = fPhase == .running && fSegStart != nil
            ? fDurMs + now.timeIntervalSince(fSegStart!) : fDurMs

        VStack(spacing: 16) {
            SegPill(selection: $fSub, options: [(.timer, "计时"), (.manual, "手动输入")])

            if fSub == .timer {
                VStack(spacing: 14) {
                    VStack(spacing: 4) {
                        Text(formatMMSS(live))
                            .font(.system(size: 46, weight: .black))
                            .tracking(-1.38)
                            .monospacedDigit()
                            .foregroundStyle(fPhase == .idle ? Palette.ink3 : Palette.pinkInk)
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
                                .foregroundStyle(Palette.pinkInk)
                        } else if fPhase == .stopped, let s = fSessionStart, let e = fSessionEnd {
                            Text("\(hhmm(s)) – \(hhmm(e))")
                                .font(.system(size: 13, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(Palette.pinkInk.opacity(0.75))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16).padding(.vertical, 22)
                    .background(fPhase == .idle ? Palette.bg2 : Palette.pink,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    formulaActionRow
                }
            } else {
                mlInput
                manualTimePicker
                CTAButton(title: saved ? "✓ 已保存" : "保存记录",
                          variant: saved ? .secondary : .primary,
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
                CTAButton(title: "✓ 停止", theme: store.theme, action: stopFormula).layoutPriority(2)
            }
        case .paused:
            HStack(spacing: 10) {
                CTAButton(title: "▶ 继续", variant: .ghost, theme: store.theme, action: resumeFormula)
                CTAButton(title: "✓ 停止", theme: store.theme, action: stopFormula).layoutPriority(2)
            }
        case .stopped:
            mlInput
            HStack(spacing: 10) {
                CTAButton(title: "重来", variant: .ghost, theme: store.theme, action: resetFormula)
                CTAButton(title: saved ? "✓ 已保存" : "保存记录",
                          variant: saved ? .secondary : .primary,
                          theme: store.theme,
                          action: saveFormulaTimer)
                    .layoutPriority(2)
            }
        }
    }

    private var mlInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel(text: "奶量 (ml)")
            StepperInput(value: $ml, step: 10, min: 10, max: 300, suffix: "ml")
            HStack(spacing: 8) {
                ForEach([60, 90, 120, 150, 180], id: \.self) { v in
                    Button {
                        ml = v
                    } label: {
                        Text("\(v)ml")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ml == v ? .white : Palette.ink2)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(ml == v ? store.theme.primary : Palette.bg2,
                                        in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var manualTimePicker: some View {
        InlineWheelTimePicker(time: $time, theme: store.theme)
    }

    // MARK: — History

    private var historySection: some View {
        let history = Array(store.events.filter { $0.kind == .feed }.prefix(20))
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
                        EmptyStateView(title: "还没有喂奶记录",
                                       subtitle: "\(store.baby.name)喝奶的每一口都会记录在这里")
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

    // MARK: — Actions

    private func repeatLast(_ last: Event) {
        let now = Date()
        store.addEvent(.init(kind: .feed, at: now, title: last.title, sub: last.sub))
        flash()
    }

    private func startOn(_ side: Side) {
        let now = Date()
        switch bPhase {
        case .idle:
            bActive = side; bSegStart = now; bSessionStart = now; bPhase = .running
        case .running:
            if side != bActive { _ = bankBreast(); bActive = side; bSegStart = now }
        case .paused:
            bActive = side; bSegStart = now; bPhase = .running
        case .stopped: break
        }
    }

    @discardableResult
    private func bankBreast() -> (TimeInterval, TimeInterval) {
        guard bPhase == .running, let start = bSegStart else { return (bLeftMs, bRightMs) }
        let add = Date().timeIntervalSince(start)
        if bActive == .L { bLeftMs += add } else { bRightMs += add }
        return (bLeftMs, bRightMs)
    }

    private func pauseBreast() { _ = bankBreast(); bSegStart = nil; bPhase = .paused }
    private func resumeBreast() { bSegStart = Date(); bPhase = .running }
    private func resetBreast() {
        bPhase = .idle; bLeftMs = 0; bRightMs = 0; bSegStart = nil; bSessionStart = nil
    }
    private func saveBreast() {
        let (l, r) = bankBreast()
        guard l + r >= 1 else { return }
        let now = Date()
        let lMin = max(1, Int((l / 60).rounded()))
        let rMin = max(1, Int((r / 60).rounded()))
        let tot = max(1, Int(((l + r) / 60).rounded()))
        let title: String; let sub: String
        if l > 0 && r > 0 {
            title = "母乳 · 双侧"; sub = "左 \(lMin)分 · 右 \(rMin)分 · 共 \(tot)分"
        } else if l > 0 {
            title = "母乳 · 左侧"; sub = "\(tot) 分钟"
        } else {
            title = "母乳 · 右侧"; sub = "\(tot) 分钟"
        }
        store.addEvent(.init(kind: .feed, at: now, endAt: now, title: title, sub: sub))
        resetBreast(); flash()
    }

    private func saveBreastManual() {
        let l = bManualMinL, r = bManualMinR
        guard l + r > 0 else { return }
        let tot = l + r
        let title: String; let sub: String
        if l > 0 && r > 0 {
            title = "母乳 · 双侧"; sub = "左 \(l)分 · 右 \(r)分 · 共 \(tot)分"
        } else if l > 0 {
            title = "母乳 · 左侧"; sub = "\(tot) 分钟"
        } else {
            title = "母乳 · 右侧"; sub = "\(tot) 分钟"
        }
        store.addEvent(.init(kind: .feed, at: bManualTime, endAt: bManualTime, title: title, sub: sub))
        bManualMinL = 10; bManualMinR = 0; bManualTime = Date()
        flash()
    }

    private func startFormula() {
        let now = Date()
        fSessionStart = now; fSessionEnd = nil
        fSegStart = now; fDurMs = 0; fPhase = .running
    }
    @discardableResult
    private func bankFormula() -> TimeInterval {
        guard fPhase == .running, let start = fSegStart else { return fDurMs }
        fDurMs += Date().timeIntervalSince(start)
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
        store.addEvent(.init(kind: .feed, at: e,
                             title: "奶粉",
                             sub: "\(ml)ml · \(hhmm(s))–\(hhmm(e))"))
        resetFormula(); flash()
    }
    private func saveFormulaManual() {
        store.addEvent(.init(kind: .feed, at: time, title: "奶粉", sub: "\(ml)ml"))
        time = Date(); flash()
    }

    private func flash() {
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { saved = false }
    }
}

// MARK: — Reusable stepper input + Repeat-last bar

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

private struct RepeatLastBar: View {
    let last: Event
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("↻")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Palette.mint600)
                    .frame(width: 28, height: 28)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("一键重复上次")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.66)
                        .textCase(.uppercase)
                        .opacity(0.75)
                    Text("\(last.title)\(last.sub.map { " · \($0)" } ?? "")")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(-0.14)
                }
                .foregroundStyle(Palette.mint600)
                Spacer(minLength: 0)
                AppIcon.Plus(size: 16, color: Palette.mint600)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Palette.mintTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
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
