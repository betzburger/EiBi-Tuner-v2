//
//  StationStackView.swift
//  EiBi-Tuner
//
//  The legible counterpart to the dial: every station in the loaded schedule,
//  one single-line row each, freely scrollable across the whole spectrum.
//  White-glowing row = on the dial frequency, amber/yellow-glowing = on the
//  air right now (ports the grey/yellow highlight rule of
//  update_view_mode_display). Click a row to tune FLRIG to it; the list
//  auto-scrolls to whichever station sits closest to the dial frequency.
//

import SwiftUI

struct StationStackView: View {
    @Bindable var vm: RadioViewModel
    @State private var centeredStationID: Station.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("STATIONS").font(Theme.label(11)).tracking(2)
                    .foregroundStyle(Theme.amber.opacity(0.8))
                Spacer()
                if let t = vm.fileType {
                    Text(t.rawValue).font(Theme.label(10))
                        .foregroundStyle(Theme.amberDim)
                }
            }
            .padding(.horizontal, 4)

            if vm.displayedStations.isEmpty {
                Spacer()
                Text(vm.isLoading ? "Loading…" : "No stations")
                    .font(Theme.stationName(13))
                    .foregroundStyle(Theme.amber.opacity(0.5))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 2) {
                            ForEach(vm.displayedStations) { st in
                                StationRow(station: st, highlight: vm.highlight(for: st))
                                    .id(st.id)
                                    .onTapGesture { vm.tune(toKHz: st.freqKHz) }
                            }
                        }
                    }
                    .onAppear { centerOnCurrent(proxy, animated: false) }
                    .onChange(of: vm.currentFreqKHz) { _, _ in centerOnCurrent(proxy) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.dialBackdrop)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.amberLamp).blur(radius: 10))
        )
        .overlay(GlassReflection(corner: 12))
        .overlay(BrassBezel(corner: 14, line: 8))
    }

    /// Scrolls to whichever station is closest to the dial frequency, but
    /// only when that target actually changes — skips redundant scrollTo
    /// calls while the dial is continuously dragged within one station's span.
    private func centerOnCurrent(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let nearest = vm.nearestStation(toKHz: vm.currentFreqKHz),
              nearest.id != centeredStationID else { return }
        centeredStationID = nearest.id
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(nearest.id, anchor: .center) }
        } else {
            proxy.scrollTo(nearest.id, anchor: .center)
        }
    }
}

private struct StationRow: View {
    let station: Station
    let highlight: RadioViewModel.Highlight

    private var tint: Color {
        switch highlight {
        case .active:      return Theme.onAirYellow
        case .onFrequency: return .white
        case .normal:      return Theme.amber
        }
    }
    private var lit: Bool { highlight != .normal }

    var body: some View {
        HStack(spacing: 8) {
            Text(station.freqText)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 66, alignment: .trailing)

            Text(station.station.isEmpty ? "—" : station.station)
                .font(Theme.stationName(12)).lineLimit(1)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10, design: .serif))
                    .opacity(0.65).lineLimit(1)
            }

            Spacer(minLength: 4)

            if !station.time.isEmpty {
                Text(station.time)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .opacity(0.85)
            }
            if station.isActive(at: Date()) {
                Text("ON AIR").font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(Theme.onAirYellow).tracking(1)
            }
        }
        .foregroundStyle(tint)
        .amberGlow(lit ? 4 : 0, color: tint)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(.black.opacity(lit ? 0.5 : 0.22))
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(tint.opacity(lit ? 0.7 : 0.18), lineWidth: 1))
        )
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var bits: [String] = []
        if !station.itu.isEmpty { bits.append(station.itu) }
        if !station.language.isEmpty { bits.append(station.language) }
        if !station.target.isEmpty { bits.append(station.target) }
        return bits.joined(separator: " · ")
    }
}
