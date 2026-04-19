import Foundation

enum VaccineStatus: String, Codable, Hashable {
    case done
    case due
    case overdue
    case upcoming
}

struct Vaccine: Identifiable, Hashable {
    let id: String
    var name: String
    var age: String
    var status: VaccineStatus
    var done: Bool
    var doneDate: String?
}
