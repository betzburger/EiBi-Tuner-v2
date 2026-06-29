//
//  ControlPanelView.swift
//  EiBi-Tuner
//
//  The lower fascia: frequency readout + UTC clock, mode / bandwidth selectors,
//  the "only active" pushbutton, target & search filters and the FLRIG
//  connection fields — all styled as engraved ivory controls on bakelite.
//

import SwiftUI

struct ControlPanelView: View {
    @Bindable var vm: RadioViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                readout
                Divider().frame(height: 46).overlay(Theme.brassDark)
                modeAndBandwidth
                Spacer()
                filters
            }
            HStack(spacing: 14) {
                PushButton(label: "ACTIVE", sublabel: "now", isOn: vm.activeOnly) {
                    vm.activeOnly.toggle()
                }
                connection
                Spacer()
                Button { vm.presentOpenPanel() } label: {
                    Label("Open Schedule…", systemImage: "folder")
                        .font(Theme.label(12))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.ivory)
                if let name = vm.loadedFileName {
                    Text(name).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.amberDim).lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cabinetPanel)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.black.opacity(0.4), lineWidth: 1))
        )
    }

    // MARK: Frequency readout + clock

    private var readout: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(freqString).font(Theme.readout)
                    .foregroundStyle(Theme.amberBright).amberGlow(8)
                Text("kHz").font(Theme.label(12)).foregroundStyle(Theme.amber.opacity(0.7))
            }
            HStack(spacing: 10) {
                IndicatorLamp(on: vm.rigOnline, color: Theme.activeGlow)
                Text(vm.rigOnline ? "FLRIG ONLINE" : "FLRIG OFFLINE")
                    .font(Theme.label(9)).tracking(1)
                    .foregroundStyle(vm.rigOnline ? Theme.activeGlow : Theme.amberDim)
                Text("UTC \(utcString)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.amber.opacity(0.8))
            }
        }
        .frame(minWidth: 230, alignment: .leading)
    }

    private var freqString: String {
        let f = vm.currentFreqKHz
        return f.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
    }
    private var utcString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: vm.utcNow)
    }

    // MARK: Mode + bandwidth

    private var modeAndBandwidth: some View {
        HStack(spacing: 14) {
            SelectControl(title: "MODE",
                          value: vm.mode,
                          options: vm.availableModes,
                          enabled: vm.rigOnline) { vm.setMode($0) }
            SelectControl(title: "BANDWIDTH",
                          value: vm.bandwidth,
                          options: vm.availableBandwidths,
                          enabled: vm.rigOnline) { vm.setBandwidth($0) }
            TapControl(title: "AGC",
                       value: vm.agcAvailable ? vm.agcLabel : "—",
                       enabled: vm.agcAvailable) { vm.cycleAGC() }
        }
    }

    // MARK: Filters

    private var filters: some View {
        HStack(spacing: 10) {
            RetroField(title: "TARGET", text: $vm.targetFilter, width: 90)
            RetroField(title: "SEARCH", text: $vm.searchText, width: 150)
        }
    }

    // MARK: Connection

    private var connection: some View {
        HStack(spacing: 6) {
            Text("FLRIG").font(Theme.label(10)).foregroundStyle(Theme.ivory.opacity(0.7))
            RetroField(title: "HOST", text: $vm.host, width: 110)
            RetroField(title: "PORT", text: $vm.port, width: 56)
        }
    }
}

// MARK: - Retro controls

/// An engraved ivory pushbutton that lights amber when on.
struct PushButton: View {
    let label: String
    var sublabel: String? = nil
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(label).font(Theme.label(12)).tracking(1)
                if let sublabel { Text(sublabel).font(.system(size: 8, design: .serif)).opacity(0.7) }
            }
            .foregroundStyle(isOn ? Color.black.opacity(0.85) : Theme.ivory.opacity(0.85))
            .frame(width: 64, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOn
                          ? LinearGradient(colors: [Theme.amberBright, Theme.amber],
                                           startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Theme.ivory.opacity(0.22), .black.opacity(0.3)],
                                           startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.black.opacity(0.4), lineWidth: 1))
                    .shadow(color: isOn ? Theme.amber.opacity(0.7) : .clear, radius: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A labelled selector backed by a Menu (used for mode & bandwidth).
struct SelectControl: View {
    let title: String
    let value: String
    let options: [String]
    var enabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(Theme.label(9)).tracking(1.5)
                .foregroundStyle(Theme.ivory.opacity(0.6))
            Menu {
                if options.isEmpty {
                    Text("No rig").font(.caption)
                } else {
                    ForEach(options, id: \.self) { opt in
                        Button(opt) { onSelect(opt) }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(value.isEmpty ? "—" : value)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.amberBright)
                    Image(systemName: "chevron.down").font(.system(size: 8))
                        .foregroundStyle(Theme.amber.opacity(0.6))
                }
                .frame(minWidth: 60)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.black.opacity(0.45))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.brassDark, lineWidth: 1)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!enabled || options.isEmpty)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

/// A labelled value that cycles on click (used for AGC).
struct TapControl: View {
    let title: String
    let value: String
    var enabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(Theme.label(9)).tracking(1.5)
                .foregroundStyle(Theme.ivory.opacity(0.6))
            Button(action: action) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.amberBright)
                    .frame(minWidth: 52)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.black.opacity(0.45))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Theme.brassDark, lineWidth: 1)))
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}

/// A dark inset text field with an engraved caption.
struct RetroField: View {
    let title: String
    @Binding var text: String
    var width: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(Theme.label(9)).tracking(1.5)
                .foregroundStyle(Theme.ivory.opacity(0.6))
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.amberBright)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .frame(width: width)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.black.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.brassDark, lineWidth: 1)))
        }
    }
}
