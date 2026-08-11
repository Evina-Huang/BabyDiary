import SwiftUI

// MARK: — 出牙记录

struct TeethScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store
    @State private var editing: ToothPosition? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "出牙记录", onBack: onBack)
            ScreenBody {
                statCard.padding(.top, 4)
                chartCard.padding(.top, 22)
                timelineBlock.padding(.top, 22)
            }
        }
        .background(Palette.bg)
        .sheet(item: $editing) { pos in
            ToothEditSheet(
                position: pos,
                initial: store.tooth(at: pos),
                theme: store.theme,
                onCancel: { editing = nil },
                onSave: { date, note in
                    store.setTooth(pos, eruptedAt: date, note: note)
                    editing = nil
                },
                onClear: {
                    store.setTooth(pos, eruptedAt: nil, note: nil)
                    editing = nil
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: — 顶部统计

    private var erupted: [ToothRecord] {
        store.teeth.filter { $0.eruptedAt != nil }
            .sorted { ($0.eruptedAt ?? .distantPast) < ($1.eruptedAt ?? .distantPast) }
    }

    private var statCard: some View {
        let count = erupted.count
        let latest = erupted.last?.eruptedAt
        let latestText: String = {
            guard let d = latest else { return "还没有记录" }
            let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
            if days <= 0 { return "最近一颗 · 今天" }
            if days == 1 { return "最近一颗 · 昨天" }
            return "最近一颗 · \(days) 天前"
        }()

        return Card(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("乳牙进度")
                            .appFont(size: 17, weight: .black)
                            .tracking(-0.18)
                            .foregroundStyle(Palette.ink)
                        Text(latestText)
                            .appFont(size: 12, weight: .bold)
                            .foregroundStyle(Palette.ink3)
                    }

                    Spacer(minLength: 12)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(count)")
                            .appFont(size: 30, weight: .black)
                            .monospacedDigit()
                            .foregroundStyle(store.theme.primary600)
                        Text("/ 20 颗")
                            .appFont(size: 13, weight: .heavy)
                            .foregroundStyle(Palette.ink3)
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(store.theme.primaryTint)
                        Capsule()
                            .fill(store.theme.primary600)
                            .frame(width: proxy.size.width * CGFloat(count) / 20)
                    }
                }
                .frame(height: 9)
                .accessibilityLabel("乳牙进度")
                .accessibilityValue("已记录 \(count) 颗，共 20 颗")
            }
        }
    }

    // MARK: — 牙位图卡片

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                Text("乳牙牙位图")
                    .appFont(size: 15, weight: .heavy)
                    .tracking(-0.15)
                    .foregroundStyle(Palette.ink)
                Text("按照真实牙列排列，点击任意一颗牙记录")
                    .appFont(size: 12, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
            }

            Card(padding: 12) {
                VStack(spacing: 12) {
                    ToothChart(
                        store: store,
                        onTap: { pos in editing = pos }
                    )
                    .frame(height: 286)

                    HStack(spacing: 16) {
                        legendItem("已萌出", color: store.theme.primary600)
                        legendItem("该出了", color: Palette.yellowInk)
                        legendItem("未萌出", color: Palette.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .appFont(size: 11, weight: .bold)
                .foregroundStyle(Palette.ink2)
        }
    }

    // MARK: — 出牙时间线

    private var timelineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("出牙时间线")
                    .appFont(size: 15, weight: .heavy)
                    .tracking(-0.15)
                Spacer()
                Text("共 \(erupted.count) 颗")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(Palette.ink3)
            }

            Card(padding: 0) {
                if erupted.isEmpty {
                    VStack(spacing: 6) {
                        Text("还没有记录的牙")
                            .appFont(size: 14, weight: .heavy)
                            .foregroundStyle(Palette.ink2)
                        Text("点击上方牙位图记录第一颗")
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(erupted.enumerated()), id: \.element.id) { i, t in
                            Button { editing = t.position } label: {
                                timelineRow(t, index: i + 1, last: i == erupted.count - 1)
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
        }
    }

    private func timelineRow(_ t: ToothRecord, index: Int, last: Bool) -> some View {
        let months = monthsSinceBirth(t.eruptedAt)
        let df = DateFormatter(); df.dateFormat = "yyyy年M月d日"
        let dateStr = t.eruptedAt.map { df.string(from: $0) } ?? "—"
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.position.label)
                        .appFont(size: 15, weight: .heavy)
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    if let note = t.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                        Text(note)
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("第 \(index) 颗")
                        .appFont(size: 11, weight: .heavy)
                        .foregroundStyle(store.theme.primary600)
                    Text(months.map { "\(dateStr) · \($0) 月龄" } ?? dateStr)
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 68)
            if !last { Rectangle().fill(Palette.line).frame(height: 1) }
        }
    }

    private func monthsSinceBirth(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let comps = Calendar.current.dateComponents([.month, .day],
                                                    from: store.baby.birthDate, to: date)
        let m = (comps.month ?? 0) + ((comps.day ?? 0) >= 15 ? 1 : 0)
        return max(0, m)
    }
}

