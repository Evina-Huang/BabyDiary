import SwiftUI

// Custom SVG-style icons matching the React `Ico.*` set.
// Drawn on a 24×24 (or 32×32) grid, rendered as SwiftUI paths so they
// match the exact stroke widths / line joins of the web app.
enum AppIcon {
    // MARK: — Tab-bar glyphs (24×24, stroke 2)

    struct Home: View {
        var size: CGFloat = 24
        var color: Color
        var fill: Color = .clear
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 4, y: 11))
                p.addLine(to: .init(x: 12, y: 4))
                p.addLine(to: .init(x: 20, y: 11))
                p.addLine(to: .init(x: 20, y: 20))
                p.addLine(to: .init(x: 16, y: 20))
                p.addLine(to: .init(x: 16, y: 14))
                p.addLine(to: .init(x: 10, y: 14))
                p.addLine(to: .init(x: 10, y: 20))
                p.addLine(to: .init(x: 5, y: 20))
                p.closeSubpath()
                let scaled = p.applying(CGAffineTransform(scaleX: size/24, y: size/24))
                ctx.fill(scaled, with: .color(fill))
                ctx.stroke(scaled, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Book: View {
        var size: CGFloat = 24
        var color: Color
        var fill: Color = .clear
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 5, y: 4))
                p.addLine(to: .init(x: 14, y: 4))
                p.addQuadCurve(to: .init(x: 18, y: 8), control: .init(x: 18, y: 4))
                p.addLine(to: .init(x: 18, y: 20))
                p.addLine(to: .init(x: 9, y: 20))
                p.addQuadCurve(to: .init(x: 5, y: 24), control: .init(x: 5, y: 20))
                p.closeSubpath()
                var lines = Path()
                lines.move(to: .init(x: 9, y: 9)); lines.addLine(to: .init(x: 14, y: 9))
                lines.move(to: .init(x: 9, y: 13)); lines.addLine(to: .init(x: 14, y: 13))
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.fill(p.applying(t), with: .color(fill))
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ctx.stroke(lines.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Growth: View {
        var size: CGFloat = 24
        var color: Color
        var fill: Color = .clear
        var body: some View {
            Canvas { ctx, _ in
                var curve = Path()
                curve.move(to: .init(x: 4, y: 17))
                curve.addCurve(to: .init(x: 10, y: 9), control1: .init(x: 7, y: 16), control2: .init(x: 9, y: 13))
                curve.move(to: .init(x: 10, y: 9))
                curve.addCurve(to: .init(x: 17, y: 17), control1: .init(x: 11, y: 12), control2: .init(x: 13, y: 15))
                var baseline = Path()
                baseline.move(to: .init(x: 3, y: 21))
                baseline.addLine(to: .init(x: 21, y: 21))
                let dots: [CGPoint] = [.init(x: 4, y: 17), .init(x: 10, y: 9), .init(x: 17, y: 17)]
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.stroke(curve.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ctx.stroke(baseline.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                for d in dots {
                    let c = CGRect(x: d.x - 1.5, y: d.y - 1.5, width: 3, height: 3).applying(t)
                    ctx.fill(Path(ellipseIn: c), with: .color(color))
                }
            }
            .frame(width: size, height: size)
        }
    }

    struct Chart: View {
        var size: CGFloat = 24
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 4, y: 20));  p.addLine(to: .init(x: 4, y: 10))
                p.move(to: .init(x: 10, y: 20)); p.addLine(to: .init(x: 10, y: 4))
                p.move(to: .init(x: 16, y: 20)); p.addLine(to: .init(x: 16, y: 12))
                p.move(to: .init(x: 22, y: 20)); p.addLine(to: .init(x: 2, y: 20))
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: — Small glyphs

    struct Back: View {
        var size: CGFloat = 22
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 15, y: 6))
                p.addLine(to: .init(x: 9, y: 12))
                p.addLine(to: .init(x: 15, y: 18))
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Chevron: View {
        var size: CGFloat = 16
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 9, y: 6))
                p.addLine(to: .init(x: 15, y: 12))
                p.addLine(to: .init(x: 9, y: 18))
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Plus: View {
        var size: CGFloat = 22
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 12, y: 5)); p.addLine(to: .init(x: 12, y: 19))
                p.move(to: .init(x: 5, y: 12));  p.addLine(to: .init(x: 19, y: 12))
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Check: View {
        var size: CGFloat = 18
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 5, y: 12))
                p.addLine(to: .init(x: 10, y: 17))
                p.addLine(to: .init(x: 20, y: 7))
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Clock: View {
        var size: CGFloat = 18
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                let ring = Path(ellipseIn: .init(x: 3, y: 3, width: 18, height: 18)).applying(t)
                var hands = Path()
                hands.move(to: .init(x: 12, y: 7))
                hands.addLine(to: .init(x: 12, y: 12))
                hands.addLine(to: .init(x: 15, y: 14))
                ctx.stroke(ring, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                ctx.stroke(hands.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Calendar: View {
        var size: CGFloat = 18
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                let rect = Path(roundedRect: .init(x: 3, y: 5, width: 18, height: 16), cornerRadius: 3).applying(t)
                var bars = Path()
                bars.move(to: .init(x: 3, y: 10));  bars.addLine(to: .init(x: 21, y: 10))
                bars.move(to: .init(x: 8, y: 3));   bars.addLine(to: .init(x: 8, y: 7))
                bars.move(to: .init(x: 16, y: 3));  bars.addLine(to: .init(x: 16, y: 7))
                ctx.stroke(rect, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ctx.stroke(bars.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Close: View {
        var size: CGFloat = 16
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                var p = Path()
                p.move(to: .init(x: 6, y: 6));  p.addLine(to: .init(x: 18, y: 18))
                p.move(to: .init(x: 18, y: 6)); p.addLine(to: .init(x: 6, y: 18))
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: — Category glyphs (inside colored tiles, 32×32 grid)

    struct Moon: View {
        var size: CGFloat = 28
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/32, y: size/32)
                var moon = Path()
                moon.move(to: .init(x: 22, y: 20))
                moon.addArc(center: .init(x: 12, y: 20), radius: 10,
                            startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                moon.closeSubpath()
                var inner = Path()
                inner.move(to: .init(x: 22, y: 20))
                inner.addCurve(to: .init(x: 12, y: 4), control1: .init(x: 16, y: 16), control2: .init(x: 12, y: 12))
                inner.addCurve(to: .init(x: 22, y: 20), control1: .init(x: 20, y: 4), control2: .init(x: 22, y: 14))
                ctx.fill(moon.applying(t), with: .color(color.opacity(0.22)))
                ctx.stroke(moon.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: 21, y: 7, width: 2, height: 2)).applying(t), with: .color(color))
                ctx.fill(Path(ellipseIn: CGRect(x: 25.4, y: 12.4, width: 1.6, height: 1.6)).applying(t), with: .color(color))
            }
            .frame(width: size, height: size)
        }
    }

    struct Bottle: View {
        var size: CGFloat = 28
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/32, y: size/32)
                var cap = Path()
                cap.move(to: .init(x: 12, y: 4)); cap.addLine(to: .init(x: 20, y: 4))
                var neck = Path()
                neck.move(to: .init(x: 11, y: 7))
                neck.addLine(to: .init(x: 21, y: 7))
                neck.addLine(to: .init(x: 20, y: 10))
                neck.addLine(to: .init(x: 12, y: 10))
                neck.closeSubpath()
                var body = Path()
                body.move(to: .init(x: 11, y: 10))
                body.addLine(to: .init(x: 21, y: 10))
                body.addLine(to: .init(x: 21, y: 25))
                body.addQuadCurve(to: .init(x: 18, y: 28), control: .init(x: 21, y: 28))
                body.addLine(to: .init(x: 14, y: 28))
                body.addQuadCurve(to: .init(x: 11, y: 25), control: .init(x: 11, y: 28))
                body.closeSubpath()
                var lines = Path()
                lines.move(to: .init(x: 13, y: 15)); lines.addLine(to: .init(x: 19, y: 15))
                lines.move(to: .init(x: 13, y: 19)); lines.addLine(to: .init(x: 19, y: 19))
                ctx.stroke(cap.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                ctx.stroke(neck.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                ctx.fill(body.applying(t), with: .color(color.opacity(0.2)))
                ctx.stroke(body.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                ctx.stroke(lines.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Diaper: View {
        var size: CGFloat = 28
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/32, y: size/32)
                var body = Path()
                body.move(to: .init(x: 5, y: 10))
                body.addLine(to: .init(x: 27, y: 10))
                body.addLine(to: .init(x: 25, y: 20))
                body.addQuadCurve(to: .init(x: 19, y: 25), control: .init(x: 25, y: 25))
                body.addLine(to: .init(x: 13, y: 25))
                body.addQuadCurve(to: .init(x: 7, y: 20), control: .init(x: 7, y: 25))
                body.closeSubpath()
                var bars = Path()
                bars.move(to: .init(x: 12, y: 15)); bars.addLine(to: .init(x: 12, y: 19))
                bars.move(to: .init(x: 20, y: 15)); bars.addLine(to: .init(x: 20, y: 19))
                bars.move(to: .init(x: 5, y: 10));  bars.addLine(to: .init(x: 8, y: 7))
                bars.move(to: .init(x: 27, y: 10)); bars.addLine(to: .init(x: 24, y: 7))
                ctx.fill(body.applying(t), with: .color(color.opacity(0.2)))
                ctx.stroke(body.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                ctx.stroke(bars.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Bowl: View {
        var size: CGFloat = 28
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/32, y: size/32)
                var bowl = Path()
                bowl.move(to: .init(x: 4, y: 15))
                bowl.addLine(to: .init(x: 28, y: 15))
                bowl.addArc(center: .init(x: 16, y: 15), radius: 12,
                            startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                bowl.closeSubpath()
                var steam = Path()
                for x in [12.0, 16.0, 20.0] {
                    steam.move(to: .init(x: x, y: 10))
                    steam.addCurve(to: .init(x: x, y: 4),
                                   control1: .init(x: x - 2, y: 8),
                                   control2: .init(x: x - 2, y: 6))
                }
                var base = Path()
                base.move(to: .init(x: 2, y: 22)); base.addLine(to: .init(x: 30, y: 22))
                ctx.fill(bowl.applying(t), with: .color(color.opacity(0.2)))
                ctx.stroke(bowl.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                ctx.stroke(steam.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                ctx.stroke(base.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Syringe: View {
        var size: CGFloat = 22
        var color: Color
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                var p = Path()
                p.move(to: .init(x: 17, y: 3)); p.addLine(to: .init(x: 21, y: 7))
                p.move(to: .init(x: 15, y: 5)); p.addLine(to: .init(x: 19, y: 9))
                p.move(to: .init(x: 19, y: 5)); p.addLine(to: .init(x: 10, y: 14)); p.addLine(to: .init(x: 14, y: 18)); p.addLine(to: .init(x: 23, y: 9))
                p.move(to: .init(x: 6, y: 14))
                p.addLine(to: .init(x: 3, y: 17)); p.addLine(to: .init(x: 4, y: 18))
                p.addLine(to: .init(x: 2, y: 20)); p.addLine(to: .init(x: 4, y: 22))
                p.addLine(to: .init(x: 6, y: 20)); p.addLine(to: .init(x: 7, y: 21))
                p.addLine(to: .init(x: 10, y: 18))
                ctx.stroke(p.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }

    struct Shield: View {
        var size: CGFloat = 24
        var color: Color
        var fill: Color = .clear
        var body: some View {
            Canvas { ctx, _ in
                let t = CGAffineTransform(scaleX: size/24, y: size/24)
                var shield = Path()
                shield.move(to: .init(x: 12, y: 3))
                shield.addLine(to: .init(x: 20, y: 6))
                shield.addLine(to: .init(x: 20, y: 12))
                shield.addCurve(to: .init(x: 12, y: 21),
                                control1: .init(x: 20, y: 17),
                                control2: .init(x: 16.5, y: 20))
                shield.addCurve(to: .init(x: 4, y: 12),
                                control1: .init(x: 7.5, y: 20),
                                control2: .init(x: 4, y: 17))
                shield.addLine(to: .init(x: 4, y: 6))
                shield.closeSubpath()
                var check = Path()
                check.move(to: .init(x: 9, y: 12))
                check.addLine(to: .init(x: 11.2, y: 14))
                check.addLine(to: .init(x: 15, y: 10))
                ctx.fill(shield.applying(t), with: .color(fill))
                ctx.stroke(shield.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ctx.stroke(check.applying(t), with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: size, height: size)
        }
    }
}

// Map event kind → (tint, ink, icon) for CategoryIcon / SinceLastBanner / EventRow.
struct CategoryStyle {
    let label: String
    let tint: Color
    let ink: Color
    let icon: AnyView

    static func forKind(_ kind: EventKind, iconSize: CGFloat = 28) -> CategoryStyle {
        switch kind {
        case .sleep:
            return .init(label: "睡眠", tint: Palette.lavender, ink: Palette.lavenderInk,
                         icon: AnyView(AppIcon.Moon(size: iconSize, color: Palette.lavenderInk)))
        case .feed:
            return .init(label: "喂奶", tint: Palette.pink, ink: Palette.pinkInk,
                         icon: AnyView(AppIcon.Bottle(size: iconSize, color: Palette.pinkInk)))
        case .diaper:
            return .init(label: "换尿布", tint: Palette.blue, ink: Palette.blueInk,
                         icon: AnyView(AppIcon.Diaper(size: iconSize, color: Palette.blueInk)))
        case .solid:
            return .init(label: "辅食", tint: Palette.yellow, ink: Palette.yellowInk,
                         icon: AnyView(AppIcon.Bowl(size: iconSize, color: Palette.yellowInk)))
        }
    }
}
