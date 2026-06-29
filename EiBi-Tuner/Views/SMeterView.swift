//
//  SMeterView.swift
//  EiBi-Tuner
//
//  A classic moving-coil S-meter. The face (arc, ticks, S1…S9 +20…+60 labels)
//  is drawn with Canvas; the needle is a spring-animated overlay driven by the
//  FLRIG S-meter reading (0…100).
//

import SwiftUI

struct SMeterView: View {
    /// 0…100, as FLRIG's get_smeter reports.
    var value: Double
    var online: Bool

    // Fractions (0…1 across the arc) for the labelled marks.
    private let sLabels: [(String, Double, Bool)] = [
        ("1", 0.00, false), ("3", 0.13, false), ("5", 0.26, false),
        ("7", 0.39, false), ("9", 0.52, false),
        ("+20", 0.66, true), ("+40", 0.83, true), ("+60", 1.00, true),
    ]
    private let sweep = 104.0 // total degrees

    private var clamped: Double { min(max(value, 0), 100) }
    private var needleAngle: Double { -sweep / 2 + (clamped / 100) * sweep }

    var body: some View {
        ZStack {
            // Meter face
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.96, green: 0.93, blue: 0.84),
                             Color(red: 0.86, green: 0.82, blue: 0.70)],
                    startPoint: .top, endPoint: .bottom))

            Canvas { ctx, size in drawFace(ctx, size) }
                .padding(10)

            // Needle
            GeometryReader { geo in
                MeterNeedle()
                    .fill(LinearGradient(colors: [.black, Theme.pointer],
                                         startPoint: .bottom, endPoint: .top))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .rotationEffect(.degrees(needleAngle), anchor: UnitPoint(x: 0.5, y: 0.9))
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: needleAngle)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            }
            .padding(10)

            // Hub cap
            GeometryReader { geo in
                Circle()
                    .fill(Theme.metalKnob)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(.black.opacity(0.5), lineWidth: 1))
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.9 - 10 + 10)
            }
            .padding(10)

            GlassReflection(corner: 12)
            BrassBezel(corner: 14, line: 8)

            if !online {
                Text("NO RIG")
                    .font(Theme.label(11))
                    .foregroundStyle(.black.opacity(0.35))
                    .offset(y: -4) // sits just above the "SIGNAL" caption
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
    }

    private func drawFace(_ ctx: GraphicsContext, _ size: CGSize) {
        let pivot = CGPoint(x: size.width / 2, y: size.height * 0.92)
        let r = size.height * 0.80

        func point(_ frac: Double, radius: CGFloat) -> CGPoint {
            let a = (-sweep / 2 + frac * sweep) * .pi / 180
            return CGPoint(x: pivot.x + radius * sin(a),
                           y: pivot.y - radius * cos(a))
        }

        // Black arc (S1…S9) then red arc (over S9)
        func arcPath(from: Double, to: Double, radius: CGFloat) -> Path {
            var p = Path()
            let steps = 48
            for i in 0...steps {
                let f = from + (to - from) * Double(i) / Double(steps)
                let pt = point(f, radius: radius)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            return p
        }
        ctx.stroke(arcPath(from: 0, to: 0.52, radius: r),
                   with: .color(.black.opacity(0.78)), lineWidth: 2.5)
        ctx.stroke(arcPath(from: 0.52, to: 1.0, radius: r),
                   with: .color(Theme.pointer.opacity(0.9)), lineWidth: 3)

        // Minor ticks
        for i in 0...40 {
            let f = Double(i) / 40
            let outer = point(f, radius: r)
            let inner = point(f, radius: r - (i % 5 == 0 ? 12 : 6))
            var t = Path(); t.move(to: outer); t.addLine(to: inner)
            let red = f > 0.52
            ctx.stroke(t, with: .color(red ? Theme.pointer.opacity(0.85) : .black.opacity(0.7)),
                       lineWidth: f.truncatingRemainder(dividingBy: 0.13) < 0.02 ? 2 : 1)
        }

        // Labels
        for (text, frac, red) in sLabels {
            let p = point(frac, radius: r - 26)
            ctx.draw(Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(red ? Theme.pointer : .black.opacity(0.8)),
                     at: p)
        }

        // "S" marker and caption
        ctx.draw(Text("S").font(.system(size: 13, weight: .heavy, design: .serif))
            .foregroundStyle(.black.opacity(0.7)),
                 at: point(0.0, radius: r - 46))
        ctx.draw(Text("SIGNAL").font(.system(size: 9, weight: .semibold, design: .serif))
            .foregroundStyle(.black.opacity(0.45)),
                 at: CGPoint(x: size.width / 2, y: size.height * 0.66))
    }
}

/// A thin tapered needle pointing up from a bottom pivot.
private struct MeterNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        let pivot = CGPoint(x: rect.midX, y: rect.height * 0.9)
        let tip = CGPoint(x: rect.midX, y: rect.height * 0.9 - rect.height * 0.72)
        let w: CGFloat = 3
        var p = Path()
        p.move(to: CGPoint(x: pivot.x - w, y: pivot.y))
        p.addLine(to: CGPoint(x: tip.x - 0.6, y: tip.y))
        p.addLine(to: CGPoint(x: tip.x + 0.6, y: tip.y))
        p.addLine(to: CGPoint(x: pivot.x + w, y: pivot.y))
        p.closeSubpath()
        return p
    }
}
