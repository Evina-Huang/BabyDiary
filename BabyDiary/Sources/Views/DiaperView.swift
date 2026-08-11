import SwiftUI

struct DiaperScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    private struct Option: Identifiable {
        let type: DiaperEventType
        let label: String
        let sub: String
        let glyph: DiaperTypeGlyph.Kind
        let tint: Color
        let ink: Color
        var id: DiaperEventType { type }
    }

    private let options: [Option] = [
        .init(type: .wet, label: DiaperEventType.wet.label,
              sub: "只有尿湿", glyph: .wet,
              tint: Palette.blue, ink: Palette.blueInk),
        .init(type: .dirty, label: DiaperEventType.dirty.label,
              sub: "只有排便", glyph: .dirty,
              tint: Palette.yellow, ink: Palette.yellowInk),
        .init(type: .both, label: "两种都有",
              sub: "尿湿和排便", glyph: .both,
              tint: Palette.mintTint, ink: Palette.mint600),
    ]

    @State private var type: DiaperEventType? = nil
    @State private var diaperNote: String = ""
    @State private var time: Date = .now

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "换尿布记录", onBack: onBack)
            ScreenBody {
                SinceLastBanner(
                    kind: .diaper,
                    lastAt: store.mostRecentEvent(kind: .diaper)?.occurredAt,
                    label: "换尿布"
                )
                .padding(.top, 8)

                typePicker.padding(.top, 24)

                if selectedTypeAllowsNote {
                    notePicker
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                timePicker.padding(.top, 22)
                saveButton.padding(.top, 22)
            }
        }
        .background(Palette.bg)
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("这次是什么情况？")
                    .appFont(size: 17, weight: .bold)
                    .tracking(-0.2)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text("选择一项")
                    .appFont(size: 12, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
            }

            HStack(alignment: .top, spacing: 10) {
                ForEach(options) { option in
                    typeButton(option)
                }
            }
        }
    }

    private func typeButton(_ option: Option) -> some View {
        let isSelected = type == option.type
        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                type = option.type
                if !option.type.allowsNote {
                    diaperNote = ""
                }
            }
        } label: {
            VStack(spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isSelected ? Palette.card.opacity(0.68) : option.tint.opacity(0.72))
                        .frame(width: 50, height: 50)
                        .overlay {
                            DiaperTypeGlyph(kind: option.glyph, size: 30, color: option.ink)
                        }

                    if isSelected {
                        Circle()
                            .fill(option.ink)
                            .frame(width: 18, height: 18)
                            .overlay(AppIcon.Check(size: 11, color: .white))
                            .offset(x: 5, y: -5)
                    }
                }

                VStack(spacing: 3) {
                    Text(option.label)
                        .appFont(size: 14, weight: .heavy)
                        .tracking(-0.14)
                        .foregroundStyle(isSelected ? option.ink : Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(option.sub)
                        .appFont(size: 11, weight: .medium)
                        .foregroundStyle(isSelected ? option.ink.opacity(0.78) : Palette.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 126)
            .background(
                isSelected ? option.tint : Palette.card,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? option.ink.opacity(0.18) : Palette.line, lineWidth: 1)
            }
            .shadowCard()
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(option.label)，\(option.sub)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var notePicker: some View {
        let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]
        let noteOptions = DiaperNotePreset.options(including: diaperNote)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("便便情况")
                        .appFont(size: 16, weight: .bold)
                        .foregroundStyle(Palette.ink)
                    Text("可选，方便以后观察变化")
                        .appFont(size: 12, weight: .medium)
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 8)
                if !diaperNote.isEmpty {
                    Button("清空") {
                        withAnimation(.easeOut(duration: 0.16)) {
                            diaperNote = ""
                        }
                    }
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(Palette.ink2)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(PressableStyle())
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(noteOptions, id: \.self) { note in
                    let isSelected = diaperNote == note
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            diaperNote = isSelected ? "" : note
                        }
                    } label: {
                        Text(note)
                            .appFont(size: 13, weight: .bold)
                            .foregroundStyle(isSelected ? Palette.yellowInk : Palette.ink2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 10)
                            .background(
                                isSelected ? Palette.yellow : Palette.bg2,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? Palette.yellowInk.opacity(0.14) : .clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            TextField("补充其他情况", text: $diaperNote)
                .appFont(size: 16, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("便便情况补充说明")
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        }
        .shadowCard()
    }

    private var timePicker: some View {
        InlineWheelTimePicker(time: $time, theme: store.theme)
    }

    private var saveButton: some View {
        let enabled = type != nil
        let background: Color = enabled ? store.theme.primary : Palette.bg2
        let foreground: Color = enabled ? .white : Palette.ink3
        return Button(action: submit) {
            HStack(spacing: 8) {
                if enabled {
                    AppIcon.Check(size: 18, color: foreground)
                }
                Text(enabled ? "保存换尿布记录" : "请先选择一种情况")
                    .appFont(size: 17, weight: .heavy)
                    .tracking(-0.17)
                    .foregroundStyle(foreground)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadowPill(tint: enabled ? background.opacity(0.9) : .clear)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private var selectedTypeAllowsNote: Bool {
        type?.allowsNote == true
    }

    private func submit() {
        guard let selectedType = type else { return }

        let trimmedNote = diaperNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = selectedType.allowsNote && !trimmedNote.isEmpty ? trimmedNote : nil
        store.addEvent(.init(kind: .diaper, at: time, title: selectedType.label, sub: note))
        diaperNote = ""
        onBack()
    }
}

private struct DiaperTypeGlyph: View {
    enum Kind {
        case wet
        case dirty
        case both
    }

    let kind: Kind
    var size: CGFloat = 30
    let color: Color

    var body: some View {
        Canvas { context, _ in
            let canvasTransform = CGAffineTransform(scaleX: size / 32, y: size / 32)
            let drop = Self.dropPath()
            let dirty = Self.dirtyPath()
            let face = Self.dirtyFacePath()

            if kind == .wet {
                context.fill(drop.applying(canvasTransform), with: .color(color.opacity(0.16)))
                context.stroke(
                    drop.applying(canvasTransform),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }

            if kind == .dirty {
                context.fill(dirty.applying(canvasTransform), with: .color(color.opacity(0.16)))
                context.stroke(
                    dirty.applying(canvasTransform),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
                context.fill(face.applying(canvasTransform), with: .color(color))
            }

            if kind == .both {
                let dropPlacement = CGAffineTransform(scaleX: 0.66, y: 0.66)
                    .translatedBy(x: -3, y: 8)
                let dirtyPlacement = CGAffineTransform(scaleX: 0.62, y: 0.62)
                    .translatedBy(x: 21, y: 10)
                let smallDrop = drop.applying(dropPlacement).applying(canvasTransform)
                let smallDirty = dirty.applying(dirtyPlacement).applying(canvasTransform)
                let smallFace = face.applying(dirtyPlacement).applying(canvasTransform)

                context.fill(smallDrop, with: .color(color.opacity(0.16)))
                context.stroke(
                    smallDrop,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round)
                )
                context.fill(smallDirty, with: .color(color.opacity(0.16)))
                context.stroke(
                    smallDirty,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round)
                )
                context.fill(smallFace, with: .color(color))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static func dropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4))
        path.addCurve(
            to: CGPoint(x: 16, y: 27),
            control1: CGPoint(x: 8, y: 14),
            control2: CGPoint(x: 8, y: 20)
        )
        path.addCurve(
            to: CGPoint(x: 16, y: 4),
            control1: CGPoint(x: 24, y: 20),
            control2: CGPoint(x: 24, y: 14)
        )
        path.closeSubpath()
        return path
    }

    private static func dirtyPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 7, y: 27))
        path.addCurve(
            to: CGPoint(x: 25, y: 27),
            control1: CGPoint(x: 2, y: 27),
            control2: CGPoint(x: 2, y: 20)
        )
        path.addCurve(
            to: CGPoint(x: 22, y: 16),
            control1: CGPoint(x: 30, y: 24),
            control2: CGPoint(x: 28, y: 17)
        )
        path.addCurve(
            to: CGPoint(x: 19, y: 10),
            control1: CGPoint(x: 24, y: 13),
            control2: CGPoint(x: 22, y: 10)
        )
        path.addCurve(
            to: CGPoint(x: 14, y: 6),
            control1: CGPoint(x: 21, y: 6),
            control2: CGPoint(x: 17, y: 4)
        )
        path.addCurve(
            to: CGPoint(x: 11, y: 16),
            control1: CGPoint(x: 10, y: 8),
            control2: CGPoint(x: 13, y: 12)
        )
        path.addCurve(
            to: CGPoint(x: 7, y: 27),
            control1: CGPoint(x: 4, y: 16),
            control2: CGPoint(x: 2, y: 24)
        )
        path.closeSubpath()
        return path
    }

    private static func dirtyFacePath() -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 11.5, y: 20, width: 2.5, height: 2.5))
        path.addEllipse(in: CGRect(x: 18, y: 20, width: 2.5, height: 2.5))
        return path
    }
}
