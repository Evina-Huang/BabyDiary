import Foundation

enum ToothJaw: String, Codable, Hashable { case upper, lower }
enum ToothSide: String, Codable, Hashable { case left, right }

enum ToothKind: String, Codable, Hashable, CaseIterable {
    case centralIncisor, lateralIncisor, canine, firstMolar, secondMolar

    var zh: String {
        switch self {
        case .centralIncisor: return "门牙"
        case .lateralIncisor: return "侧门牙"
        case .canine:         return "尖牙"
        case .firstMolar:     return "第一乳磨牙"
        case .secondMolar:    return "第二乳磨牙"
        }
    }

    /// 典型萌出月龄范围(乳牙,合并上下颌大致区间)
    var typicalMonths: ClosedRange<Int> {
        switch self {
        case .centralIncisor: return 6...12
        case .lateralIncisor: return 9...16
        case .canine:         return 16...22
        case .firstMolar:     return 13...19
        case .secondMolar:    return 23...33
        }
    }

    /// 相对视觉宽度(磨牙更宽)
    var widthFactor: CGFloat {
        switch self {
        case .centralIncisor: return 0.95
        case .lateralIncisor: return 0.85
        case .canine:         return 0.95
        case .firstMolar:     return 1.25
        case .secondMolar:    return 1.40
        }
    }
}

struct ToothPosition: Codable, Hashable, Identifiable {
    let jaw: ToothJaw
    let side: ToothSide
    let kind: ToothKind

    var id: String { "\(jaw.rawValue)_\(side.rawValue)_\(kind.rawValue)" }

    /// 20 颗乳牙,按视觉从左到右排列(上排 10 + 下排 10)。
    static let all: [ToothPosition] = {
        let kindsLeft: [ToothKind]  = [.secondMolar, .firstMolar, .canine, .lateralIncisor, .centralIncisor]
        let kindsRight: [ToothKind] = [.centralIncisor, .lateralIncisor, .canine, .firstMolar, .secondMolar]
        var out: [ToothPosition] = []
        for jaw in [ToothJaw.upper, .lower] {
            for k in kindsLeft  { out.append(.init(jaw: jaw, side: .left,  kind: k)) }
            for k in kindsRight { out.append(.init(jaw: jaw, side: .right, kind: k)) }
        }
        return out
    }()

    var label: String {
        let jawZh  = jaw  == .upper ? "上" : "下"
        let sideZh = side == .left  ? "左" : "右"
        return "\(sideZh)\(jawZh)\(kind.zh)"
    }
}

struct ToothRecord: Identifiable, Codable, Hashable {
    var id: String   // 稳定 id,按位置生成,便于 backup 合并
    var position: ToothPosition
    var eruptedAt: Date?
    var note: String?

    static func id(for p: ToothPosition) -> String {
        "th_\(p.jaw.rawValue)_\(p.side.rawValue)_\(p.kind.rawValue)"
    }

    static func empty(for p: ToothPosition) -> ToothRecord {
        .init(id: id(for: p), position: p, eruptedAt: nil, note: nil)
    }
}
