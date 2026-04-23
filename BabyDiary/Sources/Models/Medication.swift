import Foundation

enum MedicationReaction: String, Codable, Hashable, CaseIterable {
    case observing
    case none
    case allergic

    var label: String {
        switch self {
        case .observing: return "观察中"
        case .none: return "无异常"
        case .allergic: return "疑似过敏"
        }
    }
}

struct MedicationRecord: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var takenAt: Date
    var dose: String
    var reason: String
    var reaction: MedicationReaction
    var reactionNote: String?
    var note: String?

    init(
        id: String = "md_" + UUID().uuidString.prefix(6).lowercased(),
        name: String,
        takenAt: Date,
        dose: String = "",
        reason: String = "",
        reaction: MedicationReaction = .observing,
        reactionNote: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.takenAt = takenAt
        self.dose = dose
        self.reason = reason
        self.reaction = reaction
        self.reactionNote = reactionNote
        self.note = note
    }
}
