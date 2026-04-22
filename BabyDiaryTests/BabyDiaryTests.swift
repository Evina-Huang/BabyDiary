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

    @Test func storeSeedsData() {
        let store = AppStore()
        #expect(!store.events.isEmpty)
        #expect(!store.vaccines.isEmpty)
        #expect(!store.growth.isEmpty)
    }

    @Test func deleteEventRemovesIt() {
        let store = AppStore()
        let first = store.events[0]
        store.deleteEvent(first)
        #expect(!store.events.contains(first))
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
    }
}
