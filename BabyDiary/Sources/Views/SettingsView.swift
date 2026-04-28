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
            return "已经到喂奶时间"
        }
        return "下次 \(dateLabel(due, now: now))"
    }

    private func statusColor(settings: FeedReminderSettings, now: Date) -> Color {
        guard !permissionDenied, settings.isEnabled, let due = store.nextFeedReminderDueDate(now: now) else {
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
}

#Preview("设置") {
    SettingsScreen(onBack: {})
        .environment(AppStore.preview)
}
