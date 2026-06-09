import Foundation

// A free-form growth milestone: "第一次翻身", "会叫妈妈", "第一颗牙"...
struct Milestone: Identifiable, Hashable, Codable {
    let id: String
    var date: Date
    var ageMonths: Double
    var title: String
    var note: String?
    var emoji: String?
    var photoData: Data?

    init(id: String,
         date: Date,
         ageMonths: Double = 0,
         title: String,
         note: String? = nil,
         emoji: String? = nil,
         photoData: Data? = nil) {
        self.id = id
        self.date = date
        self.ageMonths = ageMonths
        self.title = title
        self.note = note
        self.emoji = emoji
        self.photoData = photoData
    }

    static func new(title: String,
                    date: Date = .now,
                    ageMonths: Double = 0,
                    note: String? = nil,
                    emoji: String? = nil,
                    photoData: Data? = nil) -> Milestone {
        Milestone(
            id: "ms_" + UUID().uuidString.prefix(6).lowercased(),
            date: date, ageMonths: ageMonths, title: title, note: note, emoji: emoji, photoData: photoData
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, ageMonths, title, note, emoji, photoData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        ageMonths = try c.decodeIfPresent(Double.self, forKey: .ageMonths) ?? 0
        title = try c.decode(String.self, forKey: .title)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        photoData = try c.decodeIfPresent(Data.self, forKey: .photoData)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(ageMonths, forKey: .ageMonths)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encodeIfPresent(emoji, forKey: .emoji)
        try c.encodeIfPresent(photoData, forKey: .photoData)
    }
}

func milestoneAgeLabel(_ ageMonths: Double) -> String {
    let safeMonths = max(0, ageMonths)
    let wholeMonths = Int(safeMonths.rounded(.down))
    let days = Int(((safeMonths - Double(wholeMonths)) * 30).rounded())

    if wholeMonths == 0 {
        return days == 0 ? "出生当天" : "\(days) 天"
    }
    if days == 0 {
        return "\(wholeMonths) 月龄"
    }
    return "\(wholeMonths) 月龄 \(days) 天"
}
