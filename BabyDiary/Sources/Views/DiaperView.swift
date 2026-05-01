import SwiftUI

struct DiaperScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    private struct Option: Identifiable {
        let type: DiaperEventType
        let label: String
        let sub: String
        let emoji: String
        let tint: Color
        let ink: Color
        var id: DiaperEventType { type }
    }

    private let options: [Option] = [
        .init(type: .wet, label: DiaperEventType.wet.label,
              sub: DiaperEventType.wet.subtitle, emoji: DiaperEventType.wet.emoji,
              tint: Palette.blue, ink: Palette.blueInk),
        .init(type: .dirty, label: DiaperEventType.dirty.label,
              sub: DiaperEventType.dirty.subtitle, emoji: DiaperEventType.dirty.emoji,
              tint: Palette.yellow, ink: Palette.yellowInk),
        .init(type: .both, label: DiaperEventType.both.label,
              sub: DiaperEventType.both.subtitle, emoji: DiaperEventType.both.emoji,
              tint: Palette.mintTint, ink: Palette.mint600),
    ]

    @State private var type: DiaperEventType? = nil
    @State private var diaperNote: String = ""
    @State private var time: Date = .now

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "换尿布记录", onBack: onBack)
            ScreenBody {
                FieldLabel(text: "选择类型").padding(.top, 8).padding(.bottom, 10)
                VStack(spacing: 10) {
                    ForEach(options) { o in typeRow(o) }
                }

                if selectedTypeAllowsNote {
                    notePicker.padding(.top, 22)
                }

                timePicker.padding(.top, 22)

                saveButton.padding(.top, 22)
            }
        }
        .background(Palette.bg)
    }

    private func typeRow(_ o: Option) -> some View {
        let on = type == o.type
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                type = o.type
                if !o.type.allowsNote {
                    diaperNote = ""
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(on ? Color.white.opacity(0.6) : Color.white)
                    Text(o.emoji)
                        .font(.system(size: o.type == .both ? 18 : 22))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 4)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(o.label)
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(-0.16)
                        .foregroundStyle(on ? o.ink : Palette.ink)
                    if !o.sub.isEmpty {
                        Text(o.sub)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(on ? o.ink.opacity(0.8) : Palette.ink3)
                    }
                }
                Spacer(minLength: 0)
                Circle()
                    .strokeBorder(on ? o.ink : Palette.line, lineWidth: on ? 6 : 2)
                    .background(Circle().fill(Color.white))
                    .frame(width: 24, height: 24)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? o.tint : Palette.bg2,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: on ? Color(hex: 0x2B2520).opacity(0.06) : .clear,
                    radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PressableStyle())
    }

    private var notePicker: some View {
        let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]
        let noteOptions = DiaperNotePreset.options(including: diaperNote)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                FieldLabel(text: "备注")
                if !diaperNote.isEmpty {
                    Button("清空") {
                        withAnimation(.easeOut(duration: 0.16)) {
                            diaperNote = ""
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink3)
                    .buttonStyle(.plain)
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(noteOptions, id: \.self) { note in
                    let on = diaperNote == note
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            diaperNote = on ? "" : note
                        }
                    } label: {
                        Text(note)
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(-0.13)
                            .foregroundStyle(on ? Palette.yellowInk : Palette.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(on ? Palette.yellow : Palette.bg2, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            TextField("自己填写", text: $diaperNote)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var timePicker: some View {
        InlineWheelTimePicker(time: $time, theme: store.theme)
    }

    private var saveButton: some View {
        let enabled = type != nil
        let bg: Color = enabled ? store.theme.primary : Palette.bg2
        let fg: Color = enabled ? .white : Palette.ink3
        return Button(action: submit) {
            Text("保存记录")
                .font(.system(size: 17, weight: .heavy))
                .tracking(-0.17)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadowPill(tint: enabled ? bg.opacity(0.9) : .clear)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private var selectedTypeAllowsNote: Bool {
        type?.allowsNote == true
    }

    private func submit() {
        guard let t = type, let o = options.first(where: { $0.type == t }) else { return }

        let trimmedNote = diaperNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = t.allowsNote && !trimmedNote.isEmpty ? trimmedNote : nil
        store.addEvent(.init(kind: .diaper, at: time, title: o.label, sub: note))
        diaperNote = ""
        onBack()
    }
}
