import SwiftUI
import UserNotifications

struct SettingsScreen: View {
    let onBack: () -> Void
    @Environment(AppStore.self) private var store

    private var enabledCount: Int {
        (store.feedReminder.isEnabled ? 1 : 0) + (store.sleepReminder.isEnabled ? 1 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "设置", onBack: onBack)
            ScreenBody {
                appearanceSection
                    .padding(.top, 4)

                reminderOverview
                    .padding(.top, 22)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("提醒项目")
                            .appFont(size: 15, weight: .heavy)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(enabledCount) / 2 已开启")
                            .appFont(size: 12, weight: .bold)
                            .foregroundStyle(Palette.ink3)
                    }

                    FeedReminderSettingsCard()
                    SleepReminderSettingsCard()
                }
                .padding(.top, 22)
            }
        }
        .background(Palette.bg)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("显示")
                    .appFont(size: 15, weight: .heavy)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("当前 · \(store.appearance.label)")
                    .appFont(size: 12, weight: .bold)
                    .foregroundStyle(Palette.ink3)
            }

            AppearanceSettingsCard()
        }
    }

    private var reminderOverview: some View {
        Card(padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .fill(store.theme.primaryTint)
                    AppIcon.Clock(size: 25, color: store.theme.primary600)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 6) {
                    Text(enabledCount == 0 ? "提醒尚未开启" : "已开启 \(enabledCount) 项提醒")
                        .appText(.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text("根据最近一次记录安排下一次提醒，也可以设置夜间免打扰。")
                        .appFont(size: 13, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct AppearanceSettingsCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("应用外观")
                        .appFont(size: 16, weight: .heavy)
                        .foregroundStyle(Palette.ink)
                    Text("跟随系统会随设备自动切换；文字大小继续使用 iOS 设置。")
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                    ForEach(AppAppearance.allCases) { option in
                        appearanceButton(option)
                    }
                }

                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("主题色")
                        .appText(.bodyEmphasis)
                        .foregroundStyle(Palette.ink)
                    Text("四套主题共用同一组浅色与深色语义 Token。")
                        .appText(.caption)
                        .foregroundStyle(Palette.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(AppTheme.allCases) { theme in
                        themeButton(theme)
                    }
                }
            }
        }
    }

    private func appearanceButton(_ option: AppAppearance) -> some View {
        let selected = store.appearance == option

        return Button {
            store.updateAppearance(option)
        } label: {
            HStack(spacing: 5) {
                Text(option.label)
                    .appText(.captionEmphasis)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if selected {
                    AppIcon.Check(size: 13, color: store.theme.primary600)
                }
            }
            .foregroundStyle(selected ? store.theme.primary600 : Palette.ink2)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(
                selected ? store.theme.primaryTint : Palette.bg2,
                in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                    .stroke(selected ? store.theme.primary600.opacity(0.34) : Palette.line, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("外观，\(option.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func themeButton(_ option: AppTheme) -> some View {
        let selected = store.theme == option

        return Button {
            store.updateTheme(option)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(option.primary)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle().stroke(option.primary600.opacity(0.45), lineWidth: 1)
                    }
                Text(option.label)
                    .appText(.captionEmphasis)
                    .foregroundStyle(selected ? option.primary600 : Palette.ink2)
                Spacer(minLength: 0)
                if selected {
                    AppIcon.Check(size: 13, color: option.primary600)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected ? option.primaryTint : Palette.bg2,
                        in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                    .stroke(selected ? option.primary600.opacity(0.42) : Palette.line,
                            lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("主题，\(option.label)")
        .accessibilityValue(selected ? "已选中" : "未选中")
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .fill(Palette.pink)
                            AppIcon.Bottle(size: 24, color: Palette.pinkInk)
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("喂养提醒")
                                .appFont(size: 15, weight: .heavy)
                                .foregroundStyle(Palette.ink)
                            Text(statusText(settings: settings, now: ctx.date))
                                .appFont(size: 12, weight: .semibold)
                                .foregroundStyle(statusColor(settings: settings, now: ctx.date))
                        }

                        Spacer(minLength: 0)

                        Toggle("", isOn: Binding(
                            get: { store.feedReminder.isEnabled },
                            set: { setEnabled($0) }
                        ))
                        .labelsHidden()
                        .accessibilityLabel("喂养提醒")
                        .tint(store.theme.primary600)
                        .disabled(requestingPermission)
                    }

                    if settings.isEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "提醒模式")
                            SegPill(
                                selection: Binding(
                                    get: { store.feedReminder.mode },
                                    set: { store.updateFeedReminderMode($0) }
                                ),
                                options: FeedReminderMode.allCases.map { ($0, $0.label) }
                            )

                            switch settings.mode {
                            case .interval:
                                intervalSettings(settings: settings)
                            case .schedule:
                                scheduleSettings(settings: settings)
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
                                            .appFont(size: 12, weight: .semibold)
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
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.pinkInk)
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
                .appFont(size: 12, weight: .heavy)
                .monospacedDigit()
                .foregroundStyle(store.feedReminder.normalizedIntervalHours == hours ? .white : Palette.ink2)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(
                    store.feedReminder.normalizedIntervalHours == hours ? store.theme.primary : Palette.bg2,
                    in: Capsule()
                )
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private func intervalSettings(settings: FeedReminderSettings) -> some View {
        HStack {
            FieldLabel(text: "提醒间隔")
            Spacer()
            Text("\(settings.normalizedIntervalHours) 小时")
                .appFont(size: 13, weight: .heavy)
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
    }

    @ViewBuilder
    private func scheduleSettings(settings: FeedReminderSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    FieldLabel(text: "作息表")
                    Text("按设置的时间提醒；刚喝过奶时，下一顿喝奶最多顺延 30 分钟")
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                }
                Spacer()
                Text("\(settings.normalizedScheduleEntries.count) 餐")
                    .appFont(size: 12, weight: .heavy)
                    .foregroundStyle(Palette.pinkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Palette.pink, in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(settings.normalizedScheduleEntries) { entry in
                    scheduleEntryRow(entry, settings: settings)
                }
            }

            if settings.normalizedScheduleEntries.count < FeedReminderSettings.maxScheduleEntries {
                Button {
                    store.addFeedReminderScheduleEntry()
                } label: {
                    HStack(spacing: 7) {
                        Text("+")
                            .appFont(size: 16, weight: .black)
                        Text("添加一餐")
                            .appFont(size: 12, weight: .heavy)
                    }
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }

            scheduleTimePicker(
                title: "最晚提醒",
                minute: settings.normalizedLatestReminderMinuteOfDay,
                setMinute: store.updateFeedReminderLatestMinute
            )
        }
    }

    private func scheduleEntryRow(
        _ entry: FeedReminderScheduleEntry,
        settings: FeedReminderSettings
    ) -> some View {
        HStack(spacing: 9) {
            Menu {
                ForEach(FeedReminderScheduleKind.allCases, id: \.self) { kind in
                    Button(kind.label) {
                        store.updateFeedReminderScheduleEntry(id: entry.id, kind: kind)
                    }
                }
            } label: {
                Text(entry.kind.label)
                    .appFont(size: 12, weight: .heavy)
                    .foregroundStyle(entry.kind == .feed ? Palette.pinkInk : Palette.yellowInk)
                    .frame(width: 46)
                    .padding(.vertical, 8)
                    .background(
                        entry.kind == .feed ? Palette.pink : Palette.yellow,
                        in: Capsule()
                    )
            }

            DatePicker(
                "",
                selection: Binding(
                    get: { dateForMinute(entry.offsetMinutes) },
                    set: {
                        store.updateFeedReminderScheduleEntry(
                            id: entry.id,
                            offsetMinutes: minuteOfDay($0)
                        )
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .center)

            Button {
                store.deleteFeedReminderScheduleEntry(id: entry.id)
            } label: {
                AppIcon.Close(size: 15, color: Palette.ink3)
                    .frame(width: 44, height: 44)
                    .background(.white, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous)
                            .stroke(Palette.line, lineWidth: 1)
                    }
            }
            .buttonStyle(PressableStyle())
            .disabled(settings.normalizedScheduleEntries.count <= FeedReminderSettings.minScheduleEntries)
            .opacity(settings.normalizedScheduleEntries.count <= FeedReminderSettings.minScheduleEntries ? 0.35 : 1)
        }
        .padding(8)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func scheduleTimePicker(
        title: String,
        minute: Int,
        setMinute: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                FieldLabel(text: title)
                Text("超过这个时间，当天不再补提醒")
                    .appFont(size: 12, weight: .semibold)
                    .foregroundStyle(Palette.ink3)
            }

            Spacer(minLength: 0)

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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
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
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
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
        guard let item = store.nextFeedReminderItem(now: now) else {
            return "未开启"
        }
        let due = item.date
        if due <= now {
            if settings.quietHoursEnabled,
               FeedReminderPlanner.isInQuietHours(now, settings: settings),
               let next = FeedReminderPlanner.scheduledItems(
                   settings: settings,
                   lastFeed: store.mostRecentEvent(kind: .feed),
                   events: store.events,
                   now: now,
                   count: 1
               ).first {
                return "\(dateLabel(next.date, now: now)) 再提醒"
            }
            return item.kind == .solid ? "已经到辅食时间" : "已经到喝奶时间"
        }
        if settings.quietHoursEnabled, FeedReminderPlanner.isInQuietHours(now, settings: settings) {
            return "\(dateLabel(due, now: now)) 再提醒"
        }
        return "下次\(item.kind.label) \(dateLabel(due, now: now))"
    }

    private func statusColor(settings: FeedReminderSettings, now: Date) -> Color {
        guard !permissionDenied, settings.isEnabled, let due = store.nextFeedReminderDueDate(now: now) else {
            return Palette.ink3
        }
        if settings.quietHoursEnabled, FeedReminderPlanner.isInQuietHours(now, settings: settings) {
            return Palette.ink3
        }
        return due <= now ? Palette.pinkInk : Palette.ink3
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
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .fill(Palette.lavender)
                            AppIcon.Moon(size: 24, color: Palette.lavenderInk)
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("哄睡提醒")
                                .appFont(size: 15, weight: .heavy)
                                .foregroundStyle(Palette.ink)
                            Text(statusText(settings: settings, now: ctx.date))
                                .appFont(size: 12, weight: .semibold)
                                .foregroundStyle(statusColor(settings: settings, now: ctx.date))
                        }

                        Spacer(minLength: 0)

                        Toggle("", isOn: Binding(
                            get: { store.sleepReminder.isEnabled },
                            set: { setEnabled($0) }
                        ))
                        .labelsHidden()
                        .accessibilityLabel("哄睡提醒")
                        .tint(store.theme.primary600)
                        .disabled(requestingPermission)
                    }

                    if settings.isEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            FieldLabel(text: "提醒方式")
                            SegPill<SleepReminderMode>(
                                selection: Binding(
                                    get: { store.sleepReminder.mode },
                                    set: { store.updateSleepReminderMode($0) }
                                ),
                                options: SleepReminderMode.allCases.map { ($0, $0.label) }
                            )
                            .frame(minHeight: 44)

                            switch settings.mode {
                            case .awakeInterval:
                                sleepIntervalSettings(settings: settings)
                            case .schedule:
                                sleepScheduleSettings(settings: settings)
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
                                            .appFont(size: 12, weight: .semibold)
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
                            .appFont(size: 12, weight: .semibold)
                            .foregroundStyle(Palette.pinkInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .onAppear(perform: refreshPermissionStatus)
    }

    @ViewBuilder
    private func sleepIntervalSettings(settings: SleepReminderSettings) -> some View {
        HStack {
            FieldLabel(text: "清醒间隔")
            Spacer()
            Text(intervalText(settings.normalizedAwakeIntervalMinutes))
                .appFont(size: 13, weight: .heavy)
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
    }

    private func sleepScheduleSettings(settings: SleepReminderSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    FieldLabel(text: "每日哄睡时间")
                    Text("到点提醒，可设置午睡和晚间入睡")
                        .appFont(size: 12, weight: .semibold)
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 8)
                Text("\(settings.normalizedScheduleEntries.count) 个")
                    .appFont(size: 12, weight: .heavy)
                    .foregroundStyle(Palette.lavenderInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Palette.lavender, in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(settings.normalizedScheduleEntries) { entry in
                    sleepScheduleEntryRow(entry, settings: settings)
                }
            }

            if settings.normalizedScheduleEntries.count < SleepReminderSettings.maxScheduleEntries {
                Button {
                    store.addSleepReminderScheduleEntry()
                } label: {
                    HStack(spacing: 7) {
                        AppIcon.Plus(size: 15, color: Palette.ink2)
                        Text("添加哄睡时间")
                            .appFont(size: 12, weight: .heavy)
                    }
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func sleepScheduleEntryRow(
        _ entry: SleepReminderScheduleEntry,
        settings: SleepReminderSettings
    ) -> some View {
        HStack(spacing: 10) {
            DatePicker(
                "",
                selection: Binding(
                    get: { dateForMinute(entry.minuteOfDay) },
                    set: {
                        store.updateSleepReminderScheduleEntry(
                            id: entry.id,
                            minuteOfDay: minuteOfDay($0)
                        )
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.deleteSleepReminderScheduleEntry(id: entry.id)
            } label: {
                AppIcon.Close(size: 15, color: Palette.ink3)
                    .frame(width: 44, height: 44)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .disabled(settings.normalizedScheduleEntries.count <= SleepReminderSettings.minScheduleEntries)
            .opacity(settings.normalizedScheduleEntries.count <= SleepReminderSettings.minScheduleEntries ? 0.35 : 1)
            .accessibilityLabel("删除这个哄睡时间")
        }
        .padding(8)
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
    }

    private func intervalPreset(_ minutes: Int) -> some View {
        Button {
            store.updateSleepReminderAwakeInterval(minutes: minutes)
        } label: {
            Text(intervalText(minutes))
                .appFont(size: 12, weight: .heavy)
                .monospacedDigit()
                .foregroundStyle(store.sleepReminder.normalizedAwakeIntervalMinutes == minutes ? .white : Palette.ink2)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
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
        .background(Palette.bg2, in: RoundedRectangle(cornerRadius: AppRadius.compact, style: .continuous))
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
        return due <= now ? Palette.pinkInk : Palette.ink3
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
