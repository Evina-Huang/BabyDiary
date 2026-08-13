import SwiftUI
import UIKit

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
    var surfaceStyle: SurfaceStyle = .plain
    var backgroundColor: Color = Palette.card
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let surface = content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            }
            .appSurface(surfaceStyle)
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
                .shadowPill(tint: shadowTint, isEnabled: variant == .primary)
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

// MARK: — Quick-record flow primitives

/// Shared progressive-disclosure panel used by the four high-frequency forms.
struct AdjustmentDetails<Content: View>: View {
    @Binding var isExpanded: Bool
    var summary: String = "时间、备注等可选设置"
    var tint: Color = Palette.ink3
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    AppIcon.Plus(size: 17, color: tint)
                        .rotationEffect(.degrees(isExpanded ? 45 : 0))
                        .frame(width: 32, height: 32)
                        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("调整详情")
                            .appText(.cardTitle)
                            .foregroundStyle(Palette.ink)
                        Text(summary)
                            .appText(.caption)
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    AppIcon.Chevron(size: 15, color: Palette.ink3)
                        .rotationEffect(.degrees(isExpanded ? 270 : 90))
                        .frame(width: 44, height: 44)
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .frame(maxWidth: .infinity, minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityValue(isExpanded ? "已展开" : "已收起")

            if isExpanded {
                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                content()
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
        .clipped()
    }
}

enum RecordSaveStatus: Equatable {
    case ready(String)
    case disabled(message: String)
    case disabledQuietly
    case error(message: String)
    case saving
    case success

    var isEnabled: Bool {
        if case .ready = self { return true }
        return false
    }
}

/// A consistent action bar anchored immediately above the bottom safe area.
struct RecordSaveBar: View {
    let status: RecordSaveStatus
    let theme: AppTheme
    var disabledButtonTitle: String = "暂时无法保存"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let message = statusMessage {
                Text(message)
                    .appText(.captionEmphasis)
                    .foregroundStyle(statusMessageColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(statusAccessibilityLabel(message))
            }

            Button(action: action) {
                HStack(spacing: 8) {
                    buttonIcon
                    Text(buttonTitle)
                        .appText(.button)
                }
                .foregroundStyle(buttonForeground)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(buttonBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .shadowPill(tint: theme.primary600, isEnabled: status.isEnabled)
            }
            .buttonStyle(PressableStyle())
            .disabled(!status.isEnabled)
            .accessibilityHint(status.isEnabled ? "保存当前记录" : "")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }

    @ViewBuilder
    private var buttonIcon: some View {
        switch status {
        case .saving:
            ProgressView().tint(buttonForeground)
        case .success:
            AppIcon.Check(size: 18, color: buttonForeground)
        case .ready, .disabled, .disabledQuietly, .error:
            EmptyView()
        }
    }

    private var buttonTitle: String {
        switch status {
        case .ready(let title): return title
        case .disabled: return disabledButtonTitle
        case .disabledQuietly: return "保存"
        case .error: return "请检查填写内容"
        case .saving: return "正在保存"
        case .success: return "已保存"
        }
    }

    private var buttonBackground: Color {
        switch status {
        case .ready: return theme.primary
        case .success: return Palette.mint
        case .error: return Palette.dangerTint
        case .disabled, .disabledQuietly, .saving: return Palette.bg2
        }
    }

    private var buttonForeground: Color {
        switch status {
        case .ready: return theme.onPrimary
        case .success: return Palette.mint600
        case .error: return Palette.dangerInk
        case .disabled, .disabledQuietly, .saving: return Palette.ink3
        }
    }

    private var statusMessage: String? {
        switch status {
        case .disabled(let message), .error(let message): return message
        case .ready, .disabledQuietly, .saving, .success: return nil
        }
    }

    private var statusMessageColor: Color {
        if case .error = status { return Palette.dangerInk }
        return Palette.ink3
    }

    private func statusAccessibilityLabel(_ message: String) -> String {
        if case .error = status { return "保存错误，\(message)" }
        return "无法保存，\(message)"
    }
}

struct RecordSuccessToast: View {
    let isPresented: Bool
    var title: String = "记录已保存"

