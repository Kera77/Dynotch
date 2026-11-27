import AppKit
import SwiftUI

/// One-colour marks of a few apps, drawn as shapes so they can be white (spec B-3).
enum BrandGlyph: String, CaseIterable, Sendable {
    case claude = "wingmate.claude"
    case beeper = "wingmate.beeper"
    case googleChat = "wingmate.gchat"
    case gmail = "wingmate.gmail"

    /// The SF Symbol standing for the mark in menus, which can only show symbols.
    var menuSymbol: String {
        switch self {
        case .claude: "sparkle"
        case .beeper: "bubble.left.and.bubble.right.fill"
        case .googleChat: "bubble.left.fill"
        case .gmail: "envelope.fill"
        }
    }
}

/// The filled outline of a brand mark in a unit square scaled to the given rect.
struct BrandGlyphShape: Shape {
    let glyph: BrandGlyph

    /// The Google Chat bubble has a smile cut out of it.
    var fillStyle: FillStyle { FillStyle(eoFill: glyph == .googleChat) }

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let transform = CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
            .scaledBy(x: side, y: side)
        return unitPath.applying(transform)
    }

    private var unitPath: Path {
        switch glyph {
        case .claude: Self.claude
        case .beeper: Self.beeper
        case .googleChat: Self.googleChat
        case .gmail: Self.gmail
        }
    }

    private static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static func stroked(_ path: Path, width: CGFloat) -> Path {
        path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// Rays around the centre.
    private static var claude: Path {
        var rays = Path()
        let count = 10
        for ray in 0..<count {
            let angle = Double(ray) / Double(count) * 2 * .pi - .pi / 2
            let length = ray.isMultiple(of: 2) ? 0.47 : 0.4
            rays.move(to: point(0.5, 0.5))
            rays.addLine(to: point(0.5 + cos(angle) * length, 0.5 + sin(angle) * length))
        }
        return stroked(rays, width: 0.11)
    }

    /// A "B": an outlined speech bubble on top of a solid lower half.
    private static var beeper: Path {
        var bubble = Path()
        bubble.move(to: point(0.4, 0.5))
        bubble.addLine(to: point(0.36, 0.5))
        bubble.addArc(center: point(0.36, 0.3), radius: 0.2, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        bubble.addLine(to: point(0.6, 0.1))
        bubble.addArc(center: point(0.6, 0.3), radius: 0.2, startAngle: .degrees(-90), endAngle: .degrees(45), clockwise: false)
        bubble.addLine(to: point(0.47, 0.71))
        let outline = stroked(bubble, width: 0.075)

        var body = Path()
        body.move(to: point(0.26, 0.5))
        body.addLine(to: point(0.47, 0.5))
        body.addLine(to: point(0.42, 0.74))
        body.addLine(to: point(0.72, 0.47))
        body.addCurve(to: point(0.62, 0.92), control1: point(0.94, 0.58), control2: point(0.86, 0.92))
        body.addLine(to: point(0.26, 0.92))
        body.closeSubpath()
        return outline.union(body)
    }

    /// A speech bubble with a smile.
    private static var googleChat: Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: 0.08, y: 0.1, width: 0.84, height: 0.62), cornerSize: CGSize(width: 0.24, height: 0.24))
        var tail = Path()
        tail.move(to: point(0.2, 0.6))
        tail.addLine(to: point(0.2, 0.93))
        tail.addLine(to: point(0.46, 0.7))
        tail.closeSubpath()
        path = path.union(tail)

        var smile = Path()
        smile.move(to: point(0.34, 0.42))
        smile.addQuadCurve(to: point(0.66, 0.42), control: point(0.5, 0.6))
        path.addPath(stroked(smile, width: 0.085))
        return path
    }

    /// The envelope "M".
    private static var gmail: Path {
        var letter = Path()
        letter.move(to: point(0.14, 0.8))
        letter.addLine(to: point(0.14, 0.26))
        letter.addLine(to: point(0.5, 0.54))
        letter.addLine(to: point(0.86, 0.26))
        letter.addLine(to: point(0.86, 0.8))
        return stroked(letter, width: 0.15)
    }
}

/// A brand mark in one colour at the given size.
struct BrandGlyphView: View {
    let glyph: BrandGlyph
    var size: CGFloat = 16
    var color: Color = .white

    var body: some View {
        let shape = BrandGlyphShape(glyph: glyph)
        shape
            .fill(color, style: shape.fillStyle)
            .frame(width: size, height: size)
    }
}
