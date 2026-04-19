import Testing
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
}