// MARK: — 牙位图 (Canvas + 可点击叠加层)

private enum ToothVisualState {
    case erupted, due, upcoming
}

private func toothVisualState(
    position: ToothPosition,
    record: ToothRecord,
    babyAgeMonths: Int
) -> ToothVisualState {
    if record.eruptedAt != nil { return .erupted }
    if babyAgeMonths >= position.kind.typicalMonths.lowerBound,
       babyAgeMonths <= position.kind.typicalMonths.upperBound + 3 {
        return .due
    }
    return .upcoming
}

private struct ToothChart: View {
    let store: AppStore
    let onTap: (ToothPosition) -> Void

    private var babyAgeMonths: Int {
        max(0, Calendar.current.dateComponents(
            [.month],
            from: store.baby.birthDate,
            to: Date()
        ).month ?? 0)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                MouthCavityShape()
                    .fill(Palette.pink.opacity(0.16))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 22)

                GumArch(jaw: .upper)
                    .fill(Palette.pink.opacity(0.72))
                    .overlay {
                        GumArch(jaw: .upper)
                            .stroke(Palette.pinkInk.opacity(0.16), lineWidth: 1)
                    }

                GumArch(jaw: .lower)
                    .fill(Palette.pink.opacity(0.72))
                    .overlay {
                        GumArch(jaw: .lower)
                            .stroke(Palette.pinkInk.opacity(0.16), lineWidth: 1)
                    }

                Text("上颌")
                    .appFont(size: 10, weight: .heavy)
                    .foregroundStyle(Palette.pinkInk)
                    .position(x: 25, y: 13)

                Text("下颌")
                    .appFont(size: 10, weight: .heavy)
                    .foregroundStyle(Palette.pinkInk)
                    .position(x: 25, y: size.height - 13)

                ForEach(ToothPosition.all) { position in
                    toothButton(position, in: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func toothButton(_ position: ToothPosition, in size: CGSize) -> some View {
        let record = store.tooth(at: position)
        let state = toothVisualState(
            position: position,
            record: record,
            babyAgeMonths: babyAgeMonths
        )
        let layout = toothLayout(for: position, in: size)

        return Button { onTap(position) } label: {
            ToothGlyph(
                position: position,
                record: record,
                babyAgeMonths: babyAgeMonths,
                theme: store.theme
            )
            .frame(width: layout.toothSize.width, height: layout.toothSize.height)
            .rotationEffect(.degrees(layout.rotation))
            .padding(6)
            .frame(width: layout.hitSize.width, height: layout.hitSize.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .position(layout.center)
        .zIndex(layout.zIndex)
        .accessibilityLabel(position.label)
        .accessibilityValue(statusLabel(state, record: record))
        .accessibilityHint("轻触编辑萌出记录")
    }

    private struct ToothLayout {
        let center: CGPoint
        let toothSize: CGSize
        let hitSize: CGSize
        let rotation: Double
        let zIndex: Double
    }

    private func toothLayout(for position: ToothPosition, in size: CGSize) -> ToothLayout {
        let jawPositions = ToothPosition.all.filter { $0.jaw == position.jaw }
        let index = jawPositions.firstIndex(of: position) ?? 0
        let normalized = (Double(index) - 4.5) / 4.5
        let distanceFromCenter = abs(normalized)
        let x = size.width * (0.5 + CGFloat(normalized) * 0.425)

        let y: CGFloat
        if position.jaw == .upper {
            y = size.height * (0.31 - CGFloat(distanceFromCenter) * 0.12)
        } else {
            y = size.height * (0.69 + CGFloat(distanceFromCenter) * 0.12)
        }

        let baseSize: CGSize
        switch position.kind {
        case .centralIncisor: baseSize = CGSize(width: 28, height: 42)
        case .lateralIncisor: baseSize = CGSize(width: 25, height: 38)
        case .canine: baseSize = CGSize(width: 27, height: 42)
        case .firstMolar: baseSize = CGSize(width: 32, height: 38)
        case .secondMolar: baseSize = CGSize(width: 35, height: 40)
        }

        let direction = position.jaw == .upper ? 1.0 : -1.0
        let rotation = normalized * 16 * direction
        return ToothLayout(
            center: CGPoint(x: x, y: y),
            toothSize: baseSize,
            hitSize: CGSize(width: 40, height: 54),
            rotation: rotation,
            zIndex: 10 - distanceFromCenter
        )
    }

    private func statusLabel(_ state: ToothVisualState, record: ToothRecord) -> String {
        switch state {
        case .erupted:
            guard let date = record.eruptedAt else { return "已记录" }
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        case .due:
            return "进入典型月龄"
        case .upcoming:
            return "尚未萌出"
        }
    }
}

private struct MouthCavityShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.height * 0.44)
    }
}

private struct GumArch: Shape {
    let jaw: ToothJaw

