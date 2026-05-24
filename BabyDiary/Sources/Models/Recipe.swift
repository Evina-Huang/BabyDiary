import Foundation

struct Recipe: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var foodNames: [String]
    var createdAt: Date

    init(
        id: String = "rcp" + UUID().uuidString.prefix(6).lowercased(),
        name: String,
        foodNames: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.foodNames = foodNames
        self.createdAt = createdAt
    }
}
