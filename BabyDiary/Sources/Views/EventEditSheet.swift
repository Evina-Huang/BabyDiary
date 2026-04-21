import SwiftUI

// Edit sheet for existing events. Field structure mirrors each add flow:
// diaper is a type picker, feed (breast) is side + minutes, feed (formula)
// is ml, sleep is start+end, solid is name + amount stepper + notes. Title
// and sub strings are always rebuilt from the structured inputs — never
// free-text-edited — to match the new-record experience.
struct EventEditSheet: View {
    let original: Event
    let onCancel: () -> Void
    let onSave: (Event) -> Void
    let onDelete: (Event) -> Void

    @Environment(AppStore.self) private var store

    // Shared
    @State private var at: Date
    @State private var showConfirm = false
    @State private var showDeleteConfirm = false

    // Sleep
    @State private var endAt: Date

    // Diaper
    enum DType: String, Hashable, CaseIterable { case wet, dirty, both
        var label: String { self == .wet ? "湿尿布" : self == .dirty ? "臭臭" : "两者都有" }
        var sub: String { self == .wet ? "只有尿" : self == .dirty ? "便便" : "湿 + 便便" }
        var emoji: String { self == .wet ? "💧" : self == .dirty ? "💩" : "💧💩" }
    }
    @State private var dType: DType = .wet

    // Feed
    enum FeedMode: String, Hashable { case breast, formula }
    enum BreastSide: String, Hashable, CaseIterable { case left, right, both
        var label: String { self == .left ? "左侧" : self == .right ? "右侧" : "双侧" }
    }
    enum FirstSide: String, Hashable, CaseIterable { case left, right
        var label: String { self == .left ? "先左后右" : "先右后左" }
    }
    @State private var feedMode: FeedMode = .breast
    @State private var breastSide: BreastSide = .left
    @State private var breastMinutes: Int = 15    // used when side is single
    @State private var leftMinutes: Int = 10
    @State private var rightMinutes: Int = 10
    @State private var firstSide: FirstSide = .left
    @State private var ml: Int = 120

    // Solid
    enum SolidUnit: String, Hashable { case g, ml }
    @State private var foodName: String = ""
    @State private var amount: Int = 30
    @State private var solidUnit: SolidUnit = .g
    @State private var solidNote: String = ""

    init(event: Event,
         onCancel: @escaping () -> Void,
         onSave: @escaping (Event) -> Void,
         onDelete: @escaping (Event) -> Void) {
        self.original = event
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _at = State(initialValue: event.at)
        _endAt = State(initialValue: event.endAt ?? event.at.addingTimeInterval(30 * 60))

        // Parse existing data per kind
        switch event.kind {
        case .diaper:
            if event.title.contains("湿") && !event.title.contains("便") { _dType = .init(initialValue: .wet) }
            else if event.title.contains("臭") || event.title == "便便" || event.title.contains("便") && !event.title.contains("两") { _dType = .init(initialValue: .dirty) }
            else { _dType = .init(initialValue: .both) }
        case .feed:
            let isFormula = event.title.contains("奶粉")
            _feedMode = .init(initialValue: isFormula ? .formula : .breast)
            if isFormula {
                _ml = .init(initialValue: Self.firstInt(in: event.sub ?? "") ?? 120)
            } else {
                let sub = event.sub ?? ""
                if event.title.contains("双") {
                    _breastSide = .init(initialValue: .both)
                    // Parse "左 X分 · 右 Y分 · 共 Z分" — the first side mentioned is firstSide.
                    let l = Self.minutesAfter("左", in: sub) ?? 10
                    let r = Self.minutesAfter("右", in: sub) ?? 10
                    _leftMinutes = .init(initialValue: l)
                    _rightMinutes = .init(initialValue: r)
                    let lIdx = sub.range(of: "左")?.lowerBound
                    let rIdx = sub.range(of: "右")?.lowerBound
                    if let lIdx, let rIdx {
                        _firstSide = .init(initialValue: rIdx < lIdx ? .right : .left)
                    } else {
                        _firstSide = .init(initialValue: .left)
                    }
                } else if event.title.contains("右") {
                    _breastSide = .init(initialValue: .right)
                    _breastMinutes = .init(initialValue: Self.firstInt(in: sub) ?? 15)
                } else {
                    _breastSide = .init(initialValue: .left)
                    _breastMinutes = .init(initialValue: Self.firstInt(in: sub) ?? 15)
                }
            }
        case .solid:
            _foodName = .init(initialValue: event.title)
            let sub = event.sub ?? ""
            let parts = sub.components(separatedBy: " · ")
            let head = parts.first ?? ""
            _amount = .init(initialValue: Self.firstInt(in: head) ?? 30)
            _solidUnit = .init(initialValue: head.contains("ml") ? .ml : .g)
            _solidNote = .init(initialValue: parts.count > 1 ? parts.dropFirst().joined(separator: " · ") : "")
        case .sleep:
            break
        }
    }

