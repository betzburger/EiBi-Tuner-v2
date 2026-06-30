//
//  MagicEyeView.swift
//  EiBi-Tuner
//
//  A nostalgic "magic eye" tuning tube (à la EM34): two glowing green fans that
//  open from the centre, with dark shadow wedges at top and bottom that close
//  as the signal gets stronger. An alternative to the moving-coil S-meter,
//  selectable via the meter switch. The eye is always green, regardless of the
//  chosen colour variant — that's how these tubes looked.
//

import SwiftUI

struct MagicEyeView: View {
    /// 0…100, as FLRIG's get_smeter reports.
    var value: Double
    var online: Bool

    private let bright = Color(red: 0.50, green: 1.00, blue: 0.58)
    private let mid    = Color(red: 0.13, green: 0.82, blue: 0.33)
    private let deep   = Color(red: 0.02, green: 0.16, blue: 0.06)

    private var level: Double { online ? min(max(value, 0), 100) / 100 : 0 }
    /// Half-angle of each dark shadow wedge: wide (open) when weak, nearly
    /// closed when strong.
    private var gapHalf: Double { 6 + (1 - level) * 70 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.04, green: 0.10, blue: 0.05),
                             Color(red: 0.01, green: 0.035, blue: 0.02)],
                    startPoint: .top, endPoint: .bottom))

            eye.padding(14)

            GlassReflection(corner: 12)
            BrassBezel(corner: 14, line: 8)

            VStack {
                Spacer()
                Text(online ? "TUNE" : "NO RIG")
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundStyle(mid.opacity(0.55))
                    .padding(.bottom, 10)
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
    }

    private var eye: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                // Tube envelope
                Circle().fill(RadialGradient(
                    colors: [deep, .black],
                    center: .center, startRadius: 2, endRadius: d * 0.6))

                // The two glowing green fans (everything except the shadow wedges).
                EyeFans(gapHalf: gapHalf)
                    .fill(RadialGradient(
                        colors: [deep, mid, bright],
                        center: .center, startRadius: d * 0.05, endRadius: d * 0.5))
                    .overlay(
                        EyeFans(gapHalf: gapHalf)
                            .stroke(bright.opacity(0.9), lineWidth: 1.5))
                    .shadow(color: bright.opacity(0.6), radius: 6)
                    .animation(.easeOut(duration: 0.28), value: gapHalf)

                // Faint phosphor target ring
                Circle().strokeBorder(mid.opacity(0.25), lineWidth: 1)
                    .frame(width: d * 0.98, height: d * 0.98)

                // Central anode cap
                Circle().fill(.black)
                    .frame(width: d * 0.13, height: d * 0.13)
                    .overlay(Circle().strokeBorder(mid.opacity(0.5), lineWidth: 1))
            }
            .frame(width: d, height: d)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// Two opposing pie sectors (left + right) leaving dark shadow wedges at the
/// top and bottom; `gapHalf` is each shadow's half-angle in degrees.
private struct EyeFans: Shape {
    var gapHalf: Double
    var animatableData: Double {
        get { gapHalf }
        set { gapHalf = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        // Right fan (around 3 o'clock); top is -90°, bottom is +90°.
        p.move(to: c)
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(-90 + gapHalf),
                 endAngle: .degrees(90 - gapHalf), clockwise: false)
        p.closeSubpath()
        // Left fan (around 9 o'clock).
        p.move(to: c)
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(90 + gapHalf),
                 endAngle: .degrees(270 - gapHalf), clockwise: false)
        p.closeSubpath()
        return p
    }
}
