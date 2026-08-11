import SwiftUI

// Edit sheet for existing events. Field structure mirrors each add flow:
// diaper is a type picker + optional stool note, feed (breast) is side +
// minutes, feed (formula) is ml, sleep is start+end, solid is name + amount
// stepper + notes. Title and sub strings are always rebuilt from the
// structured inputs — never free-text-edited — to match the new-record
// experience.
struct EventEditSheet: View {
    private enum ExpandedTimeField {
        case start
        case end
    }

    let original: Event
    let onCancel: () -> Void
    let onSave: (Event) -> Void
    let onDelete: (Event) -> Void

    @Environment(AppStore.self) private var store

    // Shared
    @State private var at: Date
    @State private var showConfirm = false
    @State private var showDeleteConfirm = false
    @State private var expandedTimeField: ExpandedTimeField?

    // Sleep
    @State private var endAt: Date

    // Diaper
    @State private var dType: DiaperEventType = .wet
    @State private var diaperNote: String = ""

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
            let parsedType = DiaperEventType.from(title: event.title)
            _dType = .init(initialValue: parsedType)
            _diaperNote = .init(initialValue: parsedType.allowsNote ? (event.sub ?? "") : "")
        case .feed:
            let isFormula = event.title.contains("奶粉") || event.title.contains("配方奶")
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
                recordSummary

                if original.kind != .sleep {
                    sectionLabel("记录内容")
                        .padding(.top, 24)
                    Card {
                        kindForm
                    }
                }

