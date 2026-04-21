import SwiftUI

struct SleepScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    @State private var draftStart: Date = .now
    @State private var draftEnd: Date = .now
    @State private var saved = false
    @State private var activePicker: SleepPicker?

    private var timer: RunningTimer? { store.activeTimer }
    private var isRunning: Bool { timer?.isRunning ?? false }
    private var effectiveEnd: Date { isRunning ? .now : draftEnd }
    private var displayDuration: TimeInterval {
        if isRunning, let timer {
            return max(0, timer.elapsed(at: .now) + timer.startedAt.timeIntervalSince(draftStart))
        }
        return max(0, draftEnd.timeIntervalSince(draftStart))
    }
    private var timeValidationMessage: String? {
        if draftEnd <= draftStart { return "结束时间需晚于开始时间" }
        return nil
    }
    private var canSaveDraft: Bool { timeValidationMessage == nil }

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
        .onAppear(perform: syncDraftFromTimer)
        .onChange(of: store.activeTimer) { _, _ in syncDraftFromTimer() }
        .sheet(item: $activePicker) { picker in
            SleepPickerSheet(picker: picker,
                             time: binding(for: picker),
                             theme: store.theme,
                             minimumDate: picker.isEnd ? draftStart : nil)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        heroCard(now: now)
        if timer != nil {
            editorCard()
                .padding(.top, 14)
        }
        lastNightCard
        historySection.padding(.top, 26)
    }

    private func heroCard(now: Date) -> some View {
        let paused = timer != nil && !isRunning
        let gradient: LinearGradient = paused
            ? LinearGradient(colors: [Color(hex: 0xEDE7F8), Color(hex: 0xF8F3FC)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : isRunning
            ? LinearGradient(colors: [Color(hex: 0xE4D8F5), Color(hex: 0xF3EBFB)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(hex: 0xFFE8E0), Color(hex: 0xFFF3EC)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
        let accent = paused ? Palette.ink2 : isRunning ? Palette.lavenderInk : store.theme.primary600
        let moonColor = paused ? Palette.ink2 : isRunning ? Palette.lavenderInk : store.theme.primary

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(gradient)
            AppIcon.Moon(size: 120, color: moonColor)
                .opacity(0.6)
                .offset(x: 220, y: -20)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    if isRunning {
                        Circle().fill(Palette.lavenderInk).frame(width: 8, height: 8)
                            .modifier(PulseOpacity())
                    }
                    Text(isRunning ? "正在睡觉" : paused ? "已暂停" : "准备开始")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(0.72)
                        .textCase(.uppercase)
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.6), in: Capsule())

                Text(timer == nil ? "00分 00秒" : formatDur(displayDuration))
                    .font(.system(size: 56, weight: .black))
                    .tracking(-1.68)
                    .monospacedDigit()
                    .foregroundStyle(isRunning ? Palette.lavenderInk : Palette.ink)
                    .padding(.top, 16)

                Text(statusText())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .padding(.top, 10)

                if timer != nil {
                    HStack(spacing: 10) {
                        CTAButton(title: isRunning ? "⏸ 暂停" : "▶ 继续",
                                  variant: .ghost,
                                  theme: store.theme) {
                            isRunning ? pauseSleep(at: now) : resumeSleep(at: now)
                        }
                        CTAButton(title: saved ? "✓ 已保存" : "保存记录",
                                  variant: canSaveDraft ? (saved ? .secondary : .primary) : .ghost,
                                  theme: store.theme) {
                            saveSleep(now: now)
                        }
                        .disabled(!canSaveDraft)
                    }
                    .padding(.top, 22)
                } else {
                    CTAButton(title: "😴 开始睡觉", theme: store.theme) {
                        startSleep(at: now)
                    }
                    .padding(.top, 22)
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadowSurface()
    }

    private func editorCard() -> some View {
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("手动调整时间")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                    Spacer()
                    Text(isRunning ? "先暂停再修改结束时间" : "可修改开始和结束时间")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.ink3)
                }

                CompactDateTimeField(time: $draftStart,
                                     theme: store.theme,
                                     label: "开始时间",
                                     onPickDate: { activePicker = .startDate },
                                     onPickTime: { activePicker = .startTime })
                    .onChange(of: draftStart) { _, newValue in
                        if isRunning {
                            saved = false
                        } else {
                            draftEnd = max(draftEnd, newValue)
                            saved = false
                        }
                    }

                CompactDateTimeField(time: $draftEnd,
                                     theme: store.theme,
                                     label: "结束时间",
                                     onPickDate: { activePicker = .endDate },
                                     onPickTime: { activePicker = .endTime })
                    .disabled(isRunning)
                    .opacity(isRunning ? 0.65 : 1)
                    .onChange(of: draftEnd) { _, _ in saved = false }

                if canSaveDraft {
                    HStack(spacing: 10) {
                        summaryPill(title: "睡了", value: formatDurShort(displayDuration))
                        summaryPill(title: "开始", value: formatTime(draftStart))
                        summaryPill(title: "结束", value: formatTime(effectiveEnd))
                    }
                } else {
                    invalidTimeBanner
                }
            }
        }
    }

    private var invalidTimeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
            Text(timeValidationMessage ?? "")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(Color(hex: 0xFF7F64))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(hex: 0xFF7F64).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            MicroLabel(text: title)
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                                       subtitle: "\(store.baby.name)的每一次小憩都会记录在这里")
                    } else {
                        ForEach(Array(history.enumerated()), id: \.element.id) { i, e in
                            SleepRow(event: e, last: i == history.count - 1) { store.deleteEvent($0) }
                        }
                    }
                }
            }
        }
    }

    private func syncDraftFromTimer() {
        guard let timer = store.activeTimer else {
            draftStart = .now
            draftEnd = .now
            return
        }
        draftStart = timer.startedAt
        draftEnd = timer.startedAt.addingTimeInterval(timer.accumulated)
    }

    private func startSleep(at now: Date) {
        saved = false
        draftStart = now
        draftEnd = now
        store.startTimer(kind: .sleep, at: now)
    }

    private func pauseSleep(at now: Date) {
        store.pauseTimer(at: now)
        draftEnd = now
        saved = false
    }

    private func resumeSleep(at now: Date) {
        if draftEnd > now {
            draftEnd = now
        }
        store.resumeTimer(at: now)
        saved = false
    }

    private func saveSleep(now: Date) {
        guard let timer = store.activeTimer else { return }
        if timer.isRunning {
            store.pauseTimer(at: now)
            draftEnd = now
        }
        guard canSaveDraft else { return }

        let dur = draftEnd.timeIntervalSince(draftStart)
        store.addEvent(.init(
            kind: .sleep,
            at: draftStart,
            endAt: draftEnd,
            title: "睡眠 \(formatDurShort(dur))",
            sub: "\(formatTime(draftStart)) - \(formatTime(draftEnd))"
        ))
        store.stopTimer()
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { saved = false }
    }

    private func statusText() -> String {
        guard let timer else { return "轻触下方按钮记录睡眠开始时间" }
        if timer.isRunning {
            return "开始于 \(formatTime(draftStart))，需要结束时先暂停或直接保存"
        }
        if let message = timeValidationMessage {
            return message
        }
        return "已暂停在 \(formatTime(draftEnd))，可手动调整醒来时间后保存"
    }

    private func binding(for picker: SleepPicker) -> Binding<Date> {
        switch picker {
        case .startDate, .startTime:
            return $draftStart
        case .endDate, .endTime:
            return $draftEnd
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

private struct CompactDateTimeField: View {
    @Binding var time: Date
    let theme: AppTheme
    let label: String
    let onPickDate: () -> Void
    let onPickTime: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: label)
            HStack(spacing: 10) {
                pickerButton(title: sleepDateText(time), style: .date, action: onPickDate)
                pickerButton(title: formatTime(time), style: .time, action: onPickTime)
            }
        }
    }

    private func pickerButton(title: String, style: PickerButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: style.fontSize, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(style.minimumScale)
                .padding(.horizontal, 14)
                .padding(.vertical, style.verticalPadding)
                .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private enum PickerButtonStyle {
        case date, time

        var fontSize: CGFloat {
            switch self {
            case .date: return 15
            case .time: return 18
            }
        }

        var minimumScale: CGFloat {
            switch self {
            case .date: return 0.78
            case .time: return 1
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .date: return 15
            case .time: return 14
            }
        }
    }
}