    var body: some View {
        if isPresented {
            HStack(spacing: 9) {
                AppIcon.Check(size: 16, color: Palette.mint600)
                Text(title)
                    .appText(.bodyEmphasis)
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(Palette.card, in: Capsule())
            .overlay { Capsule().stroke(Palette.line, lineWidth: 1) }
            .appSurface(.elevated)
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                AppAccessibility.announce(title)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct UndoToast: View {
    let message: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .appText(.bodyEmphasis)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("撤销", action: action)
                .appText(.button)
                .foregroundStyle(Palette.blueInk)
                .frame(minWidth: 56, minHeight: 44)
                .buttonStyle(PressableStyle())
                .accessibilityHint("恢复刚刚删除的记录")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
        .appSurface(.elevated)
        .accessibilityElement(children: .contain)
        .onAppear {
            AppAccessibility.announce("\(message)，可以撤销")
        }
    }
}

enum AppAccessibility {
    static func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

enum RecordSaveFeedback {
    @MainActor
    static func complete(
        isPresented: Binding<Bool>,
        delay: TimeInterval = 0.65,
        then completion: @escaping () -> Void
    ) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented.wrappedValue = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion()
        }
    }
}

enum RecordExitProtection: Equatable {
    case none
    case unsaved
    case timerDraft(isRunning: Bool)

    var requiresConfirmation: Bool { self != .none }
}

extension View {
    func recordExitProtection(
        _ protection: RecordExitProtection,
        isPresented: Binding<Bool>,
        onPreserve: @escaping () -> Void = {},
        onDiscard: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(RecordExitProtectionModifier(
            protection: protection,
            isPresented: isPresented,
            onPreserve: onPreserve,
            onDiscard: onDiscard,
            onDismiss: onDismiss
        ))
    }
}

private struct RecordExitProtectionModifier: ViewModifier {
    let protection: RecordExitProtection
    @Binding var isPresented: Bool
    let onPreserve: () -> Void
    let onDiscard: () -> Void
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .background {
                SheetDismissAttemptMonitor(
                    isDisabled: protection.requiresConfirmation,
                    onAttempt: { isPresented = true }
                )
                .frame(width: 0, height: 0)
            }
            .confirmationDialog(
                dialogTitle,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                dialogActions
            } message: {
                Text(dialogMessage)
            }
    }

    @ViewBuilder
    private var dialogActions: some View {
        switch protection {
        case .none:
            EmptyView()
        case .unsaved:
            Button("放弃更改", role: .destructive) {
                onDiscard()
                onDismiss()
            }
            Button("继续编辑", role: .cancel) {}
        case .timerDraft:
            Button("保留计时并退出") {
                onPreserve()
                onDismiss()
            }
            Button("放弃本次计时", role: .destructive) {
                onDiscard()
                onDismiss()
            }
            Button("继续记录", role: .cancel) {}
        }
    }

    private var dialogTitle: String {
        switch protection {
        case .none: return ""
        case .unsaved: return "放弃未保存的记录？"
        case .timerDraft(let isRunning): return isRunning ? "计时仍在进行" : "计时记录尚未保存"
        }
    }

    private var dialogMessage: String {
        switch protection {
        case .none: return ""
        case .unsaved: return "退出后，本页填写的内容将不会保留。"
        case .timerDraft(let isRunning):
            return isRunning
                ? "保留后计时会继续，可从首页的进行中状态继续记录。"
                : "可以保留当前草稿，稍后从首页继续完成记录。"
        }
    }
}

private struct SheetDismissAttemptMonitor: UIViewControllerRepresentable {
    let isDisabled: Bool
    let onAttempt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isDisabled: isDisabled, onAttempt: onAttempt)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.isDisabled = isDisabled
        context.coordinator.onAttempt = onAttempt
        DispatchQueue.main.async {
            controller.parent?.presentationController?.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isDisabled: Bool
        var onAttempt: () -> Void

        init(isDisabled: Bool, onAttempt: @escaping () -> Void) {
            self.isDisabled = isDisabled
            self.onAttempt = onAttempt
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isDisabled
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            guard isDisabled else { return }
            onAttempt()
        }
    }
}

// MARK: — Segmented pill toggle

struct SegPill<Value: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 0))

        layout {
            ForEach(options, id: \.0) { (val, label) in
                let selected = selection == val
                Button {
                    if reduceMotion {
                        selection = val
                    } else {
                        withAnimation(.easeOut(duration: 0.16)) { selection = val }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if selected {
                            AppIcon.Check(size: 13, color: Palette.ink)
                                .accessibilityHidden(true)
                        }
                        Text(label)
                            .appText(.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(selected ? Palette.ink : Palette.ink2)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
                    .padding(.horizontal, 18)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .fill(Palette.card)
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                        .stroke(Palette.line, lineWidth: 1)
                                }
                        }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(label)
                .accessibilityValue(selected ? "已选中" : "未选中")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
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
