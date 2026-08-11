import SwiftUI

// MARK: — Screen chrome

struct ScreenHeader<Right: View>: View {
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var right: () -> Right

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    AppIcon.Back(size: 22, color: Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(Palette.bg2, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("返回")
            }
            Text(title)
                .appText(.screenTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            right()
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

extension ScreenHeader where Right == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, right: { EmptyView() })
    }
}

struct ScreenBody<Content: View>: View {
    var padded: Bool = true
    @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = padded ? 20 : 0
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) { content }
                    .padding(.top, padded ? 8 : 0)
                    .padding(.bottom, padded ? 120 : 0)
                    .frame(
                        width: max(0, proxy.size.width - horizontalPadding * 2),
                        alignment: .top
                    )
                    .padding(.horizontal, horizontalPadding)
            }
        }
    }
}

// MARK: — Card surface

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = AppRadius.surface
    var elevation: SurfaceElevation = .flat
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let surface = content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            }
            .surfaceElevation(elevation)
        if let onTap {
            Button(action: onTap) { surface }
                .buttonStyle(PressableStyle())
        } else {
            surface
        }
    }
}

// MARK: — Press-to-shrink style for tap affordance (matches `.press:active`)

struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1.0))
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: — Category tile (44×44 rounded-corner tinted icon)

struct CategoryIcon: View {
    let kind: EventKind
    var size: CGFloat = 44

    var body: some View {
        let style = CategoryStyle.forKind(kind, iconSize: size * 0.58)
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(style.tint)
            .frame(width: size, height: size)
            .overlay(style.icon)
    }
}

// MARK: — Event row (timeline entry)

struct EventRow: View {
    let event: Event
    var last: Bool = false
    var onDelete: ((Event) -> Void)? = nil
    var onEdit: ((Event) -> Void)? = nil

