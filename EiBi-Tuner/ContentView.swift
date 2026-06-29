//
//  ContentView.swift
//  EiBi-Tuner
//
//  Assembles the radio cabinet: brand bar, the big tuning dial, the station
//  stack + S-meter + tuning knob, and the lower control fascia.
//

import SwiftUI

struct ContentView: View {
    @Bindable var vm: RadioViewModel

    var body: some View {
        ZStack {
            Theme.cabinet.ignoresSafeArea()
            woodGrain.ignoresSafeArea()

            VStack(spacing: 14) {
                BrandBar(vm: vm)

                DialScaleView(vm: vm)
                    .frame(height: 168)

                HStack(spacing: 14) {
                    StationStackView(vm: vm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 12) {
                        SMeterView(value: vm.smeter, online: vm.rigOnline)
                            .frame(width: 240)
                        HStack(spacing: 18) {
                            TuningKnobView(vm: vm, size: 98)
                            VolumeKnobView(vm: vm, size: 92)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                ControlPanelView(vm: vm)
            }
            .padding(22)
            .overlay(CabinetScrews())
        }
        .frame(minWidth: 960, minHeight: 840)
        .alert("Load error", isPresented: Binding(
            get: { vm.loadError != nil },
            set: { if !$0 { vm.loadError = nil } })) {
            Button("OK", role: .cancel) { vm.loadError = nil }
        } message: {
            Text(vm.loadError ?? "")
        }
    }

    private var woodGrain: some View {
        // Subtle vertical sheen + vignette over the bakelite.
        LinearGradient(colors: [.white.opacity(0.04), .clear, .black.opacity(0.35)],
                       startPoint: .top, endPoint: .bottom)
            .blendMode(.overlay)
    }
}

// MARK: - Brand bar

private struct BrandBar: View {
    @Bindable var vm: RadioViewModel

    private let bands = ["LW", "MW", "KW", "UKW"]

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.brassBezel)
                        .frame(width: 34, height: 34)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                }
                VStack(alignment: .leading, spacing: -2) {
                    Text("EiBi · Tuner").font(.system(size: 22, weight: .heavy, design: .serif))
                        .foregroundStyle(Theme.ivory)
                    Text("SHORTWAVE RECEIVER · DD2ZG").font(Theme.label(9)).tracking(2)
                        .foregroundStyle(Theme.amberDim)
                }
            }

            Spacer()

            // Decorative band selector strip (echoes the old set's pushbuttons).
            HStack(spacing: 6) {
                ForEach(bands, id: \.self) { b in
                    Text(b).font(Theme.label(11)).tracking(1)
                        .foregroundStyle(Theme.ivory.opacity(0.8))
                        .frame(width: 40, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(LinearGradient(colors: [Theme.ivory.opacity(0.18), .black.opacity(0.35)],
                                                     startPoint: .top, endPoint: .bottom))
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(.black.opacity(0.4), lineWidth: 1)))
                }
            }
        }
    }
}

// MARK: - Cabinet screws in the four corners

private struct CabinetScrews: View {
    var body: some View {
        VStack {
            HStack { Screw(); Spacer(); Screw() }
            Spacer()
            HStack { Screw(); Spacer(); Screw() }
        }
        .allowsHitTesting(false)
    }
}
