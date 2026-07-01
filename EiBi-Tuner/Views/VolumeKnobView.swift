//
//  VolumeKnobView.swift
//  EiBi-Tuner
//
//  Absolute rotary AF-gain knob (0…100) over a 270° sweep, driving FLRIG's
//  volume method. Greys out when the connected rig doesn't expose volume.
//

import SwiftUI

struct VolumeKnobView: View {
    @Bindable var vm: RadioViewModel
    var size: CGFloat = 96

    private let sweep = 270.0 // total degrees, -135 … +135
    private let scaleMargin: CGFloat = 9

    private var enabled: Bool { vm.volumeAvailable }
    private var angle: Double { -sweep / 2 + (vm.volume / 100) * sweep }
    private var knobSize: CGFloat { size - scaleMargin * 2 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Static faceplate scale — fixed reference ticks around the
                // knob, printed on the panel (doesn't rotate with the knob).
                Canvas { ctx, s in drawScale(ctx, s) }

                Group {
                    Circle().fill(Theme.metalKnob)
                        .overlay(Circle().strokeBorder(.black.opacity(0.45), lineWidth: 2))
                        .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 4)

                    Canvas { ctx, s in
                        let c = CGPoint(x: s.width / 2, y: s.height / 2)
                        let rOuter = min(s.width, s.height) / 2 - 2
                        let rInner = rOuter - 8
                        for i in 0..<60 {
                            let a = Double(i) / 60 * 2 * .pi
                            var p = Path()
                            p.move(to: CGPoint(x: c.x + rInner * cos(a), y: c.y + rInner * sin(a)))
                            p.addLine(to: CGPoint(x: c.x + rOuter * cos(a), y: c.y + rOuter * sin(a)))
                            ctx.stroke(p, with: .color(.black.opacity(0.28)), lineWidth: 1)
                        }
                    }

                    Circle().fill(Theme.metalKnob).padding(16)
                        .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 1).padding(16))

                    // Position marker
                    Capsule().fill(enabled ? Theme.amberDeep : .black.opacity(0.4))
                        .frame(width: 4, height: 14)
                        .offset(y: -knobSize / 2 + 16)
                        .rotationEffect(.degrees(angle))
                }
                .padding(scaleMargin)
            }
            .frame(width: size, height: size)
            .opacity(enabled ? 1 : 0.5)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard enabled else { return }
                        vm.setVolume(value(at: g.location))
                    }
                    .onEnded { g in
                        guard enabled else { return }
                        vm.setVolume(value(at: g.location), commit: true)
                    }
            )

            Text(enabled ? "VOLUME \(Int(vm.volume))" : "VOLUME")
                .font(Theme.label(10)).tracking(1.5)
                .foregroundStyle(Theme.ivory.opacity(enabled ? 0.8 : 0.4))
        }
    }

    /// Fixed tick marks (0…10) printed on the panel around the knob — the
    /// physical reference the rotating position marker points at.
    private func drawScale(_ ctx: GraphicsContext, _ s: CGSize) {
        let c = CGPoint(x: s.width / 2, y: s.height / 2)
        let rOuter = min(s.width, s.height) / 2 - 1
        let rInner = rOuter - 5
        let count = 11
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            let a = (-sweep / 2 + t * sweep) * .pi / 180
            let outer = CGPoint(x: c.x + rOuter * sin(a), y: c.y - rOuter * cos(a))
            let inner = CGPoint(x: c.x + rInner * sin(a), y: c.y - rInner * cos(a))
            var p = Path(); p.move(to: outer); p.addLine(to: inner)
            let major = i == 0 || i == count - 1 || i % 5 == 0
            ctx.stroke(p, with: .color(Theme.ivory.opacity(enabled ? (major ? 0.6 : 0.32) : 0.2)),
                       lineWidth: major ? 1.4 : 1)
        }
    }

    /// Maps a touch point to a 0…100 value along the knob's arc.
    private func value(at p: CGPoint) -> Double {
        let c = size / 2
        // Angle measured from straight up, clockwise positive.
        var deg = atan2(p.x - c, -(p.y - c)) * 180 / .pi
        deg = min(max(deg, -sweep / 2), sweep / 2)
        return (deg + sweep / 2) / sweep * 100
    }
}