private enum SleepPicker: String, Identifiable {
    case startDate, startTime, endDate, endTime
    var id: String { rawValue }
    var isDate: Bool { self == .startDate || self == .endDate }
    var isEnd: Bool { self == .endDate || self == .endTime }
    var title: String {
        switch self {
        case .startDate: return "选择开始日期"
        case .startTime: return "选择开始时间"
        case .endDate: return "选择结束日期"
        case .endTime: return "选择结束时间"
        }
    }
}

private struct SleepPickerSheet: View {
    let picker: SleepPicker
    @Binding var time: Date
    let theme: AppTheme
    var minimumDate: Date?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(picker.label)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.72)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.ink3)
                    Text(picker.isDate ? sleepDateText(time) : formatTime(time))
                        .font(.system(size: 28, weight: .black))
                        .tracking(-0.56)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    LinearGradient(colors: [theme.primaryTint, Color.white.opacity(0.92)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .shadowCard()

                Card(padding: 14, cornerRadius: 22) {
                    if picker.isDate {
                        if let minimumDate {
                            DatePicker("", selection: $time, in: minimumDate...Date().addingTimeInterval(365 * 24 * 3600), displayedComponents: .date)
                                .datePickerStyle(.graphical)
                        } else {
                            DatePicker("", selection: $time, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                        }
                    } else {
                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .frame(height: 180)
                            .clipped()
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                Button(action: { dismiss() }) {
                    Text("完成")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
            .labelsHidden()
            .tint(theme.primary600)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .padding(20)
            .background(Palette.bg)
            .navigationTitle(picker.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents(picker.isDate ? [.medium] : [.height(320)])
    }
}

private func sleepDateText(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy/MM/dd"
    return f.string(from: date)
}

private extension SleepPicker {
    var label: String {
        switch self {
        case .startDate, .startTime: return "开始时间"
        case .endDate, .endTime: return "结束时间"
        }
    }
}

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
                        Text("\(formatTime(event.at)) - \(formatTime(endAt))")
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
            .contextMenu {
                Button(role: .destructive) { onDelete(event) } label: {
                    Label("删除", systemImage: "trash")
                }
            }
            if !last {
                Rectangle().fill(Palette.line).frame(height: 1)
            }
        }
    }
}

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
