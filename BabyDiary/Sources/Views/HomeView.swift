import SwiftUI
import PhotosUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    var onOpen: (SubScreen) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Greeting block
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLine())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.72)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.ink3)
                    let g = greeting(for: store.baby)
                    Text(g.text)
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(-0.36)
                        .foregroundStyle(Palette.ink)
                    if let sub = g.sub {
                        Text(sub)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(g.isSpecial ? store.theme.primary600 : Palette.ink3)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                Button { onOpen(.backup) } label: {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.theme.primary600)
                        .frame(width: 40, height: 40)
                        .background(store.theme.primaryTint, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("数据备份")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 2)

            ScreenBody {
                BabyBadge()
                    .padding(.top, 10)

                // 2×2 quick-add grid
                let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: cols, spacing: 12) {
                    QuickTile(kind: .sleep,  onTap: { onOpen(.sleep) })
                    QuickTile(kind: .feed,   onTap: { onOpen(.feed) })
                    QuickTile(kind: .diaper, onTap: { onOpen(.diaper) })
                    QuickTile(kind: .solid,  onTap: { onOpen(.solid) })
                }
                .padding(.top, 12)

                if let timer = store.activeTimer, timer.isRunning {
                    TimerBanner(timer: timer).padding(.top, 14)
                }

                SinceLastRow().padding(.top, 10)

                DailySummaryStrip().padding(.top, 4)

                VaccineReminderBanner(onOpen: { onOpen(.vaccine) })
                    .padding(.top, 14)

            }
        }
        .background(Palette.bg)
    }

    private func dateLine() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }
}

// MARK: — Greeting: daily random phrase + milestone celebration

private struct Greeting {
    let text: String
    let sub: String?
    let isSpecial: Bool
}

private let dailyPhrases: [String] = [
    "今天也是被爱着的一天 🤍",
    "做父母是一场温柔的修行 🌱",
    "再累的夜,都会等到天亮 ☀️",
    "小小的抱抱,大大的力量 🫶",
    "你已经做得很好啦 ✨",
    "慢慢来,没关系 🍃",
    "每一次喂奶都是心跳的对话 🫧",
    "别忘了也爱自己一下 🌷",
    "今天的笑声要记得存好 🎀",
    "成长是一场看不见的烟花 🎆",
    "软软的小手,抓住了整个世界 🌏",
    "今天的云也像棉花糖 ☁️",
    "安心呼吸,一切都在变好 🌼",
    "陪伴,是最长情的告白 💌",
    "你是他最喜欢的人 💕",
]

private func greeting(for baby: Baby) -> Greeting {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let birth = cal.startOfDay(for: baby.birthDate)
    let days = max(0, cal.dateComponents([.day], from: birth, to: today).day ?? 0)

    // Special day: 100-day, 200-day, 365-day, exact monthly anniversary
    if days > 0, days % 100 == 0 {
        return Greeting(text: "\(baby.name)来到这个世界的第 \(days) 天 🎉",
                        sub: "每一个 100 天,都是了不起的里程碑",
                        isSpecial: true)
    }
    if days == 365 {
        return Greeting(text: "\(baby.name)一岁啦 🎂", sub: "生日快乐,第一个小生日", isSpecial: true)
    }
    let comps = cal.dateComponents([.year, .month, .day], from: birth, to: today)
    if comps.day == 0 {
        let months = (comps.year ?? 0) * 12 + (comps.month ?? 0)
        if months > 0 {
            if months == 12 {
                return Greeting(text: "满一岁了 🎂", sub: "\(baby.name)整整一岁啦", isSpecial: true)
            }
            return Greeting(text: "\(baby.name)满 \(months) 个月啦 🎊",
                            sub: "一个月又一个月的奇迹",
                            isSpecial: true)
        }
    }
    // Birthday anniversary (after first year)
    let b = cal.dateComponents([.month, .day], from: birth)
    let t = cal.dateComponents([.month, .day], from: today)
    if let y = comps.year, y >= 1, b.month == t.month, b.day == t.day {
        return Greeting(text: "\(baby.name) \(y) 岁啦 🎂", sub: "生日快乐呀", isSpecial: true)
    }

    // Regular day: daily random, seeded stably by day
    let seed = cal.ordinality(of: .day, in: .era, for: today) ?? days
    let phrase = dailyPhrases[abs(seed) % dailyPhrases.count]
    return Greeting(text: phrase, sub: nil, isSpecial: false)
}

// MARK: — Baby badge header card

