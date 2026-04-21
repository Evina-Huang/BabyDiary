import Foundation

// A free-form growth milestone: "第一次翻身", "会叫妈妈", "第一颗牙"...
struct Milestone: Identifiable, Hashable, Codable {
    let id: String
    var date: Date
    var title: String
    var note: String?
    var emoji: String?
    var photoData: Data?

    static func new(title: String,
                    date: Date = .now,
                    note: String? = nil,
                    emoji: String? = nil,
                    photoData: Data? = nil) -> Milestone {
        Milestone(
            id: "ms_" + UUID().uuidString.prefix(6).lowercased(),
            date: date, title: title, note: note, emoji: emoji, photoData: photoData
        )
    }
}
