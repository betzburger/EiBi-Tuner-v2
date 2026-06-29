//
//  TuningKnobView.swift
//  EiBi-Tuner
//
//  A knurled ivory tuning knob. Rotating it (drag around the centre) fine-tunes
//  FLRIG; ~0.5 kHz per degree. Coarse tuning is done by dragging the dial.
//

import SwiftUI

struct TuningKnobView: View {
    @Bindable var vm: RadioViewModel
    var size: CGFloat = 116
    var sensitivity: Double = 0.5 // kHz per degree

    @State private var rotation: Double = 0      // accumulated visual angle
    @State private var lastAngle: Double?
    @State private var knobFreq: Double?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Body
                Circle().fill(Theme.metalKnob)
                    .overlay(Circle().strokeBorder(.black.opacity(0.45), lineWidth: 2))
                    .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 4)

                // Knurled rim
                Canvas { ctx, s in
                    let c = CGPoint(x: s.width / 2, y: s.height / 2)
                    let rOuter = min(s.width, s.height) / 2 - 2
                    let rInner = rOuter - 9
                    for i in 0..<72 {
                        let a = Double(i) / 72 * 2 * .pi
                        var p = Path()
                        p.move(to: CGPoint(x: c.x + rInner * cos(a), y: c.y + rInner * sin(a)))
                        p.addLine(to: CGPoint(x: c.x + rOuter * cos(a), y: c.y + rOuter * sin(a)))
                        ctx.stroke(p, with: .color(.black.opacity(0.28)), lineWidth: 1.1)
                    }
                }

                // Inner cap
                Circle().fill(Theme.metalKnob).padding(18)
                    .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 1).padding(18))

                // Pointer dimple
                Circle().fill(.black.opacity(0.55))
                    .frame(width: 9, height: 9)
                    .offset(y: -size / 2 + 22)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let c = CGPoint(x: size / 2, y: size / 2)
                        let a = atan2(g.location.y - c.y, g.location.x - c.x)
                        if let last = lastAngle {
                            var d = a - last
                            if d > .pi { d -= 2 * .pi }
                            if d < -.pi { d += 2 * .pi }
                            let deg = d * 180 / .pi
                            rotation += deg
                            let base = knobFreq ?? vm.currentFreqKHz
                            let target = base + deg * sensitivity
                            knobFreq = target
                            vm.scrub(toKHz: target)
                        }
                        lastAngle = a
                    }
                    .onEnded { _ in
                        lastAngle = nil
                        knobFreq = nil
                        vm.tune(toKHz: vm.currentFreqKHz)
                    }
            )
            .onContinuousHover { phase in
                if case .active = phase { vm.hoverKnob = true } else { vm.hoverKnob = false }
            }

            Text("TUNING").font(Theme.label(10)).tracking(2)
                .foregroundStyle(Theme.ivory.opacity(0.7))
        }
    }
}
