# BabyDiary 项目概览

本文档基于当前仓库代码整理，目的是帮助后续开发快速建立项目心智模型。若与 `AGENTS.md` 有冲突，以当前代码实现为准。

## 1. 项目现状

- 平台：iOS only
- 技术栈：SwiftUI + Observation（`@Observable`）
- 工程管理：`project.yml` + XcodeGen
- 本地化风格：界面文案以中文为主
- 数据状态：当前已不是纯内存 demo，而是带本地 JSON 持久化、导入、导出能力的单机应用

## 2. 入口与全局状态

应用入口在 `BabyDiary/Sources/App/BabyDiaryApp.swift`。

- 启动时通过 `AppStore.loadedOrSeeded()` 创建全局 store
- 再通过 `.environment(store)` 注入整个视图树
- 全局 tint 颜色来自 `store.theme.primary600`

`AppStore` 位于 `BabyDiary/Sources/App/AppStore.swift`，是整个应用的单一状态中心。当前主要状态包括：

- `baby`
- `events`
- `vaccines`
- `growth`
- `foods`
- `teeth`
- `milestones`
- `theme`
- `activeTimer`

当前架构仍然遵循“单一 store 驱动 UI”的思路，大多数数据写操作也集中在 `AppStore` 中，例如：

- `addEvent` / `deleteEvent` / `updateEvent`
- `addGrowth` / `updateGrowth`
- `addVaccineFromTemplate` / `updateVaccine` / `toggleVaccine`
- `addMilestone` / `updateMilestone` / `deleteMilestone`
- `setTooth`
- `recordSolidFood` / `updateFoodStatus` / `renameFood` / `deleteFood`

## 3. 当前和 AGENTS.md 的差异

`AGENTS.md` 的主体方向仍然有参考价值，但以下信息已经过时：

### 3.1 数据并非只存在内存

当前代码已支持本地持久化，相关逻辑在 `BabyDiary/Sources/App/Backup.swift`：

- `loadFromDisk()`
- `persist()`
- `exportJSON()`
- `importJSON(from:)`
- `exportPDF()`

应用启动流程实际是：

1. `AppStore.init()` 先执行 `seed()`
2. `loadedOrSeeded()` 再尝试从磁盘读取 `BabyDiary.json`
3. 如果读取成功，则用磁盘数据覆盖 seed 数据

### 3.2 功能范围已扩大

仓库已不只包含喂奶、尿布、睡眠、辅食、疫苗、成长，还新增了：

- 健康总览页
- 食物清单页
- 长牙记录
- 里程碑记录
- 数据备份与恢复
- 事件编辑 Sheet
- 成长点编辑 Sheet

### 3.3 “页面不要直接改 store 字段” 不是完全成立

多数页面仍通过 `AppStore` 方法改数据，但已经存在少量直接赋值的情况，例如首页编辑宝宝资料时会直接更新 `store.baby`，然后手动调用 `store.persist()`。

这说明当前约定更接近：

- 业务列表数据优先通过 store 方法修改
- 个别聚合对象仍可能由页面直接赋值并手动持久化

## 4. 主要导航结构

根视图在 `BabyDiary/Sources/App/ContentView.swift`。

主导航不是 `TabView`，而是自定义 tab bar。当前主 tab 包括：

- `home`
- `records`
- `growth`
- `health`
- `stats`

次级页面通过 `SubScreen` 以 sheet 方式弹出，目前包括：

- `sleep`
- `feed`
- `diaper`
- `solid`
- `vaccine`
- `foodList`
- `teeth`
- `backup`

整体模式是：

- 主 tab 负责一级信息架构
- 记录类操作用 modal sheet 进入
- sheet 关闭后回到原 tab 上下文

## 5. 主要页面职责

### 5.1 首页 `HomeView`

首页更像仪表盘，包含：

- 日期和问候语
- 宝宝资料卡片
- 四个快捷记录入口：睡眠、喂奶、尿布、辅食
- 正在进行中的计时 banner
- 距上次记录时间
- 今日汇总
- 疫苗提醒
- 右上角备份入口

这里承担了“快速进入操作”和“查看今天状态”的职责。

### 5.2 记录页 `RecordsView`

记录页负责：

- 查看全部事件
- 按日期筛选
- 按天分组展示时间线
- 打开 `EventEditSheet` 编辑或删除事件

它是事件流的总入口。

### 5.3 成长页 `GrowthView`

成长页已经不是单一“身高体重”页，而是三段式结构：

- `measure`：身高体重曲线、历史记录、测量点编辑
- `teeth`：出牙记录
- `milestones`：成长里程碑

其中图表使用 `Charts`，并带一个近似 WHO 参考区间的展示逻辑。这个页面当前是成长相关能力的中心模块。

### 5.4 健康页 `HealthView`

健康页更像二级导航汇总，主要展示：

- 最新测量摘要
- 疫苗接种入口与进度摘要
- 食物与过敏入口与摘要

### 5.5 统计页 `StatsView`

统计页展示最近 7 / 14 / 30 天的“时间规律”图：

- 横轴是天
- 纵轴是 24 小时
- 睡眠以条状区间显示
- 喂奶、尿布、辅食以点状落位显示
- 支持按事件类型过滤

