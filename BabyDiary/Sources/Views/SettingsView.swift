import SwiftUI
import UserNotifications

struct SettingsScreen: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "设置", onBack: onBack)
            ScreenBody {
                VStack(alignment: .leading, spacing: 12) {
                    Text("提醒")
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(-0.15)
                        .foregroundStyle(Palette.ink)
                    FeedReminderSettingsCard()
                    SleepReminderSettingsCard()
                }
                .padding(.top, 6)
            }
        }
        .background(Palette.bg)
    }
}

private struct FeedReminderSettingsCard: View {
    @Environment(AppStore.self) private var store
    @State private var requestingPermission = false
    @State private var permissionDenied = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let settings = store.feedReminder

            Card(padding: 14) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.pink)
                            AppIcon.Clock(size: 22, color: Palette.pinkInk)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("喂奶提醒")
                                .font(.system(size: 15, weight: .heavy))
                                .tracking(-0.15)
                                .foregroundStyle(Palette.ink)
                            Text(statusText(settings: settings, now: ctx.date))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(statusColor(settings: settings, now: ctx.date))
                        }

                        Spacer(minLength: 0)

                        Toggle("", isOn: Binding(
                            get: { store.feedReminder.isEnabled },
                            set: { setEnabled($0) }
                        ))
                        .labelsHidden()
                        .tint(store.theme.primary600)
                        .disabled(requestingPermission)
                    }

                    if settings.isEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                FieldLabel(text: "提醒间隔")
                                Spacer()
                                Text("\(settings.normalizedIntervalHours) 小时")
                                    .font(.system(size: 13, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.pinkInk)
                            }

                            StepperInput(
                                value: Binding(
                                    get: { store.feedReminder.normalizedIntervalHours },
                                    set: { store.updateFeedReminderInterval(hours: $0) }
                                ),
                                step: 1,
                                min: FeedReminderSettings.minIntervalHours,
                                max: FeedReminderSettings.maxIntervalHours,
                                suffix: "小时"
                            )

                            HStack(spacing: 8) {
                                ForEach([2, 3, 4], id: \.self) { hours in
                                    intervalPreset(hours)
                                }
                            }

                            Rectangle()
                                .fill(Palette.line)
                                .frame(height: 1)
                                .padding(.vertical, 2)

                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    FieldLabel(text: "免提醒时间段")
                                    if settings.quietHoursEnabled {
                                        Text("\(timeText(settings.normalizedQuietStartMinuteOfDay)) - \(timeText(settings.normalizedQuietEndMinuteOfDay)) 不提醒")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Palette.ink3)
                                    }
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { store.feedReminder.quietHoursEnabled },
                                    set: { store.setFeedReminderQuietHoursEnabled($0) }
                                ))
                                .labelsHidden()
                                .tint(store.theme.primary600)
                            }

                            if settings.quietHoursEnabled {
                                HStack(spacing: 10) {
                                    quietTimePicker(
                                        title: "开始",
                                        minute: settings.normalizedQuietStartMinuteOfDay,
                                        setMinute: store.updateFeedReminderQuietStartMinute
                                    )
                                    quietTimePicker(
                                        title: "结束",
                                        minute: settings.normalizedQuietEndMinuteOfDay,
                                        setMinute: store.updateFeedReminderQuietEndMinute
                                    )
                                }
                            }
                        }
                    } else if permissionDenied {
                        Text("系统通知未开启")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xD44E3A))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .onAppear(perform: refreshPermissionStatus)
    }

    private func intervalPreset(_ hours: Int) -> some View {
        Button {
            store.updateFeedReminderInterval(hours: hours)
        } label: {
            Text("\(hours) 小时")
                .font(.system(size: 12, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(store.feedReminder.normalizedIntervalHours == hours ? .white : Palette.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    store.feedReminder.normalizedIntervalHours == hours ? store.theme.primary : Palette.bg2,
                    in: Capsule()
                )
        }
        .buttonStyle(PressableStyle())
    }

    private func quietTimePicker(
        title: String,
        minute: Int,
        setMinute: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: title)
            DatePicker(
                "",
                selection: Binding(
                    get: { dateForMinute(minute) },
                    set: { setMinute(minuteOfDay($0)) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func setEnabled(_ isEnabled: Bool) {
        if isEnabled {
            requestingPermission = true
            permissionDenied = false
            Task {
                let granted = await FeedReminderNotificationController.requestAuthorization()
                await MainActor.run {
                    requestingPermission = false
                    permissionDenied = !granted
                    store.setFeedReminderEnabled(granted)
                }
            }
        } else {
            permissionDenied = false
            store.setFeedReminderEnabled(false)
        }
    }

    private func refreshPermissionStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let status = settings.authorizationStatus
            await MainActor.run {
                permissionDenied = status == .denied
            }
        }
    }

    private func statusText(settings: FeedReminderSettings, now: Date) -> String {
        if requestingPermission {
            return "等待系统确认"
        }
        if permissionDenied {
            return "系统通知未开启"
        }
        guard settings.isEnabled else {
            return "未开启"
        }
        guard let due = store.nextFeedReminderDueDate(now: now) else {
            return "未开启"
        }
        if due <= now {
            if settings.quietHoursEnabled,
               FeedReminderPlanner.isInQuietHours(now, settings: settings),
               let next = FeedReminderPlanner.scheduledDates(
                   settings: settings,
                   lastFeed: store.mostRecentEvent(kind: .feed),
                   now: now,
                   count: 1
               ).first {
                return "\(dateLabel(next, now: now)) 再提醒"
            }
            return "已经到喂奶时间"
        }
        if settings.quietHoursEnabled, FeedReminderPlanner.isInQuietHours(now, settings: settings) {
            return "\(dateLabel(due, now: now)) 再提醒"
        }
        return "下次 \(dateLabel(due, now: now))"
    }

    private func statusColor(settings: FeedReminderSettings, now: Date) -> Color {
        guard !permissionDenied, settings.isEnabled, let due = store.nextFeedReminderDueDate(now: now) else {
            return Palette.ink3
        }
        if settings.quietHoursEnabled, FeedReminderPlanner.isInQuietHours(now, settings: settings) {
            return Palette.ink3
        }
        return due <= now ? Color(hex: 0xD44E3A) : Palette.ink3
    }

    private func dateLabel(_ date: Date, now: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "HH:mm" : "M月d日 HH:mm"
        return f.string(from: date)
    }

    private func timeText(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func dateForMinute(_ minute: Int) -> Date {
        let clamped = FeedReminderSettings.clampedMinuteOfDay(minute)
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .minute, value: clamped, to: start) ?? start
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return FeedReminderSettings.clampedMinuteOfDay((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }
}

private struct SleepReminderSettingsCard: View {
    @Environment(AppStore.self) private var store
    @State private var requestingPermission = false
    @State private var permissionDenied = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let settings = store.sleepReminder

            Card(padding: 14) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Palette.lavender)
                            AppIcon.Moon(size: 24, color: Palette.lavenderInk)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("哄睡提醒")
                                .font(.system(size: 15, weight: .heavy))
                                .tracking(-0.15)
                                .foregroundStyle(Palette.ink)
                            Text(statusText(settings: settings, now: ctx.date))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(statusColor(settings: settings, now: ctx.date))
                        }

                        Spacer(minLength: 0)

                        Toggle("", isOn: Binding(
                            get: { store.sleepReminder.isEnabled },
                            set: { setEnabled($0) }
                        ))
                        .labelsHidden()
                        .tint(store.theme.primary600)
                        .disabled(requestingPermission)
                    }

                    if settings.isEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                FieldLabel(text: "清醒间隔")
                                Spacer()
                                Text(intervalText(settings.normalizedAwakeIntervalMinutes))
                                    .font(.system(size: 13, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.lavenderInk)
                            }

                            StepperInput(
                                value: Binding(
                                    get: { store.sleepReminder.normalizedAwakeIntervalMinutes },
                                    set: { store.updateSleepReminderAwakeInterval(minutes: $0) }
                                ),
                                step: 15,
                                min: SleepReminderSettings.minAwakeIntervalMinutes,
                                max: SleepReminderSettings.maxAwakeIntervalMinutes,
                                suffix: "分钟"
                            )

                            HStack(spacing: 8) {
                                ForEach([90, 120, 180], id: \.self) { minutes in
                                    intervalPreset(minutes)
                                }
                            }

                            Rectangle()
                                .fill(Palette.line)
                                .frame(height: 1)
                                .padding(.vertical, 2)

                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    FieldLabel(text: "静默时间段")
                                    if settings.quietHoursEnabled {
                                        Text("\(timeText(settings.normalizedQuietStartMinuteOfDay)) - \(timeText(settings.normalizedQuietEndMinuteOfDay)) 不提醒")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Palette.ink3)
                                    }
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { store.sleepReminder.quietHoursEnabled },
                                    set: { store.setSleepReminderQuietHoursEnabled($0) }
                                ))
                                .labelsHidden()
                                .tint(store.theme.primary600)
                            }

                            if settings.quietHoursEnabled {
                                HStack(spacing: 10) {
                                    quietTimePicker(
                                        title: "开始",
                                        minute: settings.normalizedQuietStartMinuteOfDay,
                                        setMinute: store.updateSleepReminderQuietStartMinute
                                    )
                                    quietTimePicker(
                                        title: "结束",
                                        minute: settings.normalizedQuietEndMinuteOfDay,
                                        setMinute: store.updateSleepReminderQuietEndMinute
                                    )
                                }
                            }
                        }
                    } else if permissionDenied {
                        Text("系统通知未开启")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xD44E3A))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .onAppear(perform: refreshPermissionStatus)
    }

    private func intervalPreset(_ minutes: Int) -> some View {
        Button {
            store.updateSleepReminderAwakeInterval(minutes: minutes)
        } label: {
            Text(intervalText(minutes))
                .font(.system(size: 12, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(store.sleepReminder.normalizedAwakeIntervalMinutes == minutes ? .white : Palette.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    store.sleepReminder.normalizedAwakeIntervalMinutes == minutes ? store.theme.primary : Palette.bg2,
                    in: Capsule()
                )
        }
        .buttonStyle(PressableStyle())
    }

    private func quietTimePicker(
        title: String,
        minute: Int,
        setMinute: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: title)
            DatePicker(
                "",
                selection: Binding(
                    get: { dateForMinute(minute) },
                    set: { setMinute(minuteOfDay($0)) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func setEnabled(_ isEnabled: Bool) {
        if isEnabled {
            requestingPermission = true
            permissionDenied = false
            Task {
                let granted = await SleepReminderNotificationController.requestAuthorization()
                await MainActor.run {
                    requestingPermission = false
                    permissionDenied = !granted
                    store.setSleepReminderEnabled(granted)
                }
            }
        } else {
            permissionDenied = false
            store.setSleepReminderEnabled(false)
        }
    }

    private func refreshPermissionStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let status = settings.authorizationStatus
            await MainActor.run {
                permissionDenied = status == .denied
            }
        }
    }

    private func statusText(settings: SleepReminderSettings, now: Date) -> String {
        if requestingPermission {
            return "等待系统确认"
        }
        if permissionDenied {
            return "系统通知未开启"
        }
        guard settings.isEnabled else {
            return "未开启"
        }
        if store.activeTimer?.kind == .sleep {
            return "睡眠中"
        }
        guard let due = store.nextSleepReminderDueDate(now: now) else {
            return "未开启"
        }
        if due <= now {
            if settings.quietHoursEnabled,
               SleepReminderPlanner.isInQuietHours(now, settings: settings),
               let next = SleepReminderPlanner.scheduledDates(
                   settings: settings,
                   lastSleep: store.mostRecentEvent(kind: .sleep),
                   isSleeping: false,
                   now: now,
                   count: 1
               ).first {
                return "\(dateLabel(next, now: now)) 再提醒"
            }
            return "已经到哄睡时间"
        }
        if settings.quietHoursEnabled, SleepReminderPlanner.isInQuietHours(now, settings: settings) {
            return "\(dateLabel(due, now: now)) 再提醒"
        }
        return "下次 \(dateLabel(due, now: now))"
    }

    private func statusColor(settings: SleepReminderSettings, now: Date) -> Color {
        guard !permissionDenied, settings.isEnabled else {
            return Palette.ink3
        }
        if store.activeTimer?.kind == .sleep {
            return Palette.ink3
        }
        guard let due = store.nextSleepReminderDueDate(now: now) else {
            return Palette.ink3
        }
        if settings.quietHoursEnabled, SleepReminderPlanner.isInQuietHours(now, settings: settings) {
            return Palette.ink3
        }
        return due <= now ? Color(hex: 0xD44E3A) : Palette.ink3
    }

    private func dateLabel(_ date: Date, now: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "HH:mm" : "M月d日 HH:mm"
        return f.string(from: date)
    }

    private func timeText(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func dateForMinute(_ minute: Int) -> Date {
        let clamped = SleepReminderSettings.clampedMinuteOfDay(minute)
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .minute, value: clamped, to: start) ?? start
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return SleepReminderSettings.clampedMinuteOfDay((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    private func intervalText(_ minutes: Int) -> String {
        switch minutes {
        case 60:
            return "1小时"
        case let value where value.isMultiple(of: 60):
            return "\(value / 60)小时"
        case let value where value > 60:
            return "\(value / 60)小时\(value % 60)分"
        default:
            return "\(minutes)分钟"
        }
    }
}

#Preview("设置") {
    SettingsScreen(onBack: {})
        .environment(AppStore.preview)
}