private struct BabyBadge: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    var body: some View {
        Card(padding: 16) {
            HStack(spacing: 14) {
                Group {
                    if let data = store.baby.avatarData, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        BabyAvatar()
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.baby.ageLabel)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.52)
                        .foregroundStyle(store.theme.primary600)
                    Text(store.baby.name)
                        .font(.system(size: 22, weight: .black))
                        .tracking(-0.44)
                        .foregroundStyle(Palette.ink)
                    Text("出生 \(store.baby.birthLabel)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 0)
                Button { editing = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.7), in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .sheet(isPresented: $editing) {
            EditBabyScreen(onClose: { editing = false })
                .environment(store)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: 0xFFF5EE), Color(hex: 0xFFE8E0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
    }
}

private struct BabyAvatar: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xFFC7B5))
            Canvas { ctx, size in
                let s = size.width / 56
                func pt(_ x: Double, _ y: Double) -> CGPoint { .init(x: x * s, y: y * s) }
                ctx.fill(Path(ellipseIn: CGRect(x: 12*s, y: 10*s, width: 32*s, height: 32*s)),
                         with: .color(Color(hex: 0xFFE0D2)))
                // Hair tuft
                var hair = Path()
                hair.move(to: pt(20, 16))
                hair.addQuadCurve(to: pt(36, 16), control: pt(28, 10))
                ctx.stroke(hair, with: .color(Color(hex: 0x8B5A3C)),
                           style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
                // Eyes
                var e1 = Path(); e1.move(to: pt(22, 26)); e1.addQuadCurve(to: pt(26, 26), control: pt(24, 28))
                var e2 = Path(); e2.move(to: pt(30, 26)); e2.addQuadCurve(to: pt(34, 26), control: pt(32, 28))
                ctx.stroke(e1, with: .color(Color(hex: 0x2B2520)), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
                ctx.stroke(e2, with: .color(Color(hex: 0x2B2520)), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
                // Blush
                ctx.fill(Path(ellipseIn: CGRect(x: 20*s, y: 30*s, width: 4*s, height: 4*s)),
                         with: .color(Color(hex: 0xFF9B85).opacity(0.55)))
                ctx.fill(Path(ellipseIn: CGRect(x: 32*s, y: 30*s, width: 4*s, height: 4*s)),
                         with: .color(Color(hex: 0xFF9B85).opacity(0.55)))
                // Smile
                var smile = Path()
                smile.move(to: pt(25, 32))
                smile.addQuadCurve(to: pt(31, 32), control: pt(28, 34))
                ctx.stroke(smile, with: .color(Color(hex: 0x2B2520)),
                           style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
            }
        }
    }
}

// MARK: — Quick-action tile

private struct QuickTile: View {
    let kind: EventKind
    let onTap: () -> Void

    var body: some View {
        let style = CategoryStyle.forKind(kind, iconSize: 30)
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.55))
                        style.icon
                    }
                    .frame(width: 52, height: 52)
                    Text(style.label)
                        .font(.system(size: 17, weight: .heavy))
                        .tracking(-0.17)
                        .foregroundStyle(style.ink)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .aspectRatio(1.05, contentMode: .fit)

                // Plus badge
                ZStack {
                    Circle().fill(Color.white.opacity(0.6))
                    AppIcon.Plus(size: 16, color: style.ink)
                }
                .frame(width: 26, height: 26)
                .padding(14)
            }
            .background(style.tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: — Live sleep timer banner

private struct TimerBanner: View {
    let timer: RunningTimer
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let dur = timer.elapsed(at: ctx.date)
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.6))
                    AppIcon.Moon(size: 26, color: Palette.lavenderInk)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        PulseDot(color: Palette.lavenderInk)
                        Text("正在睡觉")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(0.72)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.lavenderInk)
                    }
                    Text(formatDur(dur))
                        .font(.system(size: 22, weight: .black))
                        .tracking(-0.44)
                        .monospacedDigit()
                        .foregroundStyle(Palette.lavenderInk)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Palette.lavender, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct PulseDot: View {
    let color: Color
    @State private var on: Bool = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(on ? 0.4 : 1.0)
            .scaleEffect(on ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

// MARK: — Daily summary strip (4 tinted pills)

private struct DailySummaryStrip: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let cal = Calendar.current
            let todays = store.events.filter { cal.isDateInToday($0.at) }
            let feed = todays.filter { $0.kind == .feed }.count
            let diaper = todays.filter { $0.kind == .diaper }.count
            let solid = todays.filter { $0.kind == .solid }.count
            let sleepSec: TimeInterval = todays
                .filter { $0.kind == .sleep }
                .compactMap(\.duration)
                .reduce(0, +) + (store.activeTimer.map { $0.elapsed(at: ctx.date) } ?? 0)

            HStack(spacing: 8) {
                SummaryCell(tint: Palette.lavender, ink: Palette.lavenderInk,
                            value: formatDurShort(sleepSec), label: "睡眠")
                SummaryCell(tint: Palette.pink, ink: Palette.pinkInk,
                            value: "\(feed)次", label: "喂奶")
                SummaryCell(tint: Palette.blue, ink: Palette.blueInk,
                            value: "\(diaper)次", label: "尿布")
                SummaryCell(tint: Palette.yellow, ink: Palette.yellowInk,
                            value: "\(solid)次", label: "辅食")
            }
        }
    }

    private struct SummaryCell: View {
        let tint: Color, ink: Color, value: String, label: String
        var body: some View {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .black))
                    .tracking(-0.32)
                    .monospacedDigit()
                    .foregroundStyle(ink)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ink.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10).padding(.horizontal, 6)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: — Since-last row (小字行)

