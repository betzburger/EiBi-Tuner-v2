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

    // Tube warm-up: 0 = cold/off, 1 = fully lit. The brand bar (with the power
    // switch) stays lit; only the instrument below it dims and warms up.
    @State private var warmth = 0.0
    @State private var powerOn = true
    @State private var didWarmUp = false

    var body: some View {
        ZStack {
            Theme.cabinet.ignoresSafeArea()
            woodGrain.ignoresSafeArea()

            VStack(spacing: 14) {
                BrandBar(vm: vm, powerOn: powerOn, onPower: togglePower)

                instrument
                    .overlay(
                        Color.black
                            .opacity((1 - warmth) * 0.9)
                            .cornerRadius(8)
                            .allowsHitTesting(!powerOn))
            }
            .padding(22)
            .overlay(CabinetScrews())
        }
        // Re-render the whole cabinet when the colour variant changes so every
        // view (including purely decorative ones) picks up the new palette.
        .id(vm.themeVariant)
        .onAppear { if !didWarmUp { didWarmUp = true; warmUp() } }
        .frame(minWidth: 960, minHeight: 840)
        .alert("Load error", isPresented: Binding(
            get: { vm.loadError != nil },
            set: { if !$0 { vm.loadError = nil } })) {
            Button("OK", role: .cancel) { vm.loadError = nil }
        } message: {
            Text(vm.loadError ?? "")
        }
    }

    /// Everything below the brand bar — the part that warms up / dims.
    private var instrument: some View {
        VStack(spacing: 14) {
            DialScaleView(vm: vm)
                .frame(height: 168)

            HStack(spacing: 14) {
                StationStackView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 10) {
                    Group {
                        if vm.meterStyle == .magicEye {
                            MagicEyeView(value: vm.smeter, online: vm.rigOnline)
                        } else {
                            SMeterView(value: vm.smeter, online: vm.rigOnline)
                        }
                    }
                    .frame(width: 240)
                    MeterToggle(vm: vm)
                    HStack(spacing: 18) {
                        TuningKnobView(vm: vm, size: 98)
                        VolumeKnobView(vm: vm, size: 92)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            ControlPanelView(vm: vm)
        }
    }

    // MARK: Power / warm-up

    private func togglePower() {
        powerOn.toggle()
        if powerOn {
            warmUp()
        } else {
            withAnimation(.easeIn(duration: 0.7)) { warmth = 0 }
        }
    }

    /// Flickers the backlight a few times like a filament catching, then settles
    /// to a steady glow.
    private func warmUp() {
        warmth = 0
        Task {
            for v in [0.22, 0.06, 0.42, 0.16, 0.7] {
                withAnimation(.easeInOut(duration: 0.07)) { warmth = v }
                try? await Task.sleep(for: .milliseconds(85))
            }
            withAnimation(.easeOut(duration: 1.1)) { warmth = 1 }
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
    let powerOn: Bool
    let onPower: () -> Void

    private let quickModes = ["USB", "LSB", "AM", "CW"]

    var body: some View {
        HStack(alignment: .center) {
            PowerSwitch(on: powerOn, action: onPower)
                .padding(.trailing, 12)

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
                    HStack(spacing: 6) {
                        Text("SHORTWAVE RECEIVER").font(Theme.label(9)).tracking(2)
                            .foregroundStyle(Theme.amberDim)
                        Text("· v2.0 · DD2ZG")
                            .font(.system(size: 8, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.amberDim.opacity(0.7))
                    }
                }
            }

            Spacer()

            ThemeMenu(vm: vm)
                .padding(.trailing, 10)

            // Quick mode buttons (replace the old decorative band strip).
            HStack(spacing: 6) {
                ForEach(quickModes, id: \.self) { m in
                    ModeButton(label: m,
                               isActive: vm.isQuickModeActive(m),
                               enabled: vm.modeAvailable(m)) { vm.selectQuickMode(m) }
                }
            }
        }
    }
}

/// A retro illuminated power switch with a pilot lamp.
private struct PowerSwitch: View {
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(on ? Theme.amberBright : Theme.ivory.opacity(0.45))
                Circle()
                    .fill(on ? Theme.activeGlow : Color.black.opacity(0.55))
                    .frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 0.5))
                    .shadow(color: on ? Theme.activeGlow.opacity(0.9) : .clear, radius: 4)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Theme.brassDark, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .help(on ? "Power off" : "Power on")
    }
}

/// A small palette menu (brand bar) for picking the colour variant.
private struct ThemeMenu: View {
    @Bindable var vm: RadioViewModel

    var body: some View {
        Menu {
            Picker("Theme", selection: $vm.themeVariant) {
                ForEach(ThemeVariant.allCases) { v in
                    Text(v.label).tag(v)
                }
            }
        } label: {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .frame(width: 34, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.black.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Theme.brassDark, lineWidth: 1)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Colour variant")
    }
}

/// A compact two-segment switch toggling the S-meter ↔ magic-eye indicator.
private struct MeterToggle: View {
    @Bindable var vm: RadioViewModel

    var body: some View {
        HStack(spacing: 4) {
            segment("S-METER", .sMeter)
            segment("EYE", .magicEye)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.black.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Theme.brassDark, lineWidth: 1)))
    }

    private func segment(_ label: String, _ style: MeterStyle) -> some View {
        let on = vm.meterStyle == style
        return Text(label)
            .font(Theme.label(9)).tracking(1)
            .foregroundStyle(on ? Color.black.opacity(0.85) : Theme.ivory.opacity(0.7))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(on
                          ? AnyShapeStyle(LinearGradient(colors: [Theme.amberBright, Theme.amber],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.clear)))
            .contentShape(Rectangle())
            .onTapGesture { vm.meterStyle = style }
    }
}

/// A compact lit mode button for the brand bar.
private struct ModeButton: View {
    let label: String
    let isActive: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).font(Theme.label(11)).tracking(1)
                .foregroundStyle(isActive ? Color.black.opacity(0.85) : Theme.ivory.opacity(0.85))
                .frame(width: 44, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isActive
                              ? LinearGradient(colors: [Theme.amberBright, Theme.amber],
                                               startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [Theme.ivory.opacity(0.18), .black.opacity(0.35)],
                                               startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.black.opacity(0.4), lineWidth: 1))
                        .shadow(color: isActive ? Theme.amber.opacity(0.7) : .clear, radius: 5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
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
