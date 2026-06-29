//
//  StationStackView.swift
//  EiBi-Tuner
//
//  The legible counterpart to the dial: up to 10 nearby stations as backlit
//  rows. Grey-glowing row = on the dial frequency, amber-glowing = on the air
//  right now (ports the grey/yellow highlight rule of update_view_mode_display).
//  Click a row to tune FLRIG to it.
//

import SwiftUI

struct StationStackView: View {
    @Bindable var vm: RadioViewModel

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

            if vm.nearbyStations.isEmpty {
                Spacer()
                Text(vm.isLoading ? "Loading…" : "No stations")
                    .font(Theme.stationName(13))
                    .foregroundStyle(Theme.amber.opacity(0.5))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(vm.nearbyStations) { st in
                            StationRow(station: st, highlight: vm.highlight(for: st))
                                .onTapGesture { vm.tune(toKHz: st.freqKHz) }
                        }
                    }
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
}

private struct StationRow: View {
    let station: Station
    let highlight: RadioViewModel.Highlight

    private var tint: Color {
        switch highlight {
        case .active:      return Theme.activeGlow
        case .onFrequency: return .white
        case .normal:      return Theme.amber
        }
    }
    private var lit: Bool { highlight != .normal }

    var body: some View {
        HStack(spacing: 8) {
            Text(station.freqText)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .frame(width: 72, alignment: .trailing)

            VStack(alignment: .leading, spacing: 0) {
                Text(station.station.isEmpty ? "—" : station.station)
                    .font(Theme.stationName(13)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 10, design: .serif))
                        .opacity(0.75).lineLimit(1)
                }
            }
            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 0) {
                if !station.time.isEmpty {
                    Text(station.time).font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                if station.isActive(at: Date()) {
                    Text("ON AIR").font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(Theme.activeGlow).tracking(1)
                }
            }
        }
        .foregroundStyle(tint)
        .amberGlow(lit ? 5 : 0, color: tint)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.black.opacity(lit ? 0.5 : 0.22))
                .overlay(RoundedRectangle(cornerRadius: 6)
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
