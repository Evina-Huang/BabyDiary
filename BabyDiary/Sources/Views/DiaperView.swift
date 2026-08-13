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
    @State private var showDetails = false
    @State private var showExitConfirmation = false
    @State private var showSaved = false
    @State private var saveCompleted = false
    @State private var initialDraft: DiaperDraft?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "换尿布记录", onBack: requestClose)
            ScreenBody {
                SinceLastBanner(
                    kind: .diaper,
                    lastAt: store.mostRecentEvent(kind: .diaper)?.occurredAt,
                    label: "换尿布"
                )
                .padding(.top, 8)

                typePicker.padding(.top, 24)

                if type != nil {
                    AdjustmentDetails(
                        isExpanded: $showDetails,
                        summary: selectedTypeAllowsNote
                            ? "便便情况、补充说明与记录时间"
                            : "记录时间"
                    ) {
                        diaperDetails
                    }
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RecordSaveBar(status: saveStatus, theme: store.theme, action: submit)
        }
        .overlay(alignment: .top) {
            RecordSuccessToast(isPresented: showSaved, title: "换尿布记录已保存")
                .padding(.top, 12)
        }
        .recordExitProtection(
            exitProtection,
            isPresented: $showExitConfirmation,
            onDiscard: resetDraft,
            onDismiss: onBack
        )
        .onAppear {
            if initialDraft == nil { initialDraft = currentDraft }
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这次是什么情况？")
                .appFont(size: 17, weight: .bold)
                .foregroundStyle(Palette.ink)

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
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
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
                        .foregroundStyle(isSelected ? option.ink : Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(option.sub)
                        .appFont(size: 11, weight: .medium)
                        .foregroundStyle(isSelected ? option.ink.opacity(0.78) : Palette.ink3)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 126)
            .background(
                isSelected ? option.tint : Palette.card,
                in: RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.surface, style: .continuous)
                    .stroke(isSelected ? option.ink.opacity(0.18) : Palette.line, lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(option.label)，\(option.sub)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var diaperDetails: some View {
        VStack(alignment: .leading, spacing: 20) {
            if selectedTypeAllowsNote {
                noteDetails
            }
            timePicker
        }
    }

    private var noteDetails: some View {
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
                                in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                                    .stroke(isSelected ? Palette.yellowInk.opacity(0.14) : .clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "补充说明")
                TextField("补充其他情况", text: $diaperNote)
                    .appFont(size: 16, weight: .medium)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                    .accessibilityLabel("便便情况补充说明")
            }
        }
    }

    private var timePicker: some View {
        InlineWheelTimePicker(time: $time, theme: store.theme)
    }

    private var saveStatus: RecordSaveStatus {
        if saveCompleted { return .success }
        guard type != nil else { return .disabledQuietly }
        return .ready("保存")
    }

    private var selectedTypeAllowsNote: Bool {
        type?.allowsNote == true
    }

    private func submit() {
        guard let selectedType = type, !saveCompleted else { return }

        let trimmedNote = diaperNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = selectedType.allowsNote && !trimmedNote.isEmpty ? trimmedNote : nil
        store.addEvent(.init(kind: .diaper, at: time, title: selectedType.label, sub: note))
        saveCompleted = true
        RecordSaveFeedback.complete(isPresented: $showSaved, then: onBack)
    }

    private var currentDraft: DiaperDraft {
        DiaperDraft(type: type, note: diaperNote, time: time)
    }

    private var exitProtection: RecordExitProtection {
        guard !saveCompleted, let initialDraft, currentDraft != initialDraft else { return .none }
        return .unsaved
    }

    private func requestClose() {
        if exitProtection.requiresConfirmation {
            showExitConfirmation = true
        } else {
            onBack()
        }
    }

    private func resetDraft() {
        type = nil
        diaperNote = ""
        time = initialDraft?.time ?? .now
        showDetails = false
    }
}

private struct DiaperDraft: Equatable {
    let type: DiaperEventType?
    let note: String
    let time: Date
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