这个页面偏“节律观察”，不是传统报表型统计。

## 6. 记录类功能的建模方式

### 6.1 `Event` 仍然是核心通用记录模型

定义位于 `BabyDiary/Sources/Models/Event.swift`。

支持的 `EventKind`：

- `feed`
- `diaper`
- `sleep`
- `solid`

`Event` 主要字段：

- `id`
- `kind`
- `at`
- `endAt`
- `title`
- `sub`

这意味着当前产品虽然页面功能丰富，但日常记录主线仍然落回统一事件流。

### 6.2 健康扩展数据独立建模

以下数据没有塞进 `Event`，而是独立建模：

- 疫苗：`Vaccine`
- 辅食清单：`FoodItem`
- 出牙：`ToothRecord`
- 里程碑：`Milestone`
- 成长测量：`GrowthPoint`

因此项目现在实际上是“双轨”：

- 一条是统一的 `Event` 时间线
- 一条是若干专题模型的独立模块

## 7. 持久化与备份机制

### 7.1 本地存储

当前通过 `Codable` + JSON 文件做本地存储。

- 文件名：`BabyDiary.json`
- 存储位置：Documents 目录
- 编码策略：`ISO8601` 日期编码

快照结构为 `DataSnapshot`，包含：

- `baby`
- `events`
- `vaccines`
- `growth`
- `foods`
- `teeth`
- `milestones`

### 7.2 导出能力

目前支持两种导出：

- JSON 备份：可重新导入恢复
- PDF 报告：面向阅读和分享

PDF 渲染逻辑同样在 `Backup.swift` 中，包含封面、成长、疫苗、辅食、日常记录几个 section。

### 7.3 导入行为

从 JSON 导入时会直接覆盖当前数据，因此这是“恢复备份”语义，不是“合并导入”语义。

### 7.4 当前限制

`activeTimer` 不在 `DataSnapshot` 里，因此进行中的计时不会被持久化。应用被杀掉后，计时状态大概率丢失。

## 8. UI 组织方式

### 8.1 共享组件

通用组件主要在 `BabyDiary/Sources/Components/Primitives.swift`，包括：

- `ScreenHeader`
- `ScreenBody`
- `Card`
- `CTAButton`
- `SegPill`
- `FormField`
- `EventRow`
- `SinceLastBanner`
- `EmptyStateView`

这套组件已经形成比较统一的页面骨架：

- 顶部 header
- 中部滚动内容
- 卡片化信息块
- 强视觉主按钮

### 8.2 图标系统

`BabyDiary/Sources/Components/Icons.swift` 中保留了大量自绘 `Canvas` 图标，而不是完全依赖 SF Symbols。

这说明这个项目比较重视视觉一致性，后续如果补 UI，优先应该复用现有 icon 风格，而不是直接换成系统图标。

### 8.3 主题

主题来源于 `store.theme` 和 `Palette.*`。当前代码仍然遵循“不硬编码主要品牌色”的大方向，样式统一性比较好。

## 9. 测试现状

测试文件在 `BabyDiaryTests/BabyDiaryTests.swift`，使用 Swift Testing。

当前只有很轻量的 3 个测试：

- `eventCreation`
- `storeSeedsData`
- `deleteEventRemovesIt`

它们只覆盖：

- 基础模型创建
- store 初始 seed
- 删除事件

目前还没有覆盖：

- 持久化读写
- 导入导出
- 疫苗排序和状态
- 食物观察期逻辑
- 出牙与里程碑编辑
- 事件编辑 Sheet 的结构化重建逻辑

## 10. 我建议后续开发优先记住的几点

- 这是一个“单一 store 驱动”的 SwiftUI 应用，理解 `AppStore` 比理解任一页面都重要。
- 当前代码已经从 demo 演进成“有本地持久化的个人记录应用”，不要再按纯内存假设改逻辑。
- `Event` 是日常记录主线，但健康相关能力已经拆成多个专题模型，新增功能时要先判断应不应该落到 `Event`。
- 页面视觉有比较明确的既有语言，新增 UI 应优先复用 `Card`、`SegPill`、`CTAButton`、`AppIcon` 和 `Palette`。
- 如果要做稳定性提升，优先补测试的方向应该是持久化、导入导出、专题模型状态流转，而不是只补纯展示页面。

## 11. 一个简化心智图

可以把当前项目理解为下面这层结构：

1. `BabyDiaryApp`
2. `AppStore`
3. `ContentView`
4. 主 tab：首页 / 记录 / 成长 / 健康 / 统计
5. 子页面：睡眠 / 喂奶 / 尿布 / 辅食 / 疫苗 / 食物清单 / 长牙 / 备份
6. 数据落点：`Event` + `Vaccine` + `GrowthPoint` + `FoodItem` + `ToothRecord` + `Milestone`
7. 存储：本地 JSON + JSON/PDF 导入导出

---

如果后续要继续维护这份文档，建议优先在功能变更后同步更新以下 4 个部分：

- 项目现状
- 当前和 AGENTS.md 的差异
- 主要页面职责
- 持久化与备份机制
