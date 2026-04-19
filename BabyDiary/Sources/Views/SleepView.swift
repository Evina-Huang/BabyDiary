import SwiftUI

struct SleepScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "睡眠记录", onBack: onBack)
            ScreenBody {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    content(now: ctx.date)
                }
            }
        }
        .background(Palette.bg)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let running = store.timerStart != nil
        let dur: TimeInterval = running ? now.timeIntervalSince(store.timerStart!) : 0
        heroCard(running: running, dur: dur)
        lastNightCard
        historySection.padding(.top, 26)
    }

    private func heroCard(running: Bool, dur: TimeInterval) -> some View {
        let gradient: LinearGradient = running
            ? LinearGradient(colors: [Color(hex: 0xE4D8F5), Color(hex: 0xF3EBFB)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: 0xFFE8E0), Color(hex: 0xFFF3EC)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
        let accent = running ? Palette.lavenderInk : store.theme.primary600
        let moonColor = running ? Palette.lavenderInk : store.theme.primary

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(gradient)
            AppIcon.Moon(size: 120, color: moonColor)
                .opacity(0.6)
                .offset(x: 220, y: -20)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    if running {
                        Circle().fill(Palette.lavenderInk).frame(width: 8, height: 8)
                            .modifier(PulseOpacity())
                    }
                    Text(running ? "正在睡觉" : "准备开始")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.72)
                        .textCase(.uppercase)
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.6), in: Capsule())

                Text(running ? formatDur(dur) : "00分 00秒")
                    .font(.system(size: 56, weight: .black))
                    .tracking(-1.68)
                    .monospacedDigit()
                    .foregroundStyle(running ? Palette.lavenderInk : Palette.ink)
                    .padding(.top, 16)

                Text(running
                     ? "开始于 \(formatTime(store.timerStart!))"
                     : "轻触下方按钮记录睡眠开始时间")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, 10)

                Button(action: toggle) {
                    Text(running ? "🌞 宝宝醒了" : "😴 开始睡觉")
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(-0.18)
                        .foregroundStyle(running ? Palette.lavenderInk : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(running ? Color.white : store.theme.primary,
                                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: running ? .black.opacity(0.08) : store.theme.primary600.opacity(0.35),
                                radius: 14, x: 0, y: 4)
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 22)
            }
            .padding(.horizontal, 22).padding(.vertical, 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadowSurface()
    }

    private var lastNightCard: some View {
        let (wakings, longest) = lastNightStats()
        return Group {
            if wakings > 0 || longest > 0 {
                HStack(spacing: 10) {
                    Card(padding: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            MicroLabel(text: "昨夜夜醒")
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(wakings)")
                                    .font(.system(size: 24, weight: .black))
                                    .tracking(-0.48)
                                Text("次")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.ink3)
                            }
                        }
                    }
                    Card(padding: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            MicroLabel(text: "连续最长")
                            Text(formatDurShort(longest))
                                .font(.system(size: 24, weight: .black))
                                .tracking(-0.48)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private var historySection: some View {
        let history = Array(store.events.filter { $0.kind == .sleep }.prefix(20))
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
                        EmptyStateView(title: "还没有睡眠记录",
                                       subtitle: "小宝的每一次小憩都会记录在这里")
                    } else {
                        ForEach(Array(history.enumerated()), id: \.element.id) { i, e in
                            SleepRow(event: e, last: i == history.count - 1) { store.deleteEvent($0) }
                        }
                    }
                }
            }
        }
    }

    private func toggle() {
        if let start = store.timerStart {
            let end = Date()
            let dur = end.timeIntervalSince(start)
            store.addEvent(.init(
                kind: .sleep, at: start, endAt: end,
                title: "睡眠 \(formatDurShort(dur))",
                sub: "\(formatTime(start)) — \(formatTime(end))"
            ))
            store.timerStart = nil
        } else {
            store.timerStart = Date()
        }
    }

    private func lastNightStats() -> (wakings: Int, longest: TimeInterval) {
        let cal = Calendar.current
        var start = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        if cal.component(.hour, from: Date()) < 12 {
            start = cal.date(byAdding: .day, value: -1, to: start)!
        }
        let end = cal.date(byAdding: .hour, value: 12, to: start)!
        let night = store.events.filter { $0.kind == .sleep && $0.at >= start && $0.at <= end }
        let longest = night.compactMap(\.duration).max() ?? 0
        return (max(0, night.count - 1), longest)
    }
}

// Sleep row uses a duration-centric layout (history list).
private struct SleepRow: View {
    let event: Event
    let last: Bool
    let onDelete: (Event) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CategoryIcon(kind: .sleep, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.duration.map(formatDurShort) ?? event.title)
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    if let endAt = event.endAt {
                        Text("\(formatTime(event.at)) — \(formatTime(endAt))")
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink3)
                    }
                }
                Spacer(minLength: 0)
                Text(formatDateLabel(event.at))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Palette.bg2, in: Capsule())
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(Palette.card)
            .swipeActions(trailing: true) { onDelete(event) }
            if !last {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
    }
}

// Pulse modifier — matches the CSS .pulse-dot keyframes.
private struct PulseOpacity: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 0.4 : 1)
            .scaleEffect(on ? 0.8 : 1)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