    func path(in rect: CGRect) -> Path {
        jaw == .upper ? upperPath(in: rect) : lowerPath(in: rect)
    }

    private func upperPath(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.045, y: h * 0.12))
        path.addCurve(
            to: CGPoint(x: w * 0.955, y: h * 0.12),
            control1: CGPoint(x: w * 0.24, y: h * 0.04),
            control2: CGPoint(x: w * 0.76, y: h * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.045, y: h * 0.12),
            control1: CGPoint(x: w * 0.76, y: h * 0.35),
            control2: CGPoint(x: w * 0.24, y: h * 0.35)
        )
        path.closeSubpath()
        return path
    }

    private func lowerPath(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.045, y: h * 0.88))
        path.addCurve(
            to: CGPoint(x: w * 0.955, y: h * 0.88),
            control1: CGPoint(x: w * 0.24, y: h * 0.96),
            control2: CGPoint(x: w * 0.76, y: h * 0.96)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.045, y: h * 0.88),
            control1: CGPoint(x: w * 0.76, y: h * 0.65),
            control2: CGPoint(x: w * 0.24, y: h * 0.65)
        )
        path.closeSubpath()
        return path
    }
}

private struct ToothGlyph: View {
    let position: ToothPosition
    let record: ToothRecord
    let babyAgeMonths: Int
    let theme: AppTheme

    private var state: ToothVisualState {
        toothVisualState(
            position: position,
            record: record,
            babyAgeMonths: babyAgeMonths
        )
    }

    var body: some View {
        let (fill, stroke, lineW) = styling()
        let shape = ToothShape(kind: position.kind)
        ZStack {
            shape.fill(fill)
            shape.stroke(stroke, style: StrokeStyle(
                lineWidth: lineW,
                lineCap: .round,
                lineJoin: .round,
                dash: state == .due ? [3, 2.5] : []
            ))
        }
        .shadow(color: Palette.ink.opacity(0.08), radius: 1.5, x: 0, y: 1)
        .scaleEffect(x: 1, y: position.jaw == .lower ? -1 : 1)
    }

    private func styling() -> (Color, Color, CGFloat) {
        switch state {
        case .erupted:
            return (.white, theme.primary600, 2.2)
        case .due:
            return (.white, Palette.yellowInk, 1.8)
        case .upcoming:
            return (.white, Palette.ink3.opacity(0.42), 1.2)
        }
    }
}

// MARK: — 有机牙齿路径(冠面在下方,下颌由外部翻转)

