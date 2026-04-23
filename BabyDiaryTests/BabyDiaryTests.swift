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
