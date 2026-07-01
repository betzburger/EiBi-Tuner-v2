//
//  FrequencyReadoutView.swift
//  EiBi-Tuner
//
//  The big amber frequency display, made interactive:
//   • double-click to type a frequency by hand,
//   • hover over a digit to reveal up/down arrows that step that digit by its
//     place value (1000s, 100s … 0.01),
//   • scroll the mouse wheel over a digit for the same step.
//

import SwiftUI

struct FrequencyReadoutView: View {
    @Bindable var vm: RadioViewModel

    @State private var hoveredPlace: Double?
    @State private var editing = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        Group {
            if editing { editor } else { display }
        }
        .onChange(of: hoveredPlace) { _, place in vm.hoverFreqPlace = place }
        .onDisappear { vm.hoverFreqPlace = nil }
    }

    // MARK: Display (interactive digits)

    private var display: some View {
        HStack(alignment: .center, spacing: 6) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(digits.enumerated()), id: \.offset) { _, d in
                    if let place = d.place {
                        DigitColumn(
                            char: d.char,
                            hovered: hoveredPlace == place,
                            onHover: { inside in
                                if inside { hoveredPlace = place }
                                else if hoveredPlace == place { hoveredPlace = nil }
                            },
                            onStep: { dir in vm.tune(toKHz: vm.currentFreqKHz + dir * place) },
                            onEdit: { beginEdit() })
                    } else {
                        Text(d.char)
                            .font(Theme.readout)
                            .foregroundStyle(Theme.amberBright).amberGlow(8)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.18), value: d.char)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { beginEdit() }
                    }
                }
            }
            .help(AppLanguage.t("Doppelklick zum Eingeben · Mausrad/Pfeile zum Ändern",
                                "Double-click to type · wheel/arrows to change"))

            Text("kHz").font(Theme.label(12)).foregroundStyle(Theme.amber.opacity(0.7))
        }
    }

    // MARK: Manual entry

    private var editor: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .font(Theme.readout)
                .foregroundStyle(Theme.amberBright)
                .frame(width: 190)
                .focused($editFocused)
                .onSubmit { commitEdit() }
                .onExitCommand { editing = false }
            Text("kHz").font(Theme.label(12)).foregroundStyle(Theme.amber.opacity(0.7))
        }
        .onAppear { editFocused = true }
    }

    private func beginEdit() {
        editText = String(format: "%.2f", vm.currentFreqKHz)
        hoveredPlace = nil
        vm.hoverFreqPlace = nil
        editing = true
    }

    private func commitEdit() {
        vm.tuneToTypedFrequency(editText)
        editing = false
    }

    // MARK: Digit decomposition

    private struct Digit { let char: String; let place: Double? }

    private var digits: [Digit] { Self.decompose(vm.currentFreqKHz) }

    /// Splits a frequency into display characters, tagging each numeral with the
    /// kHz value a single step changes (separators get `nil`).
    private static func decompose(_ freq: Double) -> [Digit] {
        let grp = Locale.current.groupingSeparator ?? ","
        let dec = Locale.current.decimalSeparator ?? "."
        let totalCents = Int((max(0, freq) * 100).rounded())
        let whole = totalCents / 100
        let cents = totalCents % 100
        let wholeStr = String(whole)
        let n = wholeStr.count

        var out: [Digit] = []
        for (i, ch) in wholeStr.enumerated() {
            let placeExp = n - 1 - i           // 0 = ones, 1 = tens, …
            out.append(Digit(char: String(ch), place: pow(10.0, Double(placeExp))))
            if placeExp > 0 && placeExp % 3 == 0 {
                out.append(Digit(char: grp, place: nil))
            }
        }
        out.append(Digit(char: dec, place: nil))
        out.append(Digit(char: String(cents / 10), place: 0.1))
        out.append(Digit(char: String(cents % 10), place: 0.01))
        return out
    }
}

// MARK: - One interactive digit with its hover arrows

private struct DigitColumn: View {
    let char: String
    let hovered: Bool
    let onHover: (Bool) -> Void
    let onStep: (Double) -> Void   // +1 up, -1 down
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            arrow("chevron.up") { onStep(1) }
            // Double-click only on the digit glyph, so it never competes with
            // the arrow buttons above/below for their single clicks.
            Text(char)
                .font(Theme.readout)
                .foregroundStyle(Theme.amberBright).amberGlow(8)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.18), value: char)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onEdit() }
            arrow("chevron.down") { onStep(-1) }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(hovered ? Theme.amber.opacity(0.14) : .clear))
        .contentShape(Rectangle())
        .onHover { onHover($0) }
    }

    private func arrow(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.amber)
                // Roughly the digit's width and a tall band, so the whole area
                // is clickable (not just the thin glyph) without spacing digits.
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(hovered ? 1 : 0)
        .allowsHitTesting(hovered)
    }
}