private struct ToothShape: Shape {
    let kind: ToothKind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .centralIncisor, .lateralIncisor: return incisor(in: rect)
        case .canine:                           return canine(in: rect)
        case .firstMolar, .secondMolar:         return molar(in: rect)
        }
    }

    /// 门牙:顶部圆角,冠部略外扩,底缘微微外凸
    private func incisor(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let r = min(w, h) * 0.30
        var p = Path()
        p.move(to: .init(x: r, y: 0))
        p.addLine(to: .init(x: w - r, y: 0))
        p.addQuadCurve(to: .init(x: w, y: r), control: .init(x: w, y: 0))
        p.addCurve(to: .init(x: w * 0.94, y: h * 0.82),
                   control1: .init(x: w, y: h * 0.35),
                   control2: .init(x: w * 0.98, y: h * 0.70))
        p.addQuadCurve(to: .init(x: w * 0.06, y: h * 0.82),
                       control: .init(x: w / 2, y: h * 1.05))
        p.addCurve(to: .init(x: 0, y: r),
                   control1: .init(x: w * 0.02, y: h * 0.70),
                   control2: .init(x: 0, y: h * 0.35))
        p.addQuadCurve(to: .init(x: r, y: 0), control: .init(x: 0, y: 0))
        p.closeSubpath()
        return p
    }

    /// 尖牙:圆角顶,底部收成小尖
    private func canine(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let r = min(w, h) * 0.30
        var p = Path()
        p.move(to: .init(x: r, y: 0))
        p.addLine(to: .init(x: w - r, y: 0))
        p.addQuadCurve(to: .init(x: w, y: r), control: .init(x: w, y: 0))
        p.addLine(to: .init(x: w * 0.90, y: h * 0.55))
        p.addQuadCurve(to: .init(x: w / 2, y: h),
                       control: .init(x: w * 0.78, y: h * 0.88))
        p.addQuadCurve(to: .init(x: w * 0.10, y: h * 0.55),
                       control: .init(x: w * 0.22, y: h * 0.88))
        p.addLine(to: .init(x: 0, y: r))
        p.addQuadCurve(to: .init(x: r, y: 0), control: .init(x: 0, y: 0))
        p.closeSubpath()
        return p
    }

    /// 磨牙:方胖圆角,底部两个小突起(咬合面)
    private func molar(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let r = min(w, h) * 0.28
        var p = Path()
        p.move(to: .init(x: r, y: 0))
        p.addLine(to: .init(x: w - r, y: 0))
        p.addQuadCurve(to: .init(x: w, y: r), control: .init(x: w, y: 0))
        p.addLine(to: .init(x: w, y: h * 0.60))
        // 右突
        p.addQuadCurve(to: .init(x: w * 0.50, y: h * 0.78),
                       control: .init(x: w * 0.78, y: h * 1.02))
        // 左突
        p.addQuadCurve(to: .init(x: 0, y: h * 0.60),
                       control: .init(x: w * 0.22, y: h * 1.02))
        p.addLine(to: .init(x: 0, y: r))
        p.addQuadCurve(to: .init(x: r, y: 0), control: .init(x: 0, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: — 编辑 Sheet

private struct ToothEditSheet: View {
    let position: ToothPosition
    let initial: ToothRecord
    let theme: AppTheme
    let onCancel: () -> Void
    let onSave: (Date, String?) -> Void
    let onClear: () -> Void

    @State private var erupted: Bool
    @State private var date: Date
    @State private var note: String
    @State private var showClearConfirm = false

    init(position: ToothPosition,
         initial: ToothRecord,
         theme: AppTheme,
         onCancel: @escaping () -> Void,
         onSave: @escaping (Date, String?) -> Void,
         onClear: @escaping () -> Void) {
        self.position = position
        self.initial = initial
        self.theme = theme
        self.onCancel = onCancel
        self.onSave = onSave
        self.onClear = onClear
        _erupted = .init(initialValue: initial.eruptedAt != nil)
        _date    = .init(initialValue: initial.eruptedAt ?? Date())
        _note    = .init(initialValue: initial.note ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: position.label, onBack: onCancel)

            ScreenBody {
                Card {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(position.kind.zh)
                            .appFont(size: 17, weight: .black)
                            .tracking(-0.18)
                            .foregroundStyle(Palette.ink)
                        Text("典型萌出时间为 \(position.kind.typicalMonths.lowerBound)–\(position.kind.typicalMonths.upperBound) 月龄，每个宝宝会有个体差异。")
                            .appFont(size: 13, weight: .semibold)
                            .foregroundStyle(Palette.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 9) {
                    FieldLabel(text: "当前状态")
                    SegPill(selection: $erupted, options: [(false, "尚未萌出"), (true, "已经萌出")])
                }
                .padding(.top, 18)

                if erupted {
                    Card {
                        VStack(spacing: 18) {
                        FormField(label: "萌出日期") {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                                .tint(theme.primary600)
                        }
                        FormField(label: "备注（可选）") {
                            TextField("例如：洗澡时发现", text: $note, axis: .vertical)
                                .lineLimit(1...3)
                        }
                    }
                    }
                    .padding(.top, 14)
                }

                CTAButton(title: "保存记录", theme: theme) {
                    if erupted {
                        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(date, trimmedNote.isEmpty ? nil : trimmedNote)
                    } else {
                        onClear()
                    }
                }
                .padding(.top, 18)

                if initial.eruptedAt != nil {
                    Button { showClearConfirm = true } label: {
                        Text("清除这颗牙的记录")
                            .appFont(size: 14, weight: .heavy)
                            .foregroundStyle(Palette.pinkInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                Palette.pink,
                                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                            )
                        }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 10)
                }
            }
        }
        .background(Palette.bg.ignoresSafeArea())
        .confirmationDialog(
            "确定清除这颗牙的萌出记录？",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清除记录", role: .destructive, action: onClear)
            Button("取消", role: .cancel) {}
        } message: {
            Text("萌出日期和备注将被删除。")
        }
    }
}

#Preview("出牙") {
    TeethScreen(onBack: {})
        .environment(AppStore.preview)
}
