import SwiftUI

struct DiaperScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    enum DType: String, Hashable { case wet, dirty, both }

    private struct Option: Identifiable {
        let k: DType
        let label: String
        let sub: String
        let emoji: String
        let tint: Color
        let ink: Color
        var id: DType { k }
    }

    private let options: [Option] = [
        .init(k: .wet,   label: "湿尿布",   sub: "只有尿",    emoji: "💧",   tint: Palette.blue,     ink: Palette.blueInk),
        .init(k: .dirty, label: "臭臭",     sub: "便便",      emoji: "💩",   tint: Palette.yellow,   ink: Palette.yellowInk),
        .init(k: .both,  label: "两者都有", sub: "湿 + 便便", emoji: "💧💩", tint: Palette.mintTint, ink: Palette.mint600),
    ]

    @State private var type: DType? = nil
    @State private var time: Date = .now
    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "换尿布记录", onBack: onBack)
            ScreenBody {
                FieldLabel(text: "选择类型").padding(.top, 8).padding(.bottom, 10)
                VStack(spacing: 10) {
                    ForEach(options) { o in typeRow(o) }
                }

                timePicker.padding(.top, 22)

                saveButton.padding(.top, 22)

                historySection.padding(.top, 26)
            }
        }
        .background(Palette.bg)
    }

    private func typeRow(_ o: Option) -> some View {
        let on = type == o.k
        return Button { withAnimation(.easeOut(duration: 0.16)) { type = o.k } } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(on ? Color.white.opacity(0.6) : Color.white)
                    Text(o.emoji).font(.system(size: 22))
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(o.label)
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(-0.16)
                        .foregroundStyle(on ? o.ink : Palette.ink)
                    Text(o.sub)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? o.ink.opacity(0.8) : Palette.ink3)
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

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "时间")
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white)
                    AppIcon.Clock(size: 20, color: store.theme.primary600)
                }
                .frame(width: 36, height: 36)
                Text(formatTime(time))
                    .font(.system(size: 16, weight: .heavy))
                    .tracking(-0.16)
                Spacer(minLength: 0)
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(store.theme.primary600)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var saveButton: some View {
        let enabled = type != nil
        let bg: Color = saved ? Palette.mint : (enabled ? store.theme.primary : Palette.bg2)
        let fg: Color = (enabled || saved) ? .white : Palette.ink3
        return Button(action: submit) {
            Text(saved ? "✓ 已保存" : "保存记录")
                .font(.system(size: 17, weight: .heavy))
                .tracking(-0.17)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadowPill(tint: (enabled || saved) ? bg.opacity(0.9) : .clear)
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private var historySection: some View {
        let history = Array(store.events.filter { $0.kind == .diaper }.prefix(20))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近记录")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.15)
                Spacer()
                Text("共 \(history.count) 条")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.ink3)
            }
            Card(padding: 0) {
                VStack(spacing: 0) {
                    if history.isEmpty {
                        EmptyStateView(title: "还没有尿布记录",
                                       subtitle: "跟踪换尿布的频率能帮你了解宝宝健康")
                    } else {
                        ForEach(Array(history.enumerated()), id: \.element.id) { i, e in
                            EventRow(event: e, last: i == history.count - 1, onDelete: { store.deleteEvent($0) })
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }

    private func submit() {
        guard let t = type, let o = options.first(where: { $0.k == t }) else { return }
        store.addEvent(.init(kind: .diaper, at: time, title: o.label, sub: o.sub))
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { saved = false }
        }
        type = nil
        time = Date()
    }
}