    // Find the first integer that appears after the given marker character.
    // e.g. minutesAfter("左", in: "左 18分 · 右 12分") -> 18
    private static func minutesAfter(_ marker: Character, in s: String) -> Int? {
        guard let idx = s.firstIndex(of: marker) else { return nil }
        return firstInt(in: String(s[idx...]))
    }

    private static func firstInt(in s: String) -> Int? {
        var cur = ""
        var nums: [Int] = []
        for ch in s {
            if ch.isNumber { cur.append(ch) }
            else if !cur.isEmpty { if let n = Int(cur) { nums.append(n) }; cur = "" }
        }
        if !cur.isEmpty, let n = Int(cur) { nums.append(n) }
        return nums.first
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "编辑\(original.kind.label)", onBack: onCancel)
            ScreenBody {
                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        kindForm
                        timeField(label: original.kind == .sleep ? "开始时间" : "时间",
                                  binding: $at)
                        if original.kind == .sleep {
                            timeField(label: "结束时间", binding: $endAt)
                            if endAt <= at {
                                hintText("结束时间需晚于开始时间", warn: true)
                            } else {
                                hintText("持续 \(formatDur(endAt.timeIntervalSince(at)))")
                            }
                        }
                    }
                }
                CTAButton(title: "保存",
                          variant: canSave ? .primary : .ghost,
                          theme: store.theme,
                          action: attemptSave)
                    .padding(.top, 18)
                    .disabled(!canSave)
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(PressableStyle())

                Button { showDeleteConfirm = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                        Text("删除这条记录")
                            .font(.system(size: 14, weight: .heavy))
                            .tracking(-0.14)
                    }
                    .foregroundStyle(Color(hex: 0xFF7F64))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: 0xFF7F64).opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 18)
            }
        }
        .background(Palette.bg)
        .alert("确认改动", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认修改") { commit() }
        } message: {
            Text(confirmMessage)
        }
        .alert("删除这条记录？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { onDelete(original) }
        } message: {
            Text("删除后无法恢复。")
        }
    }

    // MARK: — Kind-specific forms

    @ViewBuilder
    private var kindForm: some View {
        switch original.kind {
        case .diaper: diaperForm
        case .feed:   feedForm
        case .solid:  solidForm
        case .sleep:  EmptyView()
        }
    }

    private var diaperForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "类型")
            ForEach(DType.allCases, id: \.self) { o in
                Button { dType = o } label: {
                    HStack(spacing: 12) {
                        Text(o.emoji).font(.system(size: 20))
                            .frame(width: 36, height: 36)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(o.label)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                            Text(o.sub)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer(minLength: 0)
                        Circle()
                            .strokeBorder(dType == o ? store.theme.primary600 : Palette.line,
                                          lineWidth: dType == o ? 6 : 2)
                            .background(Circle().fill(Color.white))
                            .frame(width: 22, height: 22)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(dType == o ? store.theme.primaryTint : Palette.bg2,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var feedForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "方式")
                Text(feedMode == .breast ? "母乳" : "奶粉")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Palette.ink)
            }
            if feedMode == .breast {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "侧别")
                    HStack(spacing: 8) {
                        ForEach(BreastSide.allCases, id: \.self) { s in
                            Button { breastSide = s } label: {
                                Text(s.label)
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(breastSide == s ? .white : Palette.ink2)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(breastSide == s ? store.theme.primary : Palette.bg2,
                                                in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                if breastSide == .both {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "顺序")
                        HStack(spacing: 8) {
                            ForEach(FirstSide.allCases, id: \.self) { f in
                                Button { firstSide = f } label: {
                                    Text(f.label)
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundStyle(firstSide == f ? .white : Palette.ink2)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(firstSide == f ? store.theme.primary : Palette.bg2,
                                                    in: Capsule())
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "左侧 (分钟)")
                        StepperInput(value: $leftMinutes, step: 1, min: 0, max: 120, suffix: "分钟")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "右侧 (分钟)")
                        StepperInput(value: $rightMinutes, step: 1, min: 0, max: 120, suffix: "分钟")
                    }
                    hintText("总时长 \(leftMinutes + rightMinutes) 分钟")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "时长 (分钟)")
                        StepperInput(value: $breastMinutes, step: 1, min: 1, max: 120, suffix: "分钟")
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "奶量 (ml)")
                    StepperInput(value: $ml, step: 10, min: 10, max: 300, suffix: "ml")
                }
            }
        }
    }

    private var solidForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "食物名称")
                TextField("食物名称", text: $foodName)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "份量")
                HStack(spacing: 10) {
                    StepperInput(value: $amount, step: 5, min: 5, max: 500, suffix: solidUnit.rawValue)
                    SegPill(selection: $solidUnit, options: [(.g, "g"), (.ml, "ml")])
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "备注 (可选)")
                TextField("例如 第一次吃、过敏反应", text: $solidNote)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: — Shared fragments

    private func timeField(label: String, binding: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: label)
            DatePicker("", selection: binding, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.wheel)
                .tint(store.theme.primary600)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .environment(\.locale, Locale(identifier: "zh_CN"))
        }
    }

    private func hintText(_ s: String, warn: Bool = false) -> some View {
        Text(s)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(warn ? Color(hex: 0xFF7F64) : Palette.ink3)
    }

    // MARK: — Validation + save

    private var canSave: Bool {
        switch original.kind {
        case .sleep: return endAt > at
        case .solid: return !foodName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private var needsConfirm: Bool {
        if at > Date().addingTimeInterval(60) { return true }
        if abs(at.timeIntervalSince(original.at)) > 12 * 3600 { return true }
        if original.kind == .sleep {
            if endAt > Date().addingTimeInterval(60) { return true }
            if abs(endAt.timeIntervalSince(original.endAt ?? original.at)) > 12 * 3600 { return true }
        }
        return false
    }

    private var confirmMessage: String {
        if at > Date() || (original.kind == .sleep && endAt > Date()) {
            return "修改后的时间在未来，确认要保存吗？"
        }
        return "时间调整超过 12 小时，确认要保存吗？"
    }

    private func attemptSave() {
        guard canSave else { return }
        if needsConfirm { showConfirm = true } else { commit() }
    }

    private func commit() {
        var e = original
        e.at = at
        switch original.kind {
        case .diaper:
            e.title = dType.label
            e.sub = dType.sub
        case .feed:
            if feedMode == .breast {
                e.title = "母乳 · \(breastSide.label)"
                switch breastSide {
                case .left, .right:
                    e.sub = "\(breastMinutes) 分钟"
                case .both:
                    let total = leftMinutes + rightMinutes
                    let first = firstSide == .left
                        ? "左 \(leftMinutes)分 · 右 \(rightMinutes)分"
                        : "右 \(rightMinutes)分 · 左 \(leftMinutes)分"
                    e.sub = "\(first) · 共 \(total)分"
                }
            } else {
                e.title = "奶粉"
                e.sub = "\(ml) ml"
            }
        case .solid:
            e.title = foodName.trimmingCharacters(in: .whitespaces)
            let amt = "\(amount)\(solidUnit.rawValue)"
            let note = solidNote.trimmingCharacters(in: .whitespaces)
            e.sub = note.isEmpty ? amt : "\(amt) · \(note)"
        case .sleep:
            e.endAt = endAt
            let dur = endAt.timeIntervalSince(at)
            e.title = "睡眠 \(formatDurShort(dur))"
            e.sub = "\(hhmm(at)) — \(hhmm(endAt))"
        }
        onSave(e)
    }
}

private func hhmm(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
}
