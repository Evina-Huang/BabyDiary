# BabyDiary 宝宝日记

BabyDiary 是一个 iOS 宝宝照护记录 App。它想做的事情很简单：把喂奶、睡眠、尿布、辅食、成长、疫苗、用药这些每天都会发生的小事，稳稳地接住，整理成一份随时能看的宝宝日记。

它不是给“完美记录”用的。它更像是照顾宝宝时放在手边的小伙伴：打开就能记，过一会儿能回来看，去医院或换设备前也能把重要信息带走。

> 当前界面文案以中文为主，项目面向 iOS 18+，使用 SwiftUI 开发。

---

## 目录

- [项目亮点](#项目亮点)
- [适合谁使用](#适合谁使用)
- [主要功能](#主要功能)
- [数据与隐私](#数据与隐私)
- [运行项目](#运行项目)
- [测试](#测试)
- [项目结构](#项目结构)
- [开发说明](#开发说明)
- [当前限制](#当前限制)
- [English Version](#english-version)

---

## 项目亮点

- **中文优先的照护体验**：从页面文案到记录内容，都更贴近日常中文使用场景。
- **日常记录很快**：喂奶、睡眠、尿布、辅食都能快速记录，记录完成后回到主页面，减少重复操作。
- **能看到“现在正在发生什么”**：睡眠和喂奶进行中时，App 内会有悬浮状态；睡眠和喂奶也支持 Live Activity。
- **能回看“刚刚发生过什么”**：小组件可以查看上一次喂奶、睡眠、尿布，也可以配置显示内容。
- **成长和健康放在一起看**：成长曲线、出牙、里程碑、疫苗、用药、辅食过敏都在同一个 App 里。
- **本地自动保存**：新增、修改、删除后会立即保存到当前设备。
- **可导出备份与报告**：支持 JSON 备份导出/导入，也支持 PDF 报告导出，方便换机、重装或就医时查看。
- **默认适合真实使用**：普通启动不会灌入大批演示数据，避免把测试内容和真实记录混在一起。

---

## 适合谁使用

BabyDiary 适合：

- 想记录宝宝日常照护，但不想用复杂表格的人。
- 需要和家人同步“上次什么时候喂奶 / 睡了多久 / 有没有拉臭臭”的照护者。
- 想把疫苗、用药、辅食过敏、成长数据集中保存的人。
- 希望数据先留在自己设备上，而不是默认上传到云端的人。
- 想在 iPhone 上自己安装、自己使用的小型个人 App 使用者。

它不适合：

- 需要多人实时云同步的家庭协作场景。
- 需要医生级诊断、医疗建议或正式病历系统的场景。
- 需要 Android、网页端或跨平台版本的场景。

---

## 主要功能

### 1. 首页：今天的照护仪表盘

首页是打开 App 后最常看的地方，重点回答三个问题：

- 宝宝今天怎么样？
- 最近一次记录是什么时候？
- 现在有没有正在进行的事情？

首页包含：

- 宝宝资料卡片。
- 睡眠、喂奶、尿布、辅食四个快捷入口。
- 今日统计摘要。
- 今日奶粉总量。
- 距上次记录的提醒。
- 疫苗提醒。
- 数据备份入口。
- 进行中的睡眠或喂奶状态浮层。

### 2. 喂奶记录

喂奶支持母乳和奶粉两类记录：

- 母乳可记录左右侧时长。
- 奶粉可记录毫升数。
- 支持正在进行中的喂奶状态。
- 首页和记录页会统计喂奶次数。
- 奶粉总量会在首页和记录页展示。
- 小组件可显示最近一次喂奶。
- Live Activity 可显示正在进行的喂奶。

### 3. 睡眠记录

睡眠记录支持：

- 开始、暂停、继续、结束计时。
- 手动记录睡眠时间段。
- 首页显示正在睡觉状态。
- 睡眠会计入当天统计。
- 跨天睡眠会按当天实际覆盖时长计算。
- Live Activity 可在锁屏和 Dynamic Island 展示正在进行的睡眠。
- 小组件可显示最近一次睡眠或睡眠计时。

### 4. 尿布记录

尿布记录支持：

- 嘘嘘。
- 臭臭。
- 嘘嘘 + 臭臭。
- 备注选项，例如奶瓣、稀便等。
- 自定义备注。
- 编辑已有记录。

这一块的目标是把“需要临时记一下、下次医生问得上”的信息记住，而不是把照护者困在复杂表单里。

### 5. 辅食与过敏

辅食支持两条线：

- 在日常记录里记录一次辅食。
- 在食物清单里管理食物状态。

食物状态包括：

- 观察中。
- 已排敏 / 安全。
- 疑似过敏。

它适合记录“第一次吃了什么”“吃了几次”“观察期到了没有”“有没有异常反应”这类非常生活化但又很重要的信息。

### 6. 成长记录

成长页包含：

- 身高。
- 体重。
- 头围。
- 月龄自动计算。
- 成长曲线。
- 历史测量记录。
- 近 30 天、近 90 天、近 1 年等筛选。
- 出牙记录。
- 成长里程碑。

成长页不是只放数字，它也保留“宝宝正在长大”的感觉：曲线看趋势，里程碑留瞬间。

### 7. 健康模块

健康模块集中展示：

- 最新测量摘要。
- 疫苗接种计划。
- 用药记录。
- 食物与过敏入口。

用药记录支持：

- 药名。
- 服用时间。
- 剂量。
- 用药原因。
- 观察中 / 无异常 / 疑似过敏。
- 过敏或反应备注。
- 普通备注。

这部分很适合就医前快速回看：吃过什么药、什么时候吃的、有没有异常反应。

> 提醒：BabyDiary 只是记录工具，不提供医疗建议。疫苗、用药和过敏相关判断请以医生建议为准。

### 8. 记录页

记录页用于回看完整时间线：

- 按日期查看记录。
- 按天分组。
- 每天显示简短统计。
- 支持编辑和删除已有日常记录。
- 支持查看喂奶、睡眠、尿布、辅食等事件。

它适合回答“昨天到底发生了什么”“这一周是不是睡得更规律了”这种真实照护里经常冒出来的问题。

### 9. 统计页

统计页关注“时间规律”：

- 支持近 7 / 14 / 30 天视图。
- 睡眠用时间区间展示。
- 喂奶、尿布、辅食用时间点展示。
- 可按记录类型筛选。

它不是复杂报表，更像一张宝宝节奏地图：什么时候容易睡、什么时候常喂奶、哪段时间照护最密集。

### 10. 小组件与 Live Activity

当前包含：

- 可配置的小组件。
- 最近一次喂奶。
- 最近一次睡眠。
- 最近一次尿布。
- 正在进行的睡眠计时。
- 正在进行的喂奶计时。
- 睡眠 Live Activity。
- 喂奶 Live Activity。
- `babydiary://` 深链接回到对应页面。

设计思路是：

- **锁屏 / Dynamic Island**：显示当下正在进行的事情。
- **小组件**：显示最近发生过的事情。

这样能避免把“正在进行”和“刚刚完成”混成一团。

### 11. 备份与导出

备份页支持：

- 查看当前数据数量。
- 查看自动保存状态。
- 查看最近保存时间。
- 导出 JSON 备份。
- 从 JSON 备份恢复。
- 导出 PDF 报告。

JSON 适合恢复数据；PDF 适合阅读、分享或就医时查看。

导入 JSON 时会覆盖当前数据。这个行为更接近“恢复备份”，不是“合并两份记录”。

---

## 数据与隐私

BabyDiary 当前是本地优先的单机 App：

- 数据自动保存在当前设备的 App 本地空间。
- 不默认上传到云端。
- 不包含服务器同步。
- 不包含账号系统。
- 导出的 JSON 文件可以用于备份和恢复。
- 导出的 PDF 文件适合阅读和分享。

自动保存文件不会直接出现在 iOS「文件」App 里。需要迁移设备、重装 App 或额外留底时，请在 App 内导出 JSON 备份。

---

## 运行项目

### 环境要求

- macOS。
- Xcode 16 或更新版本。
- iOS 18 模拟器或真机。
- XcodeGen。

如果没有安装 XcodeGen，可以使用 Homebrew 安装：

```bash
brew install xcodegen
```

### 生成 Xcode 项目

项目的 Xcode 工程由 `project.yml` 生成。如果修改了 `project.yml`，或者新增了需要进入工程的源码文件，请重新生成：

```bash
xcodegen generate
```

### 使用 Xcode 打开

```bash
open BabyDiary.xcodeproj
```

然后选择 `BabyDiary` scheme，运行到 iOS 18 模拟器或真机。

### 命令行构建

```bash
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 真机运行说明

真机运行通常需要在 Xcode 中选择可用的签名 Team。如果本地 Xcode 报签名错误，可以把项目里的 Team 改成自己的 Apple ID 对应 Team。

这个项目是个人使用型 App，不需要上架 App Store 才能本地运行。

---

## 测试

运行完整测试：

```bash
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

当前测试使用 Swift Testing，测试文件位于：

```text
BabyDiaryTests/BabyDiaryTests.swift
```

测试覆盖方向包括：

- 基础事件创建。
- 默认启动为空数据。
- 演示数据只在指定模式下生成。
- 今日示例记录合并。
- 删除与更新事件。
- 最近记录排序。
- 喂奶结束时间判断。
- 母乳左右侧记录。
- 每日统计。
- 尿布备注。
- 辅食记录与食物清单联动。
- 成长月龄重算。
- 宝宝生日变更后的派生数据刷新。
- 疫苗模板去重。
- 用药记录排序。
- 备份快照包含用药记录。
- 睡眠计时暂停与继续。
- 跨天睡眠统计。
- 喂奶草稿默认值。
- 旧备份兼容。

---

## 项目结构

```text
BabyDiary
├── BabyDiary/
│   ├── Sources/
│   │   ├── App/          # App 入口、全局状态、备份、Live Activity 控制
│   │   ├── Components/   # 通用 UI 组件与图标
│   │   ├── Models/       # 日常记录、疫苗、成长、用药、辅食等数据模型
│   │   ├── Shared/       # App 与 Widget 共用的数据结构
│   │   └── Views/        # 首页、记录、成长、健康、统计和各类记录页面
│   └── Resources/        # Info.plist 与 App 图标资源
├── BabyDiaryWidgets/     # Widget 与 Live Activity 扩展
├── BabyDiaryTests/       # Swift Testing 测试
├── project.yml           # XcodeGen 工程配置
└── README.md
```

---

## 开发说明

### 技术栈

- SwiftUI。
- Observation。
- WidgetKit。
- ActivityKit。
- AppIntents。
- Charts。
- Codable JSON。
- UIKit PDF rendering。
- Swift Testing。
- XcodeGen。

### 状态管理

App 使用一个全局 `AppStore` 管理主要数据：

- 宝宝资料。
- 日常事件。
- 疫苗。
- 成长测量。
- 辅食。
- 用药。
- 出牙。
- 里程碑。
- 主题。
- 进行中的计时。
- 喂奶草稿。

视图通过环境读取同一个 store。新增、编辑、删除后会触发本地保存。

### 工程管理

`BabyDiary.xcodeproj` 是生成结果，源头是 `project.yml`。涉及 target、扩展、资源或文件加入方式的改动，请优先改 `project.yml`，再运行：

```bash
xcodegen generate
```

### 设计风格

这个 App 的视觉方向是轻、暖、清楚：

- 主界面以卡片和柔和色彩为主。
- 图标大多是项目内自绘风格。
- 页面重点是快速记录和轻松回看。
- 不追求复杂后台系统感。
- 中文文案应保持自然、短、可直接理解。

### 数据模型选择

日常照护记录主要使用统一的 `Event`：

- 喂奶。
- 睡眠。
- 尿布。
- 辅食。

健康和成长相关数据使用独立模型：

- `Vaccine`
- `GrowthPoint`
- `FoodItem`
- `MedicationRecord`
- `ToothRecord`
- `Milestone`

这个分法让“时间线记录”和“长期档案”保持清晰。

---

## 当前限制

- 目前没有账号系统。
- 目前没有多人实时同步。
- 目前没有云端备份。
- 目前没有 Android 或 Web 版本。
- PDF 导出是阅读型报告，不是正式医疗文书。
- 疫苗、用药、过敏信息只作为记录，不作为医学判断依据。

---

## 后续可以继续增强

- iCloud 同步。
- 家庭成员共享。
- 更多统计图表。
- 医院就诊摘要模板。
- 更完整的成长标准参考。
- 记录搜索。
- 照片附件。
- 更细的权限与隐私说明。

---

# English Version

## BabyDiary

BabyDiary is an iOS baby-care journal app. It helps caregivers record feeding, sleep, diapers, solids, growth, vaccines, medication, and allergy-related notes in one calm and friendly place.

The goal is not to create a perfect spreadsheet. The goal is to make daily care easier to remember, easier to review, and easier to share when needed.

The app is currently Chinese-first and built for iOS 18+ with SwiftUI.

---

## Highlights

- **Chinese-first experience** for real daily baby-care scenarios.
- **Fast daily logging** for feeding, sleep, diapers, and solids.
- **Active state tracking** for ongoing sleep and feeding.
- **Widgets** for recent feeding, sleep, diapers, and active timers.
- **Live Activities** for ongoing sleep and feeding.
- **Growth and health records** including measurements, teeth, milestones, vaccines, medication, and food allergy status.
- **Local autosave** after every add, edit, or delete.
- **JSON backup and restore** for moving or recovering data.
- **PDF export** for easy reading and sharing.
- **Real-use default startup** without filling the app with demo data.

---

## Who This Is For

BabyDiary is useful for:

- Caregivers who want a simple way to record daily baby care.
- Families who need to know the latest feeding, sleep, diaper, or solid-food record.
- Parents who want vaccines, medication, food allergy notes, and growth data in one app.
- Users who prefer local-first data instead of cloud-first storage.
- Personal-use iPhone app workflows.

It is not designed for:

- Real-time multi-user cloud collaboration.
- Medical diagnosis or professional medical records.
- Android, web, or cross-platform use.

---

## Main Features

### Home

The Home screen gives a quick view of today:

- Baby profile.
- Quick entry cards for sleep, feeding, diapers, and solids.
- Today summary.
- Formula milk total.
- Time since last record.
- Vaccine reminder.
- Backup entry.
- Floating active sleep or feeding status.

### Feeding

Feeding supports:

- Breastfeeding duration by side.
- Formula milk amount in milliliters.
- Active feeding state.
- Daily feeding count.
- Formula total on Home and Records.
- Recent feeding widget.
- Feeding Live Activity.

### Sleep

Sleep supports:

- Start, pause, resume, and stop timer.
- Manual sleep time range.
- Active sleep state on Home.
- Daily sleep summary.
- Cross-day sleep duration calculation.
- Sleep Live Activity.
- Sleep widget module.

### Diapers

Diaper records support:

- Wet diaper.
- Dirty diaper.
- Wet + dirty.
- Preset notes such as milk curds or loose stool.
- Custom notes.
- Editing existing records.

### Solids and Food Allergy

Solids and food tracking include:

- Solid-food daily records.
- Food list management.
- Observation status.
- Safe / cleared status.
- Suspected allergy status.
- First-use date and eating count.

### Growth

Growth includes:

- Weight.
- Height.
- Head circumference.
- Automatic age-in-months calculation.
- Growth chart.
- Measurement history.
- Time filters.
- Teeth records.
- Milestones.

### Health

Health includes:

- Latest measurement summary.
- Vaccine plan and completion status.
- Medication records.
- Food and allergy entry.

Medication records include:

- Medicine name.
- Taken time.
- Dose.
- Reason.
- Observing / no issue / suspected allergy.
- Reaction note.
- General note.

BabyDiary is a record-keeping app only. It does not provide medical advice. Please follow professional medical guidance for vaccines, medication, and allergy decisions.

### Records

Records provides:

- Full timeline.
- Date filtering.
- Grouping by day.
- Compact daily summary.
- Editing and deleting daily records.

### Stats

Stats focuses on daily rhythm:

- 7 / 14 / 30 day views.
- Sleep ranges.
- Feeding, diaper, and solid-food points.
- Filtering by record type.

### Widgets and Live Activities

Current extension features include:

- Configurable widget modules.
- Last feeding.
- Last sleep.
- Last diaper.
- Active sleep timer.
- Active feeding timer.
- Sleep Live Activity.
- Feeding Live Activity.
- `babydiary://` deep links.

Design intent:

- **Lock Screen / Dynamic Island** shows what is happening right now.
- **Widgets** show what happened most recently.

---

## Data and Privacy

BabyDiary is local-first:

- Data is stored in the app's local space on the current device.
- There is no default cloud upload.
- There is no server sync.
- There is no account system.
- JSON export can be used for backup and restore.
- PDF export can be used for reading and sharing.

Autosaved files do not directly appear in the iOS Files app. Use JSON export before switching devices, reinstalling the app, or keeping an extra backup.

---

## Running the Project

### Requirements

- macOS.
- Xcode 16 or newer.
- iOS 18 simulator or device.
- XcodeGen.

Install XcodeGen with Homebrew if needed:

```bash
brew install xcodegen
```

### Generate the Xcode Project

The Xcode project is generated from `project.yml`:

```bash
xcodegen generate
```

### Open in Xcode

```bash
open BabyDiary.xcodeproj
```

Select the `BabyDiary` scheme and run it on an iOS 18 simulator or device.

### Command Line Build

```bash
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

For physical devices, choose an available signing Team in Xcode if signing fails.

---

## Tests

Run the full test suite:

```bash
xcodebuild -project BabyDiary.xcodeproj -scheme BabyDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Tests use Swift Testing and live in:

```text
BabyDiaryTests/BabyDiaryTests.swift
```

Covered areas include event creation, empty default startup, demo data mode, event updates, daily summaries, diaper notes, solid-food syncing, growth recalculation, vaccine behavior, medication snapshots, sleep timers, cross-day sleep, feeding draft defaults, and legacy backup compatibility.

---

## Project Structure

```text
BabyDiary
├── BabyDiary/
│   ├── Sources/
│   │   ├── App/          # App entry, global state, backup, Live Activity control
│   │   ├── Components/   # Shared UI components and icons
│   │   ├── Models/       # Event, vaccine, growth, medication, food, teeth, milestone models
│   │   ├── Shared/       # Shared app/widget data structures
│   │   └── Views/        # Main screens and entry screens
│   └── Resources/        # Info.plist and app assets
├── BabyDiaryWidgets/     # Widgets and Live Activities
├── BabyDiaryTests/       # Swift Testing tests
├── project.yml           # XcodeGen project definition
└── README.md
```

---

## Development Notes

### Stack

- SwiftUI
- Observation
- WidgetKit
- ActivityKit
- AppIntents
- Charts
- Codable JSON
- UIKit PDF rendering
- Swift Testing
- XcodeGen

### State

The app uses a single `AppStore` for core app data, including baby profile, daily events, vaccines, growth measurements, food records, medication records, teeth, milestones, theme, active timers, and feeding drafts.

### Project Generation

`BabyDiary.xcodeproj` is generated from `project.yml`. For target, extension, resource, or source membership changes, update `project.yml` and run:

```bash
xcodegen generate
```

### Data Model Direction

Daily care uses the shared `Event` model:

- Feeding.
- Sleep.
- Diaper.
- Solids.

Longer-term health and growth records use separate models:

- `Vaccine`
- `GrowthPoint`
- `FoodItem`
- `MedicationRecord`
- `ToothRecord`
- `Milestone`

This keeps the timeline and long-term records cleanly separated.

---

## Current Limitations

- No account system.
- No real-time family sharing.
- No cloud backup.
- No Android or web version.
- PDF export is a readable report, not a formal medical document.
- Vaccine, medication, and allergy data are records only, not medical guidance.

---

## Future Ideas

- iCloud sync.
- Family sharing.
- More charts.
- Doctor-visit summary templates.
- More complete growth references.
- Record search.
- Photo attachments.
- More detailed privacy documentation.
