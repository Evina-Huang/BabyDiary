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
                statCard
                chartCard.padding(.top, 14)
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

        return Card(padding: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已出")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.66).textCase(.uppercase)
                        .foregroundStyle(Palette.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(count)").font(.system(size: 30, weight: .black))
                            .monospacedDigit().foregroundStyle(store.theme.primary600)
                        Text("/ 20").font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Palette.ink3)
                    }
                    Text(latestText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
                ProgressRing(progress: Double(count) / 20.0,
                             tint: store.theme.primary,
                             ink: store.theme.primary600)
                    .frame(width: 56, height: 56)
            }
        }
    }

    // MARK: — 牙位图卡片

    private var chartCard: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("牙位图")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                Text("点击任意一颗牙记录萌出日期")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink3)

                ToothChart(
                    store: store,
                    onTap: { pos in editing = pos }
                )
                .frame(height: 180)
                .padding(.top, 6)

                legend.padding(.top, 4)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendDot(stroke: store.theme.primary600, lineW: 2.2, dashed: false, label: "已出")
            legendDot(stroke: Palette.yellowInk,      lineW: 1.8, dashed: true,  label: "该出了")
            legendDot(stroke: Color(hex: 0xB88A8E).opacity(0.45), lineW: 1.2, dashed: false, label: "未出")
            Spacer()
        }
    }

    private func legendDot(stroke: Color, lineW: CGFloat, dashed: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(stroke,
                                      style: StrokeStyle(lineWidth: lineW,
                                                         dash: dashed ? [2.5, 2] : []))
                )
                .frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.ink2)
        }
    }

    // MARK: — 出牙时间线

    private var timelineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("出牙时间线")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                Spacer()
                Text("共 \(erupted.count) 颗")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink3)
            }

            Card(padding: 0) {
                if erupted.isEmpty {
                    VStack(spacing: 6) {
                        Text("还没有记录的牙")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Palette.ink2)
                        Text("点击上方牙位图记录第一颗")
                            .font(.system(size: 12, weight: .semibold))
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
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let dateStr = t.eruptedAt.map { df.string(from: $0) } ?? "—"
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(store.theme.primaryTint)
                    Text("#\(index)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(store.theme.primary600)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.position.label)
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    Text(months.map { "\(dateStr) · \($0) 月龄" } ?? dateStr)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
                AppIcon.Chevron(size: 14, color: Palette.ink3)
            }
            .padding(.vertical, 12)
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

private struct ToothChart: View {
    let store: AppStore
    let onTap: (ToothPosition) -> Void

    private var babyAgeMonths: Int {
        max(0, Calendar.current.dateComponents([.month], from: store.baby.birthDate, to: Date()).month ?? 0)
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            ZStack {
                // 上下颌分隔线
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: W * 0.7, height: 1)
                    .position(x: W/2, y: H/2)

                ForEach(Array(ToothPosition.all.enumerated()), id: \.element.id) { _, pos in
                    let layout = toothFrame(for: pos, in: CGSize(width: W, height: H))
                    Button { onTap(pos) } label: {
                        ToothGlyph(
                            position: pos,
                            record: store.tooth(at: pos),
                            babyAgeMonths: babyAgeMonths,
                            theme: store.theme
                        )
                        .frame(width: layout.size.width, height: layout.size.height)
                    }
                    .buttonStyle(PressableStyle())
                    .position(layout.center)
                }
            }
            .frame(width: W, height: H)
        }
    }

    /// 两排水平布局:上排居上,下排居下,每排 10 颗均匀分布
    private func toothFrame(for pos: ToothPosition, in size: CGSize) -> (center: CGPoint, size: CGSize) {
        let jawTeeth = ToothPosition.all.filter { $0.jaw == pos.jaw }
        let idx = CGFloat(jawTeeth.firstIndex(of: pos) ?? 0)

        let pad: CGFloat = 8
        let innerW = size.width - pad * 2
        let slot = innerW / 10.0                // 每颗牙的槽位宽
        let x = pad + slot * (idx + 0.5)

        // 上下行中心 y:尽量撑开,让牙齿显得大
        let rowH = size.height * 0.48
        let y = pos.jaw == .upper ? rowH * 0.5 : size.height - rowH * 0.5

        // 牙齿尺寸:在槽位内放大,高度吃满 rowH 的 80%
        let w = min(slot * pos.kind.widthFactor, slot * 0.96)
        let h = min(rowH * 0.86, w * 1.25)
        return (CGPoint(x: x, y: y), CGSize(width: w, height: h))
    }
}

private struct ToothGlyph: View {
    let position: ToothPosition
    let record: ToothRecord
    let babyAgeMonths: Int
    let theme: AppTheme

    enum State { case erupted, due, upcoming }

    private var state: State {
        if record.eruptedAt != nil { return .erupted }
        if babyAgeMonths >= position.kind.typicalMonths.lowerBound &&
           babyAgeMonths <= position.kind.typicalMonths.upperBound + 3 {
            return .due
        }
        return .upcoming
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
        // 下颌翻转:咬合面朝向舌头
        .scaleEffect(x: 1, y: position.jaw == .lower ? -1 : 1)
        .overlay {
            if state == .erupted, let m = monthLabel() {
                Text(m)
                    .font(.system(size: 8, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary600)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private func styling() -> (Color, Color, CGFloat) {
        switch state {
        case .erupted:
            return (.white, theme.primary600, 2.2)
        case .due:
            return (.white, Palette.yellowInk, 1.8)
        case .upcoming:
            return (.white, Color(hex: 0xB88A8E).opacity(0.45), 1.2)
        }
    }

    private func monthLabel() -> String? {
        guard let d = record.eruptedAt else { return nil }
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: d)
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

// MARK: — 进度圆环

private struct ProgressRing: View {
    let progress: Double
    let tint: Color
    let ink: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.35), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 12, weight: .black))
                .monospacedDigit()
                .foregroundStyle(ink)
        }
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
            HStack {
                Text(position.label)
                    .font(.system(size: 20, weight: .heavy)).tracking(-0.4)
                Spacer()
                Button(action: onCancel) {
                    AppIcon.Close(size: 18, color: Palette.ink2)
                        .frame(width: 36, height: 36)
                        .background(Palette.bg2, in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 10)

            Text("典型月龄 \(position.kind.typicalMonths.lowerBound)-\(position.kind.typicalMonths.upperBound) 月")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.6).textCase(.uppercase)
                .foregroundStyle(Palette.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SegPill(selection: $erupted, options: [(false, "未出"), (true, "已出")])
                        .padding(.top, 12)

                    if erupted {
                        FormField(label: "萌出日期") {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                                .tint(theme.primary600)
                        }
                        FormField(label: "备注(可选)") {
                            TextField("例如:下午洗澡时发现", text: $note, axis: .vertical)
                                .lineLimit(1...3)
                        }
                    }

                    HStack(spacing: 8) {
                        if initial.eruptedAt != nil {
                            Button(action: onClear) {
                                Text("清除记录")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(Palette.ink)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                        }
                        Button {
                            if erupted {
                                onSave(date, note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note)
                            } else {
                                onClear()
                            }
                        } label: {
                            Text("保存")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(theme.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadowPill(tint: theme.primary600)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
        .background(Palette.bg.ignoresSafeArea())
    }
}

#Preview("出牙") {
    TeethScreen(onBack: {})
        .environment(AppStore.preview)
}