    var body: some View {
        let display = recordDisplayText(for: event)
        let row = HStack(spacing: 14) {
            CategoryIcon(kind: event.kind, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(display.title)
                    .appText(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                if let s = display.subtitle, !s.isEmpty {
                    Text(s)
                        .appText(.caption)
                        .foregroundStyle(Palette.ink3)
                        .lineLimit(2)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Text(formatTime(event.at))
                .appFont(size: 13, weight: .bold)
                .monospacedDigit()
                .foregroundStyle(Palette.ink2)
            if onEdit != nil {
                AppIcon.Chevron(size: 14, color: Palette.ink3)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())

        let tappable = Group {
            if let onEdit {
                Button { onEdit(event) } label: { row }
                    .buttonStyle(PressableStyle())
            } else {
                row
            }
        }

        VStack(spacing: 0) {
            tappable
            if !last {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
        .background(Palette.card)
        .contextMenu {
            if let onEdit {
                Button { onEdit(event) } label: { Label("编辑", systemImage: "pencil") }
            }
            if let onDelete {
                Button(role: .destructive) {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    onDelete(event)
                } label: { Label("删除", systemImage: "trash") }
            }
        }
    }
}

struct RecordEventDisplayText: Equatable {
    let title: String
    let subtitle: String?
}

func recordDisplayText(for event: Event) -> RecordEventDisplayText {
    guard event.isBreastFeed else {
        return RecordEventDisplayText(title: event.title, subtitle: event.sub)
    }

    return RecordEventDisplayText(
        title: breastFeedRecordTitle(for: event),
        subtitle: event.endAt.map { _ in "\(formatTime(event.at))-\(formatTime(event.occurredAt))" }
    )
}

private func breastFeedRecordTitle(for event: Event) -> String {
    let parts = breastSideMinuteParts(in: event.sub)
    if !parts.isEmpty {
        return "母乳 · " + parts
            .map { "\($0.side.recordLabel)\($0.minutes)分" }
            .joined(separator: " ")
    }

    if let side = breastSide(from: event.title),
       let minutes = firstMinute(in: event.sub) {
        return "母乳 · \(side.recordLabel)\(minutes)分"
    }

    return "母乳"
}

private func breastSideMinuteParts(in text: String?) -> [(side: BreastFeedSide, minutes: Int)] {
    guard let text else { return [] }

    return [
        sideMinutePart(marker: "左", side: .left, in: text),
        sideMinutePart(marker: "右", side: .right, in: text)
    ]
    .compactMap { $0 }
    .sorted { $0.index < $1.index }
    .map { (side: $0.side, minutes: $0.minutes) }
}

private func sideMinutePart(
    marker: Character,
    side: BreastFeedSide,
    in text: String
) -> (index: String.Index, side: BreastFeedSide, minutes: Int)? {
    guard let markerIndex = text.firstIndex(of: marker) else { return nil }

    var cursor = text.index(after: markerIndex)
    while cursor < text.endIndex, !text[cursor].isNumber {
        cursor = text.index(after: cursor)
    }

    let digitStart = cursor
    while cursor < text.endIndex, text[cursor].isNumber {
        cursor = text.index(after: cursor)
    }

    guard digitStart < cursor,
          let minutes = Int(text[digitStart..<cursor]) else {
        return nil
    }

    return (markerIndex, side, minutes)
}

private func breastSide(from title: String) -> BreastFeedSide? {
    if title.contains("左侧") { return .left }
    if title.contains("右侧") { return .right }
    return nil
}

private func firstMinute(in text: String?) -> Int? {
    guard let text else { return nil }
    var cursor = text.startIndex
    while cursor < text.endIndex, !text[cursor].isNumber {
        cursor = text.index(after: cursor)
    }

    let digitStart = cursor
    while cursor < text.endIndex, text[cursor].isNumber {
        cursor = text.index(after: cursor)
    }

    guard digitStart < cursor else { return nil }
    return Int(text[digitStart..<cursor])
}

private extension BreastFeedSide {
    var recordLabel: String {
        switch self {
        case .left: return "左"
        case .right: return "右"
        }
    }
}

// MARK: — "Since last X" colored banner

struct SinceLastBanner: View {
    let kind: EventKind         // feed / diaper / sleep
    let lastAt: Date?
    let label: String           // e.g. "喂奶"
    let iconSize: CGFloat = 18

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            content(now: ctx.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let lastAt {
            let style = CategoryStyle.forKind(kind, iconSize: iconSize)
            let delta = Int(now.timeIntervalSince(lastAt))
            let h = max(0, delta / 3600)
            let m = max(0, (delta % 3600) / 60)
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                        .fill(Palette.card.opacity(0.6))
                    style.icon
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("距上次\(label)")
                        .appText(.micro)
                        .foregroundStyle(style.ink.opacity(0.75))
                    Text(h > 0 ? "\(h)时\(m)分" : "\(m)分")
                        .appFont(size: 16, weight: .black)
                        .monospacedDigit()
                        .foregroundStyle(style.ink)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(style.tint, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        } else {
            EmptyView()
        }
    }
}

// MARK: — Empty state

struct EmptyStateView: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            FriendlyMoonBlob().frame(width: 96, height: 96)
            Text(title)
                .appText(.cardTitle)
                .foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle)
                    .appText(.label)
                    .foregroundStyle(Palette.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }
}

private struct FriendlyMoonBlob: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 120
            func pt(_ x: Double, _ y: Double) -> CGPoint { .init(x: x * s, y: y * s) }
            ctx.fill(Path(ellipseIn: CGRect(x: 8 * s, y: 8 * s, width: 104 * s, height: 104 * s)),
                     with: .color(AppTheme.coral.primaryTint))
            var moon = Path()
            moon.move(to: pt(82, 68))
            moon.addArc(center: pt(58, 68), radius: 24 * s, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(moon, with: .color(Palette.yellow))
            var eye1 = Path()
            eye1.move(to: pt(48, 58)); eye1.addQuadCurve(to: pt(56, 58), control: pt(52, 61))
            var eye2 = Path()
            eye2.move(to: pt(64, 58)); eye2.addQuadCurve(to: pt(72, 58), control: pt(68, 61))
            ctx.stroke(eye1, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            ctx.stroke(eye2, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: 45 * s, y: 65 * s, width: 6 * s, height: 6 * s)), with: .color(AppTheme.coral.primary.opacity(0.5)))
            ctx.fill(Path(ellipseIn: CGRect(x: 69 * s, y: 65 * s, width: 6 * s, height: 6 * s)), with: .color(AppTheme.coral.primary.opacity(0.5)))
            ctx.fill(Path(ellipseIn: CGRect(x: 24 * s, y: 28 * s, width: 4 * s, height: 4 * s)), with: .color(Palette.pink))
            ctx.fill(Path(ellipseIn: CGRect(x: 91.5 * s, y: 37.5 * s, width: 5 * s, height: 5 * s)), with: .color(Palette.blue))
            ctx.fill(Path(ellipseIn: CGRect(x: 98.2 * s, y: 78.2 * s, width: 3.6 * s, height: 3.6 * s)), with: .color(Palette.yellow))
        }
    }
}

// MARK: — CTA button (coral pill)

struct CTAButton: View {
    enum Variant { case primary, secondary, ghost }
    let title: String
    var variant: Variant = .primary
    var theme: AppTheme = .blossom
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appText(.button)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .shadowPill(tint: shadowTint)
        }
        .buttonStyle(PressableStyle())
    }

