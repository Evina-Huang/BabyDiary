import Testing
import Foundation
@testable import BabyDiary

struct BabyDiaryTests {
    @Test func eventCreation() {
        let e = Event(kind: .feed, at: Date(), title: "奶粉", sub: "120 ml")
        #expect(e.kind == .feed)
        #expect(e.title == "奶粉")
        #expect(e.sub == "120 ml")
    }

    @Test func storeStartsEmptyForDailyUse() {
        let store = AppStore()
        #expect(store.events.isEmpty)
        #expect(store.vaccines.isEmpty)
        #expect(store.growth.isEmpty)
    }

    @Test func demoStoreSeedsData() {
        let store = AppStore(seedDemoData: true)
        #expect(!store.events.isEmpty)
        #expect(!store.vaccines.isEmpty)
        #expect(!store.growth.isEmpty)
    }

    @Test func demoStoreSeedsScreenshotTodayEvents() throws {
        let store = AppStore(seedDemoData: true)
        let cal = Calendar.current
        let todays = store.events.filter { cal.isDateInToday($0.at) }

        #expect(todays.count == 8)
        #expect(todays.map(\.id) == [
            "e_today_1904",
            "e_today_1632",
            "e_today_1623",
            "e_today_1505",
            "e_today_1220",
            "e_today_1104",
            "e_today_0714",
            "e_today_0604",
        ])

        let eveningFeed = try #require(todays.first { $0.id == "e_today_1904" })
        #expect(eveningFeed.title == "母乳 · 双侧")
        #expect(eveningFeed.sub == "右 4分 · 左 3分 · 共 7分")
        #expect(cal.component(.hour, from: eveningFeed.at) == 19)
        #expect(cal.component(.minute, from: eveningFeed.at) == 4)
        let eveningFeedEnd = try #require(eveningFeed.endAt)
        #expect(cal.component(.hour, from: eveningFeedEnd) == 19)
        #expect(cal.component(.minute, from: eveningFeedEnd) == 11)

        let diaper = try #require(todays.first { $0.id == "e_today_1623" })
        #expect(diaper.title == "臭臭")
        #expect(diaper.sub == "奶瓣")

        let formula = try #require(todays.first { $0.id == "e_today_1505" })
        #expect(formula.title == "配方奶")
        #expect(formula.sub == "230 ml · 15:05 - 15:13")
    }

    @Test func screenshotTodayEventsMergeOnceWithoutDroppingOtherRecords() throws {
        let defaultsKey = "BabyDiary.didImportScreenshotEvents.2026-04-23"
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: defaultsKey) }

        let store = AppStore()
        let cal = Calendar.current
        let duplicateSlot = cal.date(bySettingHour: 19, minute: 4, second: 0, of: Date())!
        let customSolid = Event(id: "custom_solid", kind: .solid, at: Date(), title: "香蕉", sub: "20g")
        store.events = [
            Event(id: "old_same_slot", kind: .feed, at: duplicateSlot, title: "旧记录", sub: "待替换"),
            customSolid,
        ]

        store.mergeScreenshotTodayEventsIfNeeded()

        #expect(store.events.contains(customSolid))
        #expect(!store.events.contains { $0.id == "old_same_slot" })
        #expect(AppStore.screenshotTodayEvents().allSatisfy { seeded in
            store.events.contains { $0.id == seeded.id }
        })
        let eventCountAfterFirstMerge = store.events.count

        store.mergeScreenshotTodayEventsIfNeeded()

        #expect(store.events.count == eventCountAfterFirstMerge)
    }

    @Test func deleteEventRemovesIt() {
        let store = AppStore(seedDemoData: true)
        let first = store.events[0]
        store.deleteEvent(first)
        #expect(!store.events.contains(first))
    }

    @Test func recentEventsSortsByEventTime() {
        let store = AppStore()
        let cal = Calendar.current
        let old = cal.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 8))!
        let latest = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8))!
        let middleOtherKind = cal.date(from: DateComponents(year: 2026, month: 4, day: 21, hour: 8))!
        store.events = [
            Event(id: "old", kind: .feed, at: old, title: "奶粉", sub: "90 ml"),
            Event(id: "diaper", kind: .diaper, at: middleOtherKind, title: "嘘嘘"),
            Event(id: "latest", kind: .feed, at: latest, title: "奶粉", sub: "120 ml"),
        ]

        #expect(store.recentEvents(kind: .feed).map(\.id) == ["latest", "old"])
    }

    @Test func mostRecentEventUsesFeedEndTime() throws {
        let store = AppStore()
        let cal = Calendar.current
        let earlyStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8, minute: 0))!
        let earlyEnd = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8, minute: 30))!
        let laterStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8, minute: 20))!
        let laterEnd = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8, minute: 25))!
        store.events = [
            Event(id: "later_start", kind: .feed, at: laterStart, endAt: laterEnd, title: "母乳 · 左侧", sub: "5分"),
            Event(id: "later_end", kind: .feed, at: earlyStart, endAt: earlyEnd, title: "母乳 · 右侧", sub: "30分"),
        ]

        let event = try #require(store.mostRecentEvent(kind: .feed))
        #expect(event.id == "later_end")
        #expect(event.occurredAt == earlyEnd)
    }

    @Test func feedReminderDueDateUsesLastFeedEndTime() throws {
        let store = AppStore()
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8, minute: 0))!
        let end = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8, minute: 20))!
        let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 9, minute: 0))!
        store.feedReminder = FeedReminderSettings(isEnabled: true, intervalHours: 4, anchorAt: nil)
        store.events = [
            Event(id: "feed", kind: .feed, at: start, endAt: end, title: "母乳 · 左侧", sub: "20分")
        ]

        let due = try #require(store.nextFeedReminderDueDate(now: now))

        #expect(due == cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 12, minute: 20))!)
    }

    @Test func feedReminderPlannerUsesAnchorWhenNoFeed() throws {
        let cal = Calendar.current
        let anchor = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 7, minute: 0))!
        let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 7, minute: 30))!
        let settings = FeedReminderSettings(isEnabled: true, intervalHours: 4, anchorAt: anchor)

        let due = try #require(FeedReminderPlanner.dueDate(settings: settings, lastFeed: nil, now: now))

        #expect(due == cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 11, minute: 0))!)
    }

    @Test func mostRecentBreastFeedIgnoresLaterFormulaEntry() throws {
        let store = AppStore()
        let cal = Calendar.current
        let breastStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 7, minute: 0))!
        let breastEnd = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 7, minute: 12))!
        let formulaTime = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 8, minute: 30))!
        store.events = [
            Event(id: "formula", kind: .feed, at: formulaTime, title: "奶粉", sub: "180 ml"),
            Event(id: "breast", kind: .feed, at: breastStart, endAt: breastEnd, title: "母乳 · 双侧", sub: "右 7分 · 左 5分 · 共 12分"),
        ]

        let event = try #require(store.mostRecentBreastFeedEvent())
        #expect(event.id == "breast")
        #expect(event.breastEndingSide == .left)
    }

    @Test func breastFeedSummaryKeepsFirstSideOrder() {
        #expect(orderedBreastFeedSummary(leftMinutes: 7, rightMinutes: 3, firstSide: .left) == "左 7分 · 右 3分 · 共 10分")
        #expect(orderedBreastFeedSummary(leftMinutes: 7, rightMinutes: 3, firstSide: .right) == "右 3分 · 左 7分 · 共 10分")
    }

    @Test func dailySummarySeparatesBreastAndFormulaTotals() {
        let store = AppStore()
        let cal = Calendar.current
        let day = cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 12))!

        store.events = [
            Event(id: "breast", kind: .feed, at: cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 7, minute: 30))!, title: "母乳 · 双侧", sub: "右 9分 · 左 8分 · 共 17分"),
            Event(id: "formula_old", kind: .feed, at: cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 11, minute: 0))!, title: "配方奶", sub: "210 ml · 10:55 - 11:00"),
            Event(id: "formula_new", kind: .feed, at: cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 15, minute: 0))!, title: "奶粉", sub: "250 ml"),
            Event(id: "sleep", kind: .sleep, at: cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 12, minute: 20))!, endAt: cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 13, minute: 49))!, title: "睡眠 1时29分", sub: "12:20 - 13:49"),
            Event(id: "diaper", kind: .diaper, at: cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 16, minute: 20))!, title: "嘘嘘"),
            Event(id: "solid", kind: .solid, at: cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 18, minute: 0))!, title: "米糊", sub: "30g"),
        ]

        let summary = store.dailySummary(on: day, now: day)

        #expect(summary.feedCount == 3)
        #expect(summary.breastCount == 1)
        #expect(summary.breastDuration == 17 * 60)
        #expect(summary.formulaCount == 2)
        #expect(summary.formulaMilliliters == 460)
        #expect(summary.sleepCount == 1)
        #expect(summary.sleepDuration == 89 * 60)
        #expect(summary.diaperCount == 1)
        #expect(summary.solidCount == 1)
    }

    @Test func diaperEventTypeParsesExistingTitles() {
        #expect(DiaperEventType.from(title: "嘘嘘") == .wet)
        #expect(DiaperEventType.from(title: "臭臭") == .dirty)
        #expect(DiaperEventType.from(title: "嘘嘘+臭臭") == .both)
    }

    @Test func diaperNoteOptionsKeepPresetsAndAppendCurrentCustomValue() {
        #expect(DiaperNotePreset.options(including: nil).contains("奶瓣"))
        #expect(DiaperNotePreset.options(including: "自定义备注").last == "自定义备注")
        #expect(DiaperNotePreset.options(including: "稀便").filter { $0 == "稀便" }.count == 1)
    }

    @Test func deleteSolidEventRemovesFoodEntryWhenLastUse() {
        let store = AppStore()
        let triedAt = Date()
        let solid = Event(id: "solid1", kind: .solid, at: triedAt, title: "南瓜泥", sub: "30g")
        store.events = [solid]
        store.foods = [
            FoodItem(id: "fd1", name: "南瓜泥", firstUsedAt: triedAt, status: .observing, timesEaten: 1, observationDays: 3)
        ]

        store.deleteEvent(solid)

        #expect(store.events.isEmpty)
        #expect(!store.foods.contains { $0.name == "南瓜泥" })
    }

    @Test func updateSolidEventRetargetsFoodList() {
        let store = AppStore()
        let originalAt = Date()
        let updatedAt = originalAt.addingTimeInterval(3600)
        let original = Event(id: "solid1", kind: .solid, at: originalAt, title: "南瓜泥", sub: "30g")
        let updated = Event(id: "solid1", kind: .solid, at: updatedAt, title: "米糊", sub: "40g")
        store.events = [original]
        store.foods = [
            FoodItem(id: "fd1", name: "南瓜泥", firstUsedAt: originalAt, status: .observing, timesEaten: 1, observationDays: 3)
        ]

        store.updateEvent(updated)

        #expect(!store.foods.contains { $0.name == "南瓜泥" })
        #expect(store.foods.contains {
            $0.name == "米糊" && $0.timesEaten == 1 && $0.firstUsedAt == updatedAt
        })
    }

    @Test func updateGrowthRecomputesAgeMonthsFromDate() {
        let store = AppStore()
        let cal = Calendar.current
        store.baby.birthDate = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let originalDate = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let updatedDate = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let point = GrowthPoint(id: "g1", date: originalDate, ageMonths: 1, weightKg: 4.0, heightCm: 54.0, headCm: nil)
        store.growth = [point]

        var updated = point
        updated.date = updatedDate
        store.updateGrowth(updated)

        #expect(store.growth[0].ageMonths == 3)
    }

    @Test func updateBabyRefreshesBirthDateDerivedData() {
        let store = AppStore()
        let cal = Calendar.current
        let oldBirth = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let newBirth = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let measured = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let oldRecommended = cal.date(byAdding: .month, value: 2, to: oldBirth)!
        let newRecommended = cal.date(byAdding: .month, value: 2, to: newBirth)!
        let customDate = cal.date(from: DateComponents(year: 2026, month: 5, day: 5))!

        store.baby.birthDate = oldBirth
        store.growth = [
            GrowthPoint(id: "g1", date: measured, ageMonths: 99, weightKg: 6, heightCm: 62, headCm: nil)
        ]
        store.vaccines = [
            Vaccine(id: "v1", name: "推荐疫苗", ageLabel: "2 月龄", ageMonths: 2, scheduledDate: oldRecommended, doneDate: nil),
            Vaccine(id: "v2", name: "自定义日期疫苗", ageLabel: "3 月龄", ageMonths: 3, scheduledDate: customDate, doneDate: nil),
        ]

        var baby = store.baby
        baby.birthDate = newBirth
        store.updateBaby(baby)

        #expect(store.growth[0].ageMonths == 2)
        #expect(cal.isDate(store.vaccines.first { $0.id == "v1" }!.scheduledDate!, inSameDayAs: newRecommended))
        #expect(store.vaccines.first { $0.id == "v2" }!.scheduledDate == customDate)
    }

    @Test func availableVaccineTemplatesHideLegacyEquivalent() {
        let store = AppStore()
        store.vaccines = [
            Vaccine(id: "legacy_mmr", name: "麻腮风疫苗", ageLabel: "8 月龄", ageMonths: 8, scheduledDate: nil, doneDate: nil)
        ]

        #expect(!store.availableVaccineTemplates.contains { $0.id == "t_mmr1" })
    }

    @Test func toggleVaccineUsesActualCompletionDate() throws {
        let store = AppStore()
        let scheduled = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        store.vaccines = [
            Vaccine(id: "v1", name: "测试疫苗", ageLabel: "1 月龄", ageMonths: 1, scheduledDate: scheduled, doneDate: nil)
        ]

        let before = Date()
        store.toggleVaccine("v1")
        let after = Date()

        let doneDate = try #require(store.vaccines[0].doneDate)
        #expect(doneDate >= before)
        #expect(doneDate <= after)
    }

    @Test func medicationRecordsSortNewestFirst() {
        let store = AppStore()
        let cal = Calendar.current
        let older = cal.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 9))!
        let newer = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 18))!
        store.medications = []

        store.addMedication(MedicationRecord(id: "m1", name: "维生素 D3", takenAt: older, dose: "1 粒", reason: "每日补充", reaction: .none))
        store.addMedication(MedicationRecord(id: "m2", name: "对乙酰氨基酚", takenAt: newer, dose: "2.5 ml", reason: "发热", reaction: .observing))

        #expect(store.medications.map(\.id) == ["m2", "m1"])
    }

    @Test func snapshotIncludesMedicationRecords() throws {
        let store = AppStore()
        let takenAt = Date()
        let record = MedicationRecord(
            id: "m1",
            name: "头孢克洛",
            takenAt: takenAt,
            dose: "半包",
            reason: "医生开具",
            reaction: .allergic,
            reactionNote: "皮疹"
        )
        store.medications = [record]

        let snapshot = store.snapshot()

        let medications = try #require(snapshot.medications)
        #expect(medications == [record])
    }

    @Test func snapshotIncludesFeedReminderSettings() throws {
        let store = AppStore()
        let anchor = Date()
        store.feedReminder = FeedReminderSettings(isEnabled: true, intervalHours: 4, anchorAt: anchor)

        let snapshot = store.snapshot()
        let reminder = try #require(snapshot.feedReminder)

        #expect(reminder == store.feedReminder)
    }

    @Test func pauseTimerBanksElapsedTimeAndResumeContinues() {
        let store = AppStore()
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 9, minute: 0))!
        let pausedAt = cal.date(byAdding: .minute, value: 35, to: start)!
        let resumedAt = cal.date(byAdding: .minute, value: 50, to: start)!
        let end = cal.date(byAdding: .minute, value: 80, to: start)!

        store.startTimer(kind: .sleep, at: start)
        store.pauseTimer(at: pausedAt)

        let paused = try! #require(store.activeTimer)
        #expect(paused.kind == .sleep)
        #expect(paused.startedAt == start)
        #expect(paused.resumedAt == nil)
        #expect(paused.accumulated == 35 * 60)

        store.resumeTimer(at: resumedAt)

        let resumed = try! #require(store.activeTimer)
        #expect(resumed.resumedAt == resumedAt)
        #expect(resumed.elapsed(at: end) == 65 * 60)
    }

    @Test func sleepDurationCountsOnlyTodayPortionForCrossDayRecords() {
        let store = AppStore()
        let cal = Calendar.current
        let day = cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 12))!
        let overnightStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 23, minute: 30))!
        let overnightEnd = cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 1, minute: 15))!
        let napStart = cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 13, minute: 0))!
        let napEnd = cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 14, minute: 0))!

        store.events = [
            Event(id: "overnight", kind: .sleep, at: overnightStart, endAt: overnightEnd, title: "睡眠 1时45分", sub: "23:30 - 01:15"),
            Event(id: "nap", kind: .sleep, at: napStart, endAt: napEnd, title: "睡眠 1时", sub: "13:00 - 14:00"),
        ]

        #expect(store.sleepDuration(on: day, now: day) == 135 * 60)
    }

    @Test func sleepDurationCountsRunningSleepAfterMidnight() {
        let store = AppStore()
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 4, day: 23, hour: 23, minute: 30))!
        let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 1, minute: 0))!

        store.startTimer(kind: .sleep, at: start)

        #expect(store.sleepDuration(on: now, now: now) == 60 * 60)
    }

    @Test func feedDraftDefaultsMatchFormulaManualEntry() {
        let draft = FeedDraft()

        #expect(draft.formulaSubMode == .manual)
        #expect(draft.formulaMilliliters == 210)
    }

    @Test func sleepEventTitleUsesDurationFromManualTimes() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 10, minute: 5))!
        let end = cal.date(byAdding: .minute, value: 52, to: start)!
        let event = Event(
            kind: .sleep,
            at: start,
            endAt: end,
            title: "睡眠 \(formatDurShort(end.timeIntervalSince(start)))",
            sub: "\(formatTime(start)) - \(formatTime(end))"
        )

        #expect(event.title == "睡眠 52分")
        #expect(event.sub == "10:05 - 10:57")
    }

    @Test func applyLegacySnapshotClearsTeeth() {
        let store = AppStore()
        let eruptedAt = Date()
        store.setTooth(ToothPosition.all[0], eruptedAt: eruptedAt, note: "已出")
        #expect(store.teeth.contains { $0.eruptedAt == eruptedAt })

        let snapshot = DataSnapshot(
            baby: store.baby,
            events: [],
            vaccines: [],
            growth: [],
            foods: [],
            teeth: nil,
            milestones: nil
        )

        store.apply(snapshot)

        #expect(store.teeth.count == ToothPosition.all.count)
        #expect(store.teeth.allSatisfy { $0.eruptedAt == nil })
        #expect(store.medications.isEmpty)
    }
}
