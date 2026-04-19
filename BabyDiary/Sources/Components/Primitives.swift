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
                        .frame(width: 40, height: 40)
                        .background(Palette.bg2, in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
            Text(title)
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.44)
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) { content }
                .padding(.top, padded ? 8 : 0)
                .padding(.horizontal, padded ? 20 : 0)
                .padding(.bottom, padded ? 120 : 0)
        }
    }
}

// MARK: — Card surface

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 22
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let surface = content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadowCard()
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

    var body: some View {
        let row = HStack(spacing: 14) {
            CategoryIcon(kind: event.kind, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(-0.15)
                    .foregroundStyle(Palette.ink)
                if let s = event.sub, !s.isEmpty {
                    Text(s)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ink3)
                }
            }
            Spacer(minLength: 0)
            Text(formatTime(event.at))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink2)
        }
        .padding(.vertical, 12)

        VStack(spacing: 0) {
            row
            if !last {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
        .background(Palette.card)
        .swipeActions(trailing: onDelete != nil, trash: { onDelete?(event) })
    }
}

// Lightweight swipe-to-delete bridge — on iOS lists we'd use .swipeActions,
// but inside our custom card stack we render it manually.
private struct SwipeToDeleteModifier: ViewModifier {
    let trailing: Bool
    let onTrash: () -> Void
    @State private var dx: CGFloat = 0
    private let MAX: CGFloat = -88

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            if trailing {
                Button(action: { withAnimation(.spring()) { onTrash(); dx = 0 } }) {
                    Text("删除")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 60)
                        .background(Palette.bg)
                }
                .background(Color(hex: 0xFF7F64))
            }
            content
                .offset(x: dx)
                .gesture(
                    DragGesture()
                        .onChanged { g in
                            guard trailing else { return }
                            let next = min(0, max(MAX * 1.2, g.translation.width))
                            dx = next
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                dx = dx < MAX / 2 ? MAX : 0
                            }
                        }
                )
        }
    }
}

extension View {
    func swipeActions(trailing: Bool, trash: @escaping () -> Void) -> some View {
        self.modifier(SwipeToDeleteModifier(trailing: trailing, onTrash: trash))
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.6))
                    style.icon
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("距上次\(label)")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(style.ink.opacity(0.75))
                    Text(h > 0 ? "\(h)小时\(m)分" : "\(m) 分钟")
                        .font(.system(size: 16, weight: .black))
                        .tracking(-0.32)
                        .monospacedDigit()
                        .foregroundStyle(style.ink)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(style.tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
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
                     with: .color(Color(hex: 0xFFE8E0)))
            var moon = Path()
            moon.move(to: pt(82, 68))
            moon.addArc(center: pt(58, 68), radius: 24 * s, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            ctx.fill(moon, with: .color(Color(hex: 0xFFC7B5)))
            var eye1 = Path()
            eye1.move(to: pt(48, 58)); eye1.addQuadCurve(to: pt(56, 58), control: pt(52, 61))
            var eye2 = Path()
            eye2.move(to: pt(64, 58)); eye2.addQuadCurve(to: pt(72, 58), control: pt(68, 61))
            ctx.stroke(eye1, with: .color(Color(hex: 0x2B2520)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            ctx.stroke(eye2, with: .color(Color(hex: 0x2B2520)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: 45 * s, y: 65 * s, width: 6 * s, height: 6 * s)), with: .color(Color(hex: 0xFF9B85).opacity(0.5)))
            ctx.fill(Path(ellipseIn: CGRect(x: 69 * s, y: 65 * s, width: 6 * s, height: 6 * s)), with: .color(Color(hex: 0xFF9B85).opacity(0.5)))
            ctx.fill(Path(ellipseIn: CGRect(x: 24 * s, y: 28 * s, width: 4 * s, height: 4 * s)), with: .color(Color(hex: 0xFFD0DC)))
            ctx.fill(Path(ellipseIn: CGRect(x: 91.5 * s, y: 37.5 * s, width: 5 * s, height: 5 * s)), with: .color(Color(hex: 0xCFE4F5)))
            ctx.fill(Path(ellipseIn: CGRect(x: 98.2 * s, y: 78.2 * s, width: 3.6 * s, height: 3.6 * s)), with: .color(Color(hex: 0xFFE8A8)))
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
                .font(.system(size: 17, weight: .heavy))
                .tracking(-0.17)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        variant == .ghost ? Palette.ink : .white
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
                        .font(.system(size: 14, weight: .bold))
                        .tracking(-0.14)
                        .foregroundStyle(selection == val ? Palette.ink : Palette.ink2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background {
                            if selection == val {
                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
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
            .font(.system(size: 12, weight: .bold))
            .tracking(0.72)
            .textCase(.uppercase)
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
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
    }
}

// MARK: — Time / duration / date formatters (matching primitives.jsx)

func formatTime(_ d: Date) -> String {
    let cal = Calendar.current
    let h = cal.component(.hour, from: d)
    let m = cal.component(.minute, from: d)
    let ap = h < 12 ? "上午" : "下午"
    let hh = h % 12 == 0 ? 12 : h % 12
    return String(format: "%@ %d:%02d", ap, hh, m)
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
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)分钟"
}

func formatDateLabel(_ d: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(d)     { return "今天" }
    if cal.isDateInYesterday(d) { return "昨天" }
    let mm = cal.component(.month, from: d)
    let dd = cal.component(.day, from: d)
    return "\(mm)月\(dd)日"
}
