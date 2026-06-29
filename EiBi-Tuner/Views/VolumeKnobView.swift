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

    private var enabled: Bool { vm.volumeAvailable }
    private var angle: Double { -sweep / 2 + (vm.volume / 100) * sweep }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
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
                    .offset(y: -size / 2 + 16)
                    .rotationEffect(.degrees(angle))
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

    /// Maps a touch point to a 0…100 value along the knob's arc.
    private func value(at p: CGPoint) -> Double {
        let c = size / 2
        // Angle measured from straight up, clockwise positive.
        var deg = atan2(p.x - c, -(p.y - c)) * 180 / .pi
        deg = min(max(deg, -sweep / 2), sweep / 2)
        return (deg + sweep / 2) / sweep * 100
    }
}
