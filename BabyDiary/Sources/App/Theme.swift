import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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
        case .coral:    return .adaptive(light: 0xFF9B85, dark: 0xA95548)
        case .lavender: return .adaptive(light: 0xB89DD9, dark: 0x71598F)
        case .sky:      return .adaptive(light: 0x7EC4E7, dark: 0x32657E)
        case .blossom:  return .adaptive(light: 0xF5A8C0, dark: 0x85485B)
        }
    }
    var primary600: Color {
        switch self {
        case .coral:    return .adaptive(light: 0xB94032, dark: 0xFFAB98)
        case .lavender: return .adaptive(light: 0x72529F, dark: 0xCEB0EF)
        case .sky:      return .adaptive(light: 0x2C6E92, dark: 0x91D5F6)
        case .blossom:  return .adaptive(light: 0xA93F61, dark: 0xFFADC7)
        }
    }
    var primaryTint: Color {
        switch self {
        case .coral:    return .adaptive(light: 0xFFE8E0, dark: 0x452822)
        case .lavender: return .adaptive(light: 0xEFE5FA, dark: 0x33293F)
        case .sky:      return .adaptive(light: 0xD8EDFA, dark: 0x203744)
        case .blossom:  return .adaptive(light: 0xFCE2EC, dark: 0x422833)
        }
    }

    var onPrimary: Color {
        .adaptive(light: 0x2B2520, dark: 0xFFF8F2)
    }
}

enum Palette {
    static let bg      = Color.adaptive(light: 0xFFFBF7, dark: 0x141210)
    static let bg2     = Color.adaptive(light: 0xFFF5EE, dark: 0x25211E)
    static let card    = Color.adaptive(light: 0xFFFFFF, dark: 0x1C1917)
    static let ink     = Color.adaptive(light: 0x2B2520, dark: 0xF8F2EC)
    static let ink2    = Color.adaptive(light: 0x5A4E46, dark: 0xD2C7BE)
    static let ink3    = Color.adaptive(light: 0x756A63, dark: 0xAA9D93)
    static let line    = Color.adaptive(light: 0x2B2520, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.10)

    static let mint     = Color.adaptive(light: 0x8FD4B8, dark: 0x2F6654)
    static let mint600  = Color.adaptive(light: 0x2F765B, dark: 0x8CD6BA)
    static let mintTint = Color.adaptive(light: 0xDEF3E9, dark: 0x203A31)

    static let pink     = Color.adaptive(light: 0xFFD0DC, dark: 0x472A35)
    static let pinkInk  = Color.adaptive(light: 0x934159, dark: 0xF1A4BD)
    static let blue     = Color.adaptive(light: 0xCFE4F5, dark: 0x233A49)
    static let blueInk  = Color.adaptive(light: 0x2D678D, dark: 0x8EC5E9)
    static let yellow   = Color.adaptive(light: 0xFFE8A8, dark: 0x493B21)
    static let yellowInk = Color.adaptive(light: 0x76580A, dark: 0xEFCB79)
    static let lavender  = Color.adaptive(light: 0xE4D8F5, dark: 0x352D45)
    static let lavenderInk = Color.adaptive(light: 0x5F438C, dark: 0xC7ACEF)

    static let dangerTint = Color.adaptive(light: 0xFFE8E0, dark: 0x492621)
    static let dangerInk  = Color.adaptive(light: 0xB94032, dark: 0xFF9B88)
}

enum AppRadius {
    /// Small controls, icon wells, and compact status surfaces.
    static let compact: CGFloat = 12
    /// Inputs, list controls, and grouped secondary surfaces.
    static let control: CGFloat = 16
    /// Primary sections, cards, and modal content surfaces.
    static let surface: CGFloat = 20
}

enum SurfaceElevation {
    case flat
    case raised
    case floating
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// Two elevation levels. Flat content uses borders and spacing only.
extension View {
    /// `--shadow-1` — subtle card shadow.
    func shadowCard() -> some View {
        self
            .shadow(color: Color.adaptive(light: 0x2B2520, dark: 0x000000, lightAlpha: 0.035, darkAlpha: 0.20), radius: 1, x: 0, y: 1)
            .shadow(color: Color.adaptive(light: 0x2B2520, dark: 0x000000, lightAlpha: 0.035, darkAlpha: 0.16), radius: 10, x: 0, y: 3)
    }
    /// `--shadow-2` — medium surface shadow.
    func shadowSurface() -> some View {
        self
            .shadow(color: Color.adaptive(light: 0x2B2520, dark: 0x000000, lightAlpha: 0.04, darkAlpha: 0.22), radius: 4, x: 0, y: 2)
            .shadow(color: Color.adaptive(light: 0x2B2520, dark: 0x000000, lightAlpha: 0.05, darkAlpha: 0.18), radius: 20, x: 0, y: 8)
    }
    /// Primary pills share the subtle elevation instead of introducing a third glow style.
    func shadowPill(tint _: Color) -> some View {
        shadowCard()
    }