    private var background: Color {
        switch variant {
        case .primary:   return theme.primary
        case .secondary: return Palette.mint
        case .ghost:     return Palette.bg2
        }
    }
    private var foreground: Color {
        variant == .ghost ? Palette.ink : theme.onPrimary
    }
    private var shadowTint: Color {
        switch variant {
        case .primary:   return theme.primary600
        case .secondary: return Palette.mint600
        case .ghost:     return .clear
        }
    }
}

// MARK: — Segmented pill toggle

struct SegPill<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { (val, label) in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { selection = val }
                } label: {
                    Text(label)
                        .appText(.label)
                        .foregroundStyle(selection == val ? Palette.ink : Palette.ink2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background {
                            if selection == val {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(Palette.card)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                                            .stroke(Palette.line, lineWidth: 1)
                                    }
                            }
                        }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(4)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 999, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous).stroke(Palette.line, lineWidth: 1)
        )
    }
}

// MARK: — Labeled form input (matches .input + .label)

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .appText(.captionEmphasis)
            .foregroundStyle(Palette.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: label)
            content()
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .appText(.body)
                .foregroundStyle(Palette.ink)
        }
    }
}

// MARK: — Time / duration / date formatters (matching primitives.jsx)

func formatTime(_ d: Date) -> String {
    let cal = Calendar.current
    let h = cal.component(.hour, from: d)
    let m = cal.component(.minute, from: d)
    return String(format: "%02d:%02d", h, m)
}

func formatDur(_ seconds: TimeInterval) -> String {
    let sec = Int(seconds)
    let h = sec / 3600
    let m = (sec % 3600) / 60
    let s = sec % 60
    if h > 0 { return "\(h)时 \(m)分" }
    return String(format: "%d分 %02d秒", m, s)
}

func formatDurShort(_ seconds: TimeInterval) -> String {
    let sec = Int(seconds)
    let h = sec / 3600
    let m = (sec % 3600) / 60
    if h > 0 { return "\(h)时 \(m)分" }
    return "\(m)分"
}

struct InlineWheelTimePicker: View {
    @Binding var time: Date
    let theme: AppTheme
    var components: DatePickerComponents = [.date, .hourAndMinute]
    var label: String = "时间"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: label)
            HStack(spacing: 8) {
                DatePicker("", selection: $time, displayedComponents: components)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(theme.primary600)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        }
    }
}

func formatDateLabel(_ d: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(d)     { return "今天" }
    if cal.isDateInYesterday(d) { return "昨天" }
    let mm = cal.component(.month, from: d)
    let dd = cal.component(.day, from: d)
    return "\(mm)月\(dd)日"
}