private struct SinceLastRow: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let now = ctx.date
            let lastFeed   = store.events.filter { $0.kind == .feed   }.max(by: { $0.at < $1.at })
            let lastDiaper = store.events.filter { $0.kind == .diaper }.max(by: { $0.at < $1.at })
            let lastSleepEnd = store.activeTimer == nil
                ? store.events.filter { $0.kind == .sleep && $0.endAt != nil }.max(by: { ($0.endAt ?? .distantPast) < ($1.endAt ?? .distantPast) })
                : nil

            let items: [(String, String, Color)] = [
                lastFeed.map   { ("喂奶", fmt(now.timeIntervalSince($0.at)), Palette.pinkInk) },
                lastSleepEnd.map { ("睡眠", fmt(now.timeIntervalSince($0.endAt ?? now)), Palette.lavenderInk) },
                lastDiaper.map { ("尿布", fmt(now.timeIntervalSince($0.at)), Palette.blueInk) },
            ].compactMap { $0 }

            if !items.isEmpty {
                HStack(spacing: 10) {
                    Text("距上次")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                    ForEach(Array(items.enumerated()), id: \.offset) { (i, it) in
                        HStack(spacing: 4) {
                            Text(it.0).font(.system(size: 11, weight: .heavy)).foregroundStyle(it.2)
                            Text(it.1).font(.system(size: 11, weight: .bold)).monospacedDigit()
                            if i < items.count - 1 {
                                Text("·").opacity(0.4).padding(.leading, 6)
                            }
                        }
                    }
                }
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func fmt(_ s: TimeInterval) -> String {
        let sec = Int(max(0, s))
        let h = sec / 3600
        let m = (sec % 3600) / 60
        return h > 0 ? "\(h)时\(m)分" : "\(m)分"
    }
}

// MARK: — Vaccine reminder banner

private struct VaccineReminderBanner: View {
    @Environment(AppStore.self) private var store
    let onOpen: () -> Void

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let pending = store.vaccines.filter { !$0.done }
        let urgent = pending.filter { v in
            guard let d = v.scheduledDate else { return false }
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: d)).day ?? 0
            return days <= 15   // overdue (negative) or within half a month
        }
        let next = urgent.sorted {
            ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture)
        }.first

        if let v = next {
            let isOverdue = v.status() == .overdue
            let tint: Color = isOverdue ? Color(hex: 0xFFE8E0) : Palette.yellow
            let ink: Color = isOverdue ? Color(hex: 0xD44E3A) : Palette.yellowInk
            let kicker: String = isOverdue ? "已逾期" : "即将接种"

            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.6))
                        AppIcon.Syringe(size: 22, color: ink)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("疫苗提醒 · \(kicker)")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.66)
                            .textCase(.uppercase)
                            .foregroundStyle(ink)
                        Text(v.name)
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(-0.15)
                            .foregroundStyle(Palette.ink)
                        Text(reminderDetail(for: v))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                    AppIcon.Chevron(size: 16, color: Palette.ink3)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func reminderDetail(for v: Vaccine) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        if let d = v.scheduledDate {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: d)
            ).day ?? 0
            if days < 0 { return "\(v.ageLabel) · 计划 \(f.string(from: d))(已过 \(-days) 天)" }
            if days == 0 { return "\(v.ageLabel) · 就是今天" }
            return "\(v.ageLabel) · 还有 \(days) 天(\(f.string(from: d)))"
        }
        return v.ageLabel
    }
}

// MARK: — Edit baby profile sheet

private struct EditBabyScreen: View {
    @Environment(AppStore.self) private var store
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: BabyGender = .unspecified
    @State private var avatarData: Data? = nil
    @State private var pickerItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "编辑宝宝资料", onBack: onClose)

            ScreenBody {
                VStack(spacing: 18) {
                    avatarPicker
                        .padding(.top, 6)

                    FormField(label: "姓名") {
                        TextField("请输入宝宝姓名", text: $name)
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "出生日期")
                        DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "性别")
                        SegPill(selection: $gender, options: [
                            (.girl, "女宝"),
                            (.boy, "男宝"),
                            (.unspecified, "未设置"),
                        ])
                    }

                    CTAButton(title: "保存", theme: store.theme) {
                        var b = store.baby
                        b.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? b.name : name
                        b.birthDate = birthDate
                        b.gender = gender
                        b.avatarData = avatarData
                        store.baby = b
                        store.persist()
                        onClose()
                    }
                    .padding(.top, 6)
                }
            }
        }
        .background(Palette.bg)
        .onAppear {
            name = store.baby.name
            birthDate = store.baby.birthDate
            gender = store.baby.gender
            avatarData = store.baby.avatarData
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    avatarData = data
                }
            }
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let data = avatarData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else {
                            BabyAvatar()
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadowCard()

                    ZStack {
                        Circle().fill(store.theme.primary)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 30, height: 30)
                }
                Text("点击更换头像")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview("首页") {
    HomeView(onOpen: { _ in })
        .environment(AppStore.preview)
}
