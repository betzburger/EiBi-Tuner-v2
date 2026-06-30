//
//  BandPickerView.swift
//  EiBi-Tuner
//
//  The pop-up shown by the BAND button: the shortwave meter bands laid out as
//  backlit chips, split into Rundfunk (broadcast, amber) and Amateurfunk
//  (amateur, phosphor-green). Tapping a chip jumps the dial to that band.
//

import SwiftUI

struct BandPickerView: View {
    @Bindable var vm: RadioViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            section(title: AppLanguage.t("Rundfunk · Broadcast", "Broadcast"),
                    bands: Band.broadcast,
                    tint: Theme.amber)

            section(title: AppLanguage.t("Amateurfunk · Amateur Radio", "Amateur Radio"),
                    bands: Band.amateur,
                    tint: BandPickerView.amateurTint)

            legend
        }
        .padding(18)
        .frame(width: 460)
        .background(Theme.cabinet)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "dial.medium")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.amberBright)
            VStack(alignment: .leading, spacing: -1) {
                Text(AppLanguage.t("BÄNDER", "BANDS")).font(Theme.label(15)).tracking(2)
                    .foregroundStyle(Theme.ivory)
                Text(AppLanguage.t("Meterband wählen", "Select a meter band"))
                    .font(Theme.label(9)).tracking(1)
                    .foregroundStyle(Theme.amberDim)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ivory.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private func section(title: String, bands: [Band], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(Theme.label(10)).tracking(1.5)
                .foregroundStyle(tint.opacity(0.9))
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(bands) { band in
                    BandChip(band: band, tint: tint) {
                        vm.tuneToBand(band)
                        dismiss()
                    }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(Theme.amber, AppLanguage.t("Rundfunk", "Broadcast"))
            legendDot(BandPickerView.amateurTint, AppLanguage.t("Amateurfunk", "Amateur Radio"))
            Spacer()
        }
        .padding(.top, 2)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 9, design: .serif))
                .foregroundStyle(Theme.ivory.opacity(0.6))
        }
    }

    /// Phosphor green used to set amateur bands apart from broadcast amber.
    static let amateurTint = Color(red: 0.42, green: 0.86, blue: 0.58)
}

// MARK: - Band chip

private struct BandChip: View {
    let band: Band
    let tint: Color
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(band.name)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                Text(band.rangeText)
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.ivory.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.black.opacity(hovering ? 0.25 : 0.45))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(tint.opacity(hovering ? 0.9 : 0.45), lineWidth: 1))
                    .shadow(color: hovering ? tint.opacity(0.6) : .clear, radius: 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