                sectionLabel(original.kind == .sleep ? "睡眠时间" : "记录时间")
                    .padding(.top, 24)
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        timeField(label: original.kind == .sleep ? "开始" : "发生时间",
                                  binding: $at,
                                  field: .start)
                        if original.kind == .sleep {
                            timeField(label: "结束",
                                      binding: $endAt,
                                      field: .end)
                            if endAt <= at {
                                hintText("结束时间需晚于开始时间", warn: true)
                            } else {
                                durationSummary
                            }
                        }
                    }
                }

                CTAButton(title: "保存",
                          variant: canSave ? .primary : .ghost,
                          theme: store.theme,
                          action: attemptSave)
                    .padding(.top, 24)
                    .disabled(!canSave)
                Button(action: onCancel) {
                    Text("取消")
                        .appFont(size: 15, weight: .semibold)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                }
                .buttonStyle(PressableStyle())

                dangerZone
                    .padding(.top, 24)
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

    private var recordSummary: some View {
        let style = CategoryStyle.forKind(original.kind, iconSize: 29)
        let display = recordDisplayText(for: original)

        return HStack(spacing: 14) {
            CategoryIcon(kind: original.kind, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                MicroLabel(text: "当前记录")
                Text(display.title)
                    .appFont(size: 17, weight: .bold)
                    .tracking(-0.2)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(formatDateLabel(original.at)) · \(formatTime(original.at))")
                    .appFont(size: 13, weight: .semibold)
                    .foregroundStyle(style.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(style.tint.opacity(0.62),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(style.ink.opacity(0.08), lineWidth: 1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .appFont(size: 16, weight: .bold)
            .tracking(-0.16)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicroLabel(text: "删除记录")
            Button { showDeleteConfirm = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("删除这条记录")
                            .appFont(size: 15, weight: .bold)
                            .foregroundStyle(Palette.pinkInk)
                        Text("删除后无法恢复")
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 12)
                    Text("删除")
                        .appFont(size: 13, weight: .bold)
                        .foregroundStyle(Palette.pinkInk)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Palette.pink, in: Capsule())
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 68)
                .background(Palette.card,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.pink.opacity(0.8), lineWidth: 1)
                }
            }
            .buttonStyle(PressableStyle())
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
        VStack(alignment: .leading, spacing: 12) {
            FieldLabel(text: "类型")
            HStack(spacing: 8) {
                ForEach(DiaperEventType.allCases, id: \.self) { option in
                    let selected = dType == option
                    Button {
                        dType = option
                        if !option.allowsNote {
                            diaperNote = ""
                        }
                    } label: {
                        Text(option.label)
                            .appFont(size: 13, weight: .bold)
                            .foregroundStyle(selected ? Palette.blueInk : Palette.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 46)
                            .background(selected ? Palette.blue : Palette.bg2,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected ? Palette.blueInk.opacity(0.14) : Palette.line,
                                            lineWidth: 1)
                            }
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            if dType.allowsNote {
                diaperNotePicker
                    .padding(.top, 4)
            }
        }
    }

    private var diaperNotePicker: some View {
        let noteOptions = DiaperNotePreset.options(including: diaperNote)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                FieldLabel(text: "备注")
                if !diaperNote.isEmpty {
                    Button("清空") { diaperNote = "" }
                        .appFont(size: 12, weight: .bold)
                        .foregroundStyle(Palette.ink3)
                        .frame(minWidth: 44, minHeight: 44)
                        .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(noteOptions, id: \.self) { note in
                    let on = diaperNote == note
                    Button {
                        diaperNote = on ? "" : note
                    } label: {
                        Text(note)
                            .appFont(size: 13, weight: .heavy)
                            .tracking(-0.13)
                            .foregroundStyle(on ? Palette.yellowInk : Palette.ink2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(on ? Palette.yellow : Palette.bg2,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            TextField("自己填写", text: $diaperNote)
                .appFont(size: 16, weight: .semibold)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var feedForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "方式")
                Text(feedMode == .breast ? "母乳" : "奶粉")
                    .appFont(size: 15, weight: .bold)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .background(Palette.bg2,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if feedMode == .breast {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "侧别")
                    HStack(spacing: 8) {
                        ForEach(BreastSide.allCases, id: \.self) { s in
                            Button { breastSide = s } label: {
                                Text(s.label)
                                    .appFont(size: 13, weight: .heavy)
                                    .foregroundStyle(breastSide == s ? .white : Palette.ink2)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(breastSide == s ? store.theme.primary : Palette.bg2,
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                        .appFont(size: 13, weight: .heavy)
                                        .foregroundStyle(firstSide == f ? .white : Palette.ink2)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(firstSide == f ? store.theme.primary : Palette.bg2,
                                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    StepperInput(
                        value: $ml,
                        step: 10,
                        min: AppStore.minFormulaMilliliters,
                        max: AppStore.maxFormulaMilliliters,
                        suffix: "ml"
                    )
                }
            }
        }
    }

    private var solidForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "食物名称")
                TextField("食物名称", text: $foodName)
                    .appFont(size: 16, weight: .semibold)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
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
                    .appFont(size: 16, weight: .semibold)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: — Shared fragments

    private func timeField(label: String,
                           binding: Binding<Date>,
                           field: ExpandedTimeField) -> some View {
        let isExpanded = expandedTimeField == field
        let accent = timeFieldAccent(for: field)

        return VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: label)
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.92)) {
                        expandedTimeField = isExpanded ? nil : field
                    }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(hhmm(binding.wrappedValue))
                                    .appFont(size: 28, weight: .black)
                                    .tracking(-0.72)
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.ink)
                                Text(formatDateLabel(binding.wrappedValue))
                                    .appFont(size: 14, weight: .heavy)
                                    .foregroundStyle(accent.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(accent.badge, in: Capsule())
                            }
                            Text(timeDetail(binding.wrappedValue))
                                .appFont(size: 12, weight: .semibold)
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer(minLength: 0)
                        Text(isExpanded ? "收起" : "调整")
                            .appFont(size: 12, weight: .heavy)
                            .foregroundStyle(isExpanded ? accent.ink : Palette.ink2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isExpanded ? accent.badge : Palette.card.opacity(0.72),
                                        in: Capsule())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, isExpanded ? 10 : 14)
                .background(isExpanded ? accent.surfaceStrong : accent.surfaceSoft,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isExpanded ? accent.borderStrong : accent.borderSoft, lineWidth: 1)
                }

                if isExpanded {
                    DatePicker("", selection: binding, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .tint(store.theme.primary600)
                        .frame(maxWidth: .infinity)
                        .frame(height: 178)
                        .clipped()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .offset(y: -3)
                        .background(Palette.bg2,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .transition(
                            .asymmetric(
                                insertion: .offset(y: -14)
                                    .combined(with: .scale(scale: 0.985, anchor: .top))
                                    .combined(with: .opacity),
                                removal: .offset(y: -8)
                                    .combined(with: .scale(scale: 0.995, anchor: .top))
                                    .combined(with: .opacity)
                            )
                        )
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isExpanded)
        }
    }

    private func timeFieldAccent(for field: ExpandedTimeField) -> (surfaceSoft: Color,
                                                                   surfaceStrong: Color,
                                                                   badge: Color,
                                                                   wheel: Color,
                                                                   ink: Color,
                                                                   borderSoft: Color,
                                                                   borderStrong: Color) {
        switch field {
        case .start:
            return (
                Palette.bg2,
                store.theme.primaryTint,
                store.theme.primaryTint,
                Palette.bg2,
                store.theme.primary600,
                Palette.line,
                store.theme.primary.opacity(0.34)
            )
        case .end:
            return (
                Palette.bg2,
                Palette.mint.opacity(0.72),
                store.theme.primaryTint,
                Palette.bg2,
                store.theme.primary600,
                Palette.line,
                Palette.mint600.opacity(0.24)
            )
        }
    }

    private func timeDetail(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return weekdayText(date)
        }
        if calendar.isDateInYesterday(date) {
            return weekdayText(date)
        }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return weekdayText(date)
        }
        return yearDateText(date)
    }

    private var durationSummary: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                MicroLabel(text: "睡眠时长")
                Text(formatDur(endAt.timeIntervalSince(at)))
                    .appFont(size: 18, weight: .black)
                    .tracking(-0.36)
                    .foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [store.theme.primaryTint, Palette.card],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.card.opacity(0.6), lineWidth: 1)
        }
    }

    private func hintText(_ s: String, warn: Bool = false) -> some View {
        Text(s)
            .appFont(size: 12, weight: .semibold)
            .foregroundStyle(warn ? Palette.pinkInk : Palette.ink3)
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
            let trimmedNote = diaperNote.trimmingCharacters(in: .whitespacesAndNewlines)
            e.sub = dType.allowsNote && !trimmedNote.isEmpty ? trimmedNote : nil
        case .feed:
            if feedMode == .breast {
                e.title = "母乳 · \(breastSide.label)"
                switch breastSide {
                case .left, .right:
                    e.sub = "\(breastMinutes)分"
                case .both:
                    e.sub = orderedBreastFeedSummary(
                        leftMinutes: leftMinutes,
                        rightMinutes: rightMinutes,
                        firstSide: firstSide == .left ? .left : .right
                    )
                }
            } else {
                e.title = original.title.contains("配方奶") ? "配方奶" : "奶粉"
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
            e.sub = "\(hhmm(at)) - \(hhmm(endAt))"
        }
        onSave(e)
    }
}

private func hhmm(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
}

private func weekdayText(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "EEEE"
    return f.string(from: d)
}

private func yearDateText(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = "yyyy年M月d日"
    return f.string(from: d)
}
