import SwiftUI
import UIKit
import UserNotifications
import AppIntents

@main
struct BabyDiaryApp: App {
    @UIApplicationDelegateAdaptor(BabyDiaryAppDelegate.self) private var appDelegate
    @State private var store = AppStore.loadedOrSeeded()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(store.theme.primary600)
                .preferredColorScheme(.light)
        }
    }
}

final class BabyDiaryAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let destination = response.notification.request.content.userInfo["destination"] as? String else { return }
        await MainActor.run {
            NotificationCenter.default.post(
                name: .babyDiaryNotificationDestination,
                object: nil,
                userInfo: ["destination": destination]
            )
        }
    }
}

struct StartFeedingIntent: AppIntent {
    static var title: LocalizedStringResource = "开始喂奶"
    static var description = IntentDescription("开始一次母乳喂奶计时。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = BabyDiaryShortcutCoordinator.startFeeding()
        let dialog: IntentDialog = status == .started ? "已开始喂奶" : "已经在喂奶"
        return .result(dialog: dialog)
    }
}

struct LogFormulaIntent: AppIntent {
    static var title: LocalizedStringResource = "记录奶粉"
    static var description = IntentDescription("直接记录一次奶粉喂奶，不开始计时。")
    static var openAppWhenRun = false

    @Parameter(title: "奶量（ml）")
    var milliliters: Int?

    init() {
        self.milliliters = nil
    }

    init(milliliters: Int?) {
        self.milliliters = milliliters
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let event = BabyDiaryShortcutCoordinator.recordFormula(milliliters: milliliters)
        return .result(dialog: "已记录\(event.title) \(event.sub ?? "")")
    }
}

struct StartSleepingIntent: AppIntent {
    static var title: LocalizedStringResource = "开始睡觉"
    static var description = IntentDescription("开始一次睡眠计时。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = BabyDiaryShortcutCoordinator.startSleeping()
        let dialog: IntentDialog = status == .started ? "已开始睡觉" : "已经在睡觉"
        return .result(dialog: dialog)
    }
}

enum ShortcutDiaperType: String, AppEnum {
    case wet
    case dirty
    case both

    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "尿布类型",
        synonyms: ["尿布", "换尿布"]
    )

    static var caseDisplayRepresentations: [ShortcutDiaperType: DisplayRepresentation] = [
        .wet: .init(title: "嘘嘘", synonyms: ["尿尿", "小便", "湿尿布"]),
        .dirty: .init(title: "臭臭", synonyms: ["便便", "大便", "拉臭臭"]),
        .both: .init(title: "嘘嘘和臭臭", synonyms: ["都有", "尿尿和臭臭", "大小便"])
    ]

    var diaperEventType: DiaperEventType {
        switch self {
        case .wet: return .wet
        case .dirty: return .dirty
        case .both: return .both
        }
    }
}

struct LogDiaperIntent: AppIntent {
    static var title: LocalizedStringResource = "记录换尿布"
    static var description = IntentDescription("直接记录一次换尿布。")
    static var openAppWhenRun = false

    @Parameter(title: "类型", default: .wet)
    var type: ShortcutDiaperType

    init() {
        self.type = .wet
    }

    init(type: ShortcutDiaperType) {
        self.type = type
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let event = BabyDiaryShortcutCoordinator.recordDiaper(type: type.diaperEventType)
        return .result(dialog: "已记录\(event.title)")
    }
}

struct BabyDiaryAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFeedingIntent(),
            phrases: [
                "用 \(.applicationName) 我要喂奶",
                "用 \(.applicationName) 开始喂奶",
                "在 \(.applicationName) 记录喂奶",
                "\(.applicationName) 我要喂奶"
            ],
            shortTitle: "开始喂奶",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: LogFormulaIntent(),
            phrases: [
                "用 \(.applicationName) 记录奶粉",
                "用 \(.applicationName) 直接记录奶粉",
                "用 \(.applicationName) 宝宝喝奶粉了",
                "在 \(.applicationName) 记录奶粉",
                "\(.applicationName) 记录奶粉"
            ],
            shortTitle: "记录奶粉",
            systemImageName: "waterbottle.fill"
        )

        AppShortcut(
            intent: StartSleepingIntent(),
            phrases: [
                "用 \(.applicationName) 开始睡觉",
                "用 \(.applicationName) 宝宝开始睡觉",
                "在 \(.applicationName) 记录睡觉",
                "\(.applicationName) 开始睡觉"
            ],
            shortTitle: "开始睡觉",
            systemImageName: "moon.fill"
        )

        AppShortcut(
            intent: LogDiaperIntent(),
            phrases: [
                "用 \(.applicationName) 帮我记一个换尿布",
                "用 \(.applicationName) 记录换尿布",
                "用 \(.applicationName) 宝宝换尿布了",
                "在 \(.applicationName) 记录换尿布",
                "\(.applicationName) 帮我记一个换尿布",
                "\(.applicationName) 记录 \(\.$type)"
            ],
            shortTitle: "记录换尿布",
            systemImageName: "drop.triangle.fill"
        )
    }
}

@MainActor
enum BabyDiaryShortcutCoordinator {
    private static let pendingDestinationKey = "BabyDiary.shortcutDestination"
    private static weak var activeStore: AppStore?

    static func register(_ store: AppStore) {
        activeStore = store
    }

    static func startFeeding(at date: Date = Date()) -> ShortcutStartStatus {
        let target = activeStore ?? AppStore.loadedOrSeeded()
        let status = target.startFeedFromShortcut(at: date)
        requestOpen(.feed)
        return status
    }

    static func recordFormula(milliliters: Int? = nil, at date: Date = Date()) -> Event {
        let target = activeStore ?? AppStore.loadedOrSeeded()
        return target.recordFormulaFromShortcut(milliliters: milliliters, at: date)
    }

    static func startSleeping(at date: Date = Date()) -> ShortcutStartStatus {
        let target = activeStore ?? AppStore.loadedOrSeeded()
        let status = target.startSleepFromShortcut(at: date)
        requestOpen(.sleep)
        return status
    }

    static func recordDiaper(type: DiaperEventType = .wet, at date: Date = Date()) -> Event {
        let target = activeStore ?? AppStore.loadedOrSeeded()
        return target.recordDiaperFromShortcut(type: type, at: date)
    }

    static func consumePendingDestination() -> BabyDiaryDestination? {
        guard let rawValue = UserDefaults.standard.string(forKey: pendingDestinationKey) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: pendingDestinationKey)
        return BabyDiaryDestination(rawValue: rawValue)
    }

    private static func requestOpen(_ destination: BabyDiaryDestination) {
        UserDefaults.standard.set(destination.rawValue, forKey: pendingDestinationKey)
        NotificationCenter.default.post(
            name: .babyDiaryShortcutDestination,
            object: nil,
            userInfo: ["destination": destination.rawValue]
        )
    }
}
