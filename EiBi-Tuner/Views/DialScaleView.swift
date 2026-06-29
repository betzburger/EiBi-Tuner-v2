//
//  DialScaleView.swift
//  EiBi-Tuner
//
//  The hero: a big amber-backlit tuning scale. A frequency ruler scrolls under
//  a fixed red center index as you tune; up to 10 nearby stations are drawn as
//  staggered call-out plates along the scale. Drag to tune FLRIG (two-way),
//  or click a plate to jump to it.
//

import SwiftUI

struct DialScaleView: View {
    @Bindable var vm: RadioViewModel
    @State private var dragStartFreq: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let span = visibleSpan
            let lo = vm.currentFreqKHz - span / 2
            let layout = stagger(in: CGSize(width: w, height: h), lo: lo, span: span)

            ZStack {
                // Backlit glass
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.dialBackdrop)
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.amberLamp)
                    .blur(radius: 8)

                // Ruler
                Canvas { ctx, size in drawRuler(ctx, size: size, lo: lo, span: span) }

                // Leader lines + station plates
                ForEach(layout) { item in
                    Path { p in
                        p.move(to: CGPoint(x: item.tickX, y: h * 0.30))
                        p.addLine(to: CGPoint(x: item.point.x, y: item.point.y - 9))
                    }
                    .stroke(item.tint.opacity(0.45), lineWidth: 1)

                    StationPlate(station: item.station, highlight: item.highlight, tint: item.tint)
                        .position(item.point)
                        .onTapGesture { vm.tune(toKHz: item.station.freqKHz) }
                }

                // Fixed center index
                CenterIndex().frame(width: 26).position(x: w / 2, y: h / 2)

                GlassReflection(corner: 14)
                BrassBezel(corner: 18, line: 11)

                if vm.stations.isEmpty {
                    Text("Open an EIBI or ILG schedule  ·  File ▸ Open…")
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.amber.opacity(0.8))
                        .amberGlow()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { g in
                        let start = dragStartFreq ?? vm.currentFreqKHz
                        if dragStartFreq == nil { dragStartFreq = start }
                        let delta = Double(g.translation.width / w) * span
                        vm.scrub(toKHz: start + delta)
                    }
                    .onEnded { _ in
                        dragStartFreq = nil
                        vm.endTuneGesture()
                    }
            )
            .onContinuousHover { phase in
                if case .active = phase { vm.hoverDial = true } else { vm.hoverDial = false }
            }
        }
    }

    // MARK: - Visible span (adapts so all nearby plates fit)

    private var visibleSpan: Double {
        let base = max(40, min(vm.currentFreqKHz * 0.06, 400))
        let farthest = vm.nearbyStations
            .map { abs($0.freqKHz - vm.currentFreqKHz) }.max() ?? 0
        return min(max(base, farthest * 2.3), 2000)
    }

    // MARK: - Ruler drawing

    private func drawRuler(_ ctx: GraphicsContext, size: CGSize, lo: Double, span: Double) {
        let w = size.width, h = size.height
        let baseY = h * 0.30
        func x(_ f: Double) -> CGFloat { CGFloat((f - lo) / span) * w }

        // Baseline
        var line = Path()
        line.move(to: CGPoint(x: 0, y: baseY)); line.addLine(to: CGPoint(x: w, y: baseY))
        ctx.stroke(line, with: .color(Theme.amber.opacity(0.55)), lineWidth: 1.5)

        let minor = niceStep(span / 14)
        let major = minor * 5
        var f = (lo / minor).rounded(.down) * minor
        while f <= lo + span {
            if f >= lo {
                let isMajor = abs(f.truncatingRemainder(dividingBy: major)) < minor * 0.25
                    || abs(f.truncatingRemainder(dividingBy: major) - major) < minor * 0.25
                let len: CGFloat = isMajor ? 14 : 7
                var t = Path()
                t.move(to: CGPoint(x: x(f), y: baseY))
                t.addLine(to: CGPoint(x: x(f), y: baseY - len))
                ctx.stroke(t, with: .color(Theme.amber.opacity(isMajor ? 0.95 : 0.5)),
                           lineWidth: isMajor ? 1.6 : 1)
                if isMajor {
                    ctx.draw(Text(freqLabel(f))
                        .font(Theme.dialNumber(13))
                        .foregroundStyle(Theme.amberBright),
                             at: CGPoint(x: x(f), y: baseY - 24))
                }
            }
            f += minor
        }
    }

    private func freqLabel(_ kHz: Double) -> String {
        if kHz >= 10_000 { return String(format: "%.1f", kHz / 1000) + "M" }
        if kHz >= 1_000 { return String(format: "%g", kHz) }
        return String(format: "%g", kHz)
    }

    /// Rounds to a "nice" 1/2/5 × 10ⁿ step.
    private func niceStep(_ raw: Double) -> Double {
        guard raw > 0 else { return 1 }
        let exp = floor(log10(raw))
        let base = pow(10, exp)
        let frac = raw / base
        let nice: Double = frac < 1.5 ? 1 : (frac < 3.5 ? 2 : (frac < 7.5 ? 5 : 10))
        return nice * base
    }

    // MARK: - Plate stagger packing

    private struct PlateItem: Identifiable {
        let id: UUID
        let station: Station
        let point: CGPoint
        let tickX: CGFloat
        let highlight: RadioViewModel.Highlight
        let tint: Color
    }

    private func stagger(in size: CGSize, lo: Double, span: Double) -> [PlateItem] {
        let w = size.width, h = size.height
        func x(_ f: Double) -> CGFloat { CGFloat((f - lo) / span) * w }

        let topY = h * 0.42
        let laneH: CGFloat = 30
        let maxLanes = max(1, Int((h - topY) / laneH))
        var laneRight = [CGFloat]()

        var items: [PlateItem] = []
        for st in vm.nearbyStations.sorted(by: { $0.freqKHz < $1.freqKHz }) {
            let px = min(max(x(st.freqKHz), 8), w - 8)
            let plateW = min(max(CGFloat(st.station.count) * 6.5 + 44, 90), 220)
            let leftEdge = px - plateW / 2

            var lane = laneRight.firstIndex(where: { $0 + 10 <= leftEdge }) ?? -1
            if lane == -1 {
                if laneRight.count < maxLanes { laneRight.append(px + plateW / 2); lane = laneRight.count - 1 }
                else { lane = (laneRight.count - 1); laneRight[lane] = px + plateW / 2 }
            } else {
                laneRight[lane] = px + plateW / 2
            }

            let hl = vm.highlight(for: st)
            items.append(PlateItem(
                id: st.id, station: st,
                point: CGPoint(x: px, y: topY + CGFloat(lane) * laneH + 12),
                tickX: x(st.freqKHz),
                highlight: hl, tint: tint(for: hl)))
        }
        return items
    }

    private func tint(for hl: RadioViewModel.Highlight) -> Color {
        switch hl {
        case .active:      return Theme.activeGlow
        case .onFrequency: return .white
        case .normal:      return Theme.amber.opacity(0.85)
        }
    }
}

// MARK: - Station call-out plate

private struct StationPlate: View {
    let station: Station
    let highlight: RadioViewModel.Highlight
    let tint: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(station.station.isEmpty ? "—" : station.station)
                .font(Theme.stationName(12))
                .lineLimit(1)
            Text(station.freqText)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .opacity(0.85)
        }
        .foregroundStyle(tint)
        .amberGlow(highlight == .normal ? 3 : 7, color: tint)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(.black.opacity(highlight == .normal ? 0.25 : 0.45))
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(tint.opacity(highlight == .normal ? 0.25 : 0.7), lineWidth: 1))
        )
        .scaleEffect(highlight == .active ? 1.06 : 1)
        .animation(.easeOut(duration: 0.25), value: highlight)
    }
}

// MARK: - Fixed red center index

private struct CenterIndex: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle().fill(Theme.pointer)
                    .frame(width: 2)
                    .shadow(color: Theme.pointer.opacity(0.9), radius: 4)
                Triangle().fill(Theme.pointer)
                    .frame(width: 14, height: 9)
                    .position(x: geo.size.width / 2, y: 5)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