    @ViewBuilder
    func surfaceElevation(_ elevation: SurfaceElevation) -> some View {
        switch elevation {
        case .flat:
            self
        case .raised:
            shadowCard()
        case .floating:
            shadowSurface()
        }
    }

    func appFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle? = nil
    ) -> some View {
        modifier(AppFontModifier(
            size: size,
            weight: weight,
            design: design,
            relativeTo: textStyle ?? AppFontModifier.relativeStyle(for: size)
        ))
    }

    func appText(_ role: AppTextRole) -> some View {
        appFont(
            size: role.size,
            weight: role.weight,
            relativeTo: role.relativeStyle
        )
    }

    func respectReduceMotion() -> some View {
        modifier(ReduceMotionModifier())
    }
}

/// Semantic type roles keep hierarchy consistent while retaining Dynamic Type scaling.
enum AppTextRole {
    case pageTitle
    case screenTitle
    case heroTitle
    case sectionTitle
    case cardTitle
    case body
    case bodyEmphasis
    case label
    case caption
    case captionEmphasis
    case micro
    case button
    case statValue
    case timer

    var size: CGFloat {
        switch self {
        case .pageTitle: return 28
        case .screenTitle: return 22
        case .heroTitle: return 21
        case .sectionTitle: return 18
        case .cardTitle: return 16
        case .body, .bodyEmphasis: return 15
        case .label: return 14
        case .caption, .captionEmphasis: return 12
        case .micro: return 11
        case .button: return 17
        case .statValue: return 28
        case .timer: return 44
        }
    }

    var weight: Font.Weight {
        switch self {
        case .pageTitle, .screenTitle, .heroTitle:
            return .bold
        case .sectionTitle, .cardTitle, .button:
            return .semibold
        case .body, .caption:
            return .regular
        case .bodyEmphasis, .label, .captionEmphasis, .micro:
            return .medium
        case .statValue, .timer:
            return .black
        }
    }

    var relativeStyle: Font.TextStyle {
        switch self {
        case .pageTitle, .statValue, .timer: return .largeTitle
        case .screenTitle: return .title2
        case .heroTitle: return .title3
        case .sectionTitle, .cardTitle: return .headline
        case .body, .bodyEmphasis: return .body
        case .label: return .subheadline
        case .caption, .captionEmphasis: return .caption
        case .micro: return .caption2
        case .button: return .headline
        }
    }
}

private struct AppFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    let baseSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo: Font.TextStyle) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.baseSize = size
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(
            size: min(scaledSize, baseSize * Self.maximumScale(for: baseSize)),
            weight: hierarchyWeight,
            design: design
        ))
    }

    /// Older screens used heavy weights for nearly every label. Normalize those
    /// requests so only explicit key figures (`.black`) retain maximum emphasis.
    private var hierarchyWeight: Font.Weight {
        if weight == .heavy || weight == .bold {
            if baseSize < 14 { return .medium }
            if baseSize < 20 { return .semibold }
            return .bold
        }
        if weight == .semibold, baseSize < 14 {
            return .medium
        }
        return weight
    }

    static func relativeStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11: return .caption2
        case ..<14: return .caption
        case ..<17: return .body
        case ..<21: return .title3
        case ..<25: return .title2
        default: return .largeTitle
        }
    }

    private static func maximumScale(for size: CGFloat) -> CGFloat {
        switch size {
        case ...12: return 1.5
        case ...17: return 1.55
        case ...24: return 1.45
        default: return 1.35
        }
    }
}

private struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transaction { transaction in
            guard reduceMotion else { return }
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

// Quiet micro-label used for compact supporting information.
struct MicroLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .appText(.captionEmphasis)
            .foregroundStyle(Palette.ink3)
    }
}
