//
//  PresetPickerView.swift
//  EiBi-Tuner
//
//  The pop-up shown by the PRESET button: a grid of freely-assignable memory
//  slots. Tap a slot to recall it; press and hold for two seconds — a bar
//  fills upward inside the button — to store the current frequency, after
//  which the slot blinks to confirm. Each slot can be renamed.
//

import SwiftUI

struct PresetPickerView: View {
    @Bindable var vm: RadioViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(vm.presets.indices), id: \.self) { i in
                    PresetButton(vm: vm, index: i, dismiss: { dismiss() })
                }
            }
            footer
        }
        .padding(18)
        .frame(width: 520)
        .background(Theme.cabinet)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.amberBright)
            VStack(alignment: .leading, spacing: -1) {
                Text("PRESETS").font(Theme.label(15)).tracking(2)
                    .foregroundStyle(Theme.ivory)
                Text(AppLanguage.t("Eigene Frequenzen", "Your frequencies"))
                    .font(Theme.label(9)).tracking(1)
                    .foregroundStyle(Theme.amberDim)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: -1) {
                Text(AppLanguage.t("AKTUELL", "CURRENT")).font(Theme.label(8)).tracking(1.5)
                    .foregroundStyle(Theme.ivory.opacity(0.5))
                Text("\(currentFreqText) kHz")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.amberBright)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ivory.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 9)).foregroundStyle(Theme.amberDim)
            Text(AppLanguage.t(
                "Tippen = abrufen · 2 s halten = aktuelle Frequenz speichern · Rechtsklick = löschen",
                "Tap = recall · Hold 2 s = store current frequency · Right-click = delete"))
                .font(.system(size: 9, design: .serif))
                .foregroundStyle(Theme.ivory.opacity(0.55))
            Spacer()
        }
    }

    private var currentFreqText: String {
        vm.currentFreqKHz.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
    }
}

// MARK: - One preset slot (name field + hold-to-save button)

private struct PresetButton: View {
    @Bindable var vm: RadioViewModel
    let index: Int
    let dismiss: () -> Void

    private let holdDuration: Double = 2.0
    private let areaHeight: CGFloat = 44

    @State private var progress: CGFloat = 0   // 0…1 fill while holding
    @State private var pressing = false
    @State private var justSaved = false        // suppress recall on the release after a save
    @State private var blink = false
    @State private var pressStart = Date()
    @State private var holdTask: Task<Void, Never>?
    @State private var blinkTask: Task<Void, Never>?

    private var preset: FrequencyPreset { vm.presets[index] }
    private var filled: Bool { preset.freqKHz != nil }
    private var tint: Color { filled ? Theme.amber : Theme.ivory }

    var body: some View {
        VStack(spacing: 4) {
            TextField("P\(index + 1)", text: $vm.presets[index].name)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ivory.opacity(0.9))
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.black.opacity(0.4))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Theme.brassDark, lineWidth: 1)))

            pressArea
        }
    }

    private var pressArea: some View {
        ZStack(alignment: .bottom) {
            // Fill that rises while holding.
            Rectangle()
                .fill(LinearGradient(colors: [Theme.amber, Theme.amberBright],
                                     startPoint: .bottom, endPoint: .top))
                .frame(height: areaHeight * progress)
                .opacity(0.55)

            VStack(spacing: 1) {
                if filled {
                    Text(preset.freqText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text(preset.mode ?? "—")
                        .font(.system(size: 8, weight: .semibold)).tracking(1)
                        .opacity(0.7)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                    Text(AppLanguage.t("frei", "empty"))
                        .font(.system(size: 8, design: .serif)).opacity(0.7)
                }
            }
            .foregroundStyle(blink ? Color.black.opacity(0.85) : tint.opacity(filled ? 1 : 0.55))
        }
        .frame(maxWidth: .infinity)
        .frame(height: areaHeight)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(blink ? Theme.amberBright : Color.black.opacity(0.45))
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(tint.opacity(filled ? 0.7 : 0.35), lineWidth: 1)
        )
        .shadow(color: blink ? Theme.amber.opacity(0.9) : .clear, radius: 8)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHold() }
                .onEnded { _ in endHold() }
        )
        .contextMenu {
            if filled {
                Button(role: .destructive) { vm.clearPreset(at: index) } label: {
                    Label(AppLanguage.t("Löschen", "Delete"), systemImage: "trash")
                }
            }
            Button { vm.savePreset(at: index) } label: {
                Label(AppLanguage.t("Aktuelle Frequenz speichern", "Save current frequency"),
                      systemImage: "square.and.arrow.down")
            }
        }
    }

    // MARK: Press / hold logic

    private func beginHold() {
        guard !pressing, !justSaved else { return }
        pressing = true
        pressStart = Date()
        holdTask?.cancel()
        withAnimation(.linear(duration: holdDuration)) { progress = 1 }
        holdTask = Task {
            try? await Task.sleep(for: .seconds(holdDuration))
            if !Task.isCancelled { completeSave() }
        }
    }

    private func endHold() {
        holdTask?.cancel(); holdTask = nil
        let wasHolding = pressing
        let heldFor = Date().timeIntervalSince(pressStart)
        pressing = false

        if justSaved { justSaved = false; return }   // the save already happened

        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
        // A quick tap on a filled slot recalls it; a longer (but < 2 s) hold is
        // treated as an aborted save and does nothing.
        if wasHolding, heldFor < 0.35, filled {
            vm.recallPreset(at: index)
            dismiss()
        }
    }

    private func completeSave() {
        guard pressing else { return }
        pressing = false
        justSaved = true
        vm.savePreset(at: index)

        blinkTask?.cancel()
        blinkTask = Task {
            for _ in 0..<3 {
                blink = true
                try? await Task.sleep(for: .milliseconds(130))
                blink = false
                try? await Task.sleep(for: .milliseconds(110))
            }
            withAnimation(.easeOut(duration: 0.35)) { progress = 0 }
        }
    }
}
