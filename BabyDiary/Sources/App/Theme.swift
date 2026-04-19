import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case coral, lavender, sky, blossom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .coral:    return "珊瑚"
        case .lavender: return "薰衣"
        case .sky:      return "天空"
        case .blossom:  return "樱花"
        }
    }

    var primary: Color {
        switch self {
        case .coral:    return Color(hex: 0xFF9B85)
        case .lavender: return Color(hex: 0xB89DD9)
        case .sky:      return Color(hex: 0x7EC4E7)
        case .blossom:  return Color(hex: 0xF5A8C0)
        }
    }
    var primary600: Color {
        switch self {
        case .coral:    return Color(hex: 0xFF7F64)
        case .lavender: return Color(hex: 0x9B7EC4)
        case .sky:      return Color(hex: 0x5AABD6)
        case .blossom:  return Color(hex: 0xE88AA8)
        }
    }
    var primaryTint: Color {
        switch self {
        case .coral:    return Color(hex: 0xFFE8E0)
        case .lavender: return Color(hex: 0xEFE5FA)
        case .sky:      return Color(hex: 0xD8EDFA)
        case .blossom:  return Color(hex: 0xFCE2EC)
        }
    }
}

enum Palette {
    static let bg      = Color(hex: 0xFFFBF7)
    static let bg2     = Color(hex: 0xFFF5EE)
    static let card    = Color.white
    static let ink     = Color(hex: 0x2B2520)
    static let ink2    = Color(hex: 0x5A4E46)
    static let ink3    = Color(hex: 0x9A8E85)
    static let line    = Color(red: 43/255, green: 37/255, blue: 32/255).opacity(0.08)

    static let mint     = Color(hex: 0x8FD4B8)
    static let mint600  = Color(hex: 0x67C29E)
    static let mintTint = Color(hex: 0xDEF3E9)

    static let pink     = Color(hex: 0xFFD0DC)
    static let pinkInk  = Color(hex: 0xC26A84)
    static let blue     = Color(hex: 0xCFE4F5)
    static let blueInk  = Color(hex: 0x4A86B5)
    static let yellow   = Color(hex: 0xFFE8A8)
    static let yellowInk = Color(hex: 0xB88A1F)
    static let lavender  = Color(hex: 0xE4D8F5)
    static let lavenderInk = Color(hex: 0x7C5EB0)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// Shadow helpers — two-layer soft shadows matching the CSS tokens.
extension View {
    /// `--shadow-1` — subtle card shadow.
    func shadowCard() -> some View {
        self
            .shadow(color: Color(hex: 0x2B2520).opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: Color(hex: 0x2B2520).opacity(0.05), radius: 14, x: 0, y: 4)
    }
    /// `--shadow-2` — medium surface shadow.
    func shadowSurface() -> some View {
        self
            .shadow(color: Color(hex: 0x2B2520).opacity(0.05), radius: 6, x: 0, y: 2)
            .shadow(color: Color(hex: 0x2B2520).opacity(0.07), radius: 30, x: 0, y: 10)
    }
    /// `--shadow-pill` — glowing shadow under coral CTA.
    func shadowPill(tint: Color) -> some View {
        self.shadow(color: tint.opacity(0.28), radius: 14, x: 0, y: 4)
    }
}

// Uppercase micro-label used all over the UI ("主题色", "跳到屏幕", etc.)
struct MicroLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.72)
            .textCase(.uppercase)
            .foregroundStyle(Palette.ink3)
    }
}
