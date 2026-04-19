import Foundation

struct GrowthPoint: Identifiable, Hashable {
    let id: String
    var date: Date
    var ageMonths: Double
    var weightKg: Double
    var heightCm: Double
    var headCm: Double?
}

struct Baby: Hashable {
    var name: String
    var ageLabel: String
    var birthLabel: String
}
