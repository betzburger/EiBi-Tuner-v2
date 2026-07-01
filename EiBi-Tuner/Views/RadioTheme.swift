//
//  RadioTheme.swift
//  EiBi-Tuner
//
//  Shared palette, gradients and reusable "hardware" pieces (bezel, glass
//  reflection, cabinet screws) that give every view the same backlit
//  valve-radio look. Two cabinets are available (RadioViewModel.themeVariant):
//  a warm amber-backlit wood cabinet with brass trim, and a cool blue-backlit
//  brushed-metal cabinet with silver trim.
//

import SwiftUI

/// The interchangeable part of the look: the accent ("backlight") colour family
/// and the dial glow.
nonisolated struct ThemePalette: Sendable {
    let amber, amberBright, amberDeep, amberDim, activeGlow: Color

    var lamp: RadialGradient {
        RadialGradient(colors: [amber.opacity(0.55), amberDeep.opacity(0.18), .clear],
                       center: .center, startRadius: 2, endRadius: 360)
    }
}

extension ThemePalette {
    static let amber = ThemePalette(
        amber:       Color(red: 1.00, green: 0.69, blue: 0.31),
        amberBright: Color(red: 1.00, green: 0.86, blue: 0.58),
        amberDeep:   Color(red: 0.80, green: 0.43, blue: 0.13),
        amberDim:    Color(red: 0.62, green: 0.36, blue: 0.12),
        activeGlow:  Color(red: 1.00, green: 0.82, blue: 0.30))

    static let blue = ThemePalette(
        amber:       Color(red: 0.40, green: 0.74, blue: 1.00),
        amberBright: Color(red: 0.72, green: 0.89, blue: 1.00),
        amberDeep:   Color(red: 0.13, green: 0.40, blue: 0.72),
        amberDim:    Color(red: 0.26, green: 0.46, blue: 0.70),
        activeGlow:  Color(red: 0.56, green: 0.86, blue: 1.00))
}

/// User-selectable cabinet variants (persisted; see RadioViewModel.themeVariant).
/// Each bundles an accent colour family with a cabinet material: wood cabinet
/// + brass trim + amber backlight, or brushed-metal cabinet + silver trim +
/// blue backlight.
nonisolated enum ThemeVariant: String, CaseIterable, Identifiable, Sendable {
    case wood, metal
    var id: String { rawValue }

    var palette: ThemePalette {
        switch self {
        case .wood:  return .amber
        case .metal: return .blue
        }
    }

    var label: String {
        switch self {
        case .wood:  return AppLanguage.t("Holz", "Wood")
        case .metal: return AppLanguage.t("Metall", "Metal")
        }
    }

    /// Cabinet background texture asset name.
    var cabinetImageName: String {
        switch self {
        case .wood:  return "OakGrain"
        case .metal: return "BrushedMetal"
        }
    }

    /// Bezel/trim gradient around dials and panels: brass for the wood
    /// cabinet, brushed silver for the metal one.
    var bezel: LinearGradient {
        switch self {
        case .wood:
            return LinearGradient(colors: [
                Color(red: 0.88, green: 0.76, blue: 0.46),
                Color(red: 0.55, green: 0.43, blue: 0.21),
                Color(red: 0.82, green: 0.68, blue: 0.40),
                Color(red: 0.40, green: 0.30, blue: 0.14),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .metal:
            return LinearGradient(colors: [
                Color(red: 0.93, green: 0.94, blue: 0.96),
                Color(red: 0.55, green: 0.58, blue: 0.62),
                Color(red: 0.86, green: 0.88, blue: 0.91),
                Color(red: 0.40, green: 0.43, blue: 0.47),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Thin trim colour used for strokes/dividers matching `bezel`.
    var bezelLine: Color {
        switch self {
        case .wood:  return Color(red: 0.34, green: 0.26, blue: 0.13)
        case .metal: return Color(red: 0.52, green: 0.55, blue: 0.58)
        }
    }

    /// Background for popover-style secondary windows (Band/Preset/Help).
    var cabinet: LinearGradient {
        switch self {
        case .wood:
            return LinearGradient(colors: [
                Color(red: 0.26, green: 0.16, blue: 0.10),
                Color(red: 0.16, green: 0.095, blue: 0.055),
                Color(red: 0.09, green: 0.05, blue: 0.028),
            ], startPoint: .top, endPoint: .bottom)
        case .metal:
            return LinearGradient(colors: [
                Color(red: 0.22, green: 0.23, blue: 0.25),
                Color(red: 0.13, green: 0.14, blue: 0.155),
                Color(red: 0.06, green: 0.065, blue: 0.075),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Background fill for opaque instrument panels (control panel, help sidebar).
    var cabinetPanel: LinearGradient {
        switch self {
        case .wood:
            return LinearGradient(colors: [
                Color(red: 0.20, green: 0.125, blue: 0.075),
                Color(red: 0.115, green: 0.07, blue: 0.04),
            ], startPoint: .top, endPoint: .bottom)
        case .metal:
            return LinearGradient(colors: [
                Color(red: 0.16, green: 0.17, blue: 0.185),
                Color(red: 0.09, green: 0.095, blue: 0.105),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Label/legend colour: warm ivory on the wood cabinet, cool silver-white
    /// on the metal one — every button and panel label picks this up via
    /// `Theme.ivory` so text reads as "metal" too, not just the bezels.
    var ivory: Color {
        switch self {
        case .wood:  return Color(red: 0.93, green: 0.89, blue: 0.80)
        case .metal: return Color(red: 0.88, green: 0.90, blue: 0.93)
        }
    }

    var ivoryDark: Color {
        switch self {
        case .wood:  return Color(red: 0.74, green: 0.69, blue: 0.58)
        case .metal: return Color(red: 0.62, green: 0.65, blue: 0.69)
        }
    }

    /// Deepest metal-knob/screw shadow tone.
    var metalDeep: Color {
        switch self {
        case .wood:  return Color(red: 0.55, green: 0.50, blue: 0.40)
        case .metal: return Color(red: 0.38, green: 0.41, blue: 0.45)
        }
    }
}

/// Which signal indicator is shown: the moving-coil S-meter or the green
/// "magic eye" tuning tube (persisted; see RadioViewModel.meterStyle).
nonisolated enum MeterStyle: String, CaseIterable, Sendable {
    case sMeter, magicEye
}

enum Theme {

    /// The active cabinet variant. Swapped by RadioViewModel.themeVariant
    /// (always on the main thread); views re-read it when the tree re-renders.
    nonisolated(unsafe) static var currentVariant: ThemeVariant = .wood
    nonisolated static var current: ThemePalette { currentVariant.palette }

    // MARK: Colours (accent family forwards to the active palette)
    nonisolated static var amber: Color       { current.amber }
    nonisolated static var amberBright: Color { current.amberBright }
    nonisolated static var amberDeep: Color   { current.amberDeep }
    nonisolated static var amberDim: Color    { current.amberDim }
    nonisolated static var activeGlow: Color  { current.activeGlow }

    static let dialInk     = Color(red: 0.05, green: 0.040, blue: 0.022)
    static let dialInk2    = Color(red: 0.10, green: 0.075, blue: 0.035)

    /// A fixed "on-air" yellow, independent of the selected cabinet — the
    /// station list uses this (rather than `activeGlow`) so a tuned, on-air
    /// station always reads as yellow, even in the metal/blue variant where
    /// `activeGlow` is just a lighter tint of the accent colour.
    static let onAirYellow = Color(red: 1.00, green: 0.85, blue: 0.20)

    nonisolated static var ivory: Color     { currentVariant.ivory }
    nonisolated static var ivoryDark: Color { currentVariant.ivoryDark }
    static let pointer     = Color(red: 0.93, green: 0.27, blue: 0.18)

    static let brass       = Color(red: 0.78, green: 0.64, blue: 0.36)

    // MARK: Gradients (bezel/cabinet colours forward to the active variant)
    nonisolated static var cabinet: LinearGradient      { currentVariant.cabinet }
    nonisolated static var cabinetPanel: LinearGradient { currentVariant.cabinetPanel }
    nonisolated static var brassBezel: LinearGradient   { currentVariant.bezel }
    nonisolated static var brassDark: Color             { currentVariant.bezelLine }

    static let dialBackdrop = RadialGradient(
        colors: [dialInk2, dialInk, Color.black],
        center: .center, startRadius: 4, endRadius: 520)

    nonisolated static var amberLamp: RadialGradient { current.lamp }

    nonisolated static var metalKnob: LinearGradient {
        LinearGradient(colors: [ivory, ivoryDark, currentVariant.metalDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let glass = LinearGradient(
        colors: [.white.opacity(0.16), .white.opacity(0.03), .clear, .white.opacity(0.05)],
        startPoint: .top, endPoint: .bottom)

    // MARK: Fonts
    static func dialNumber(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func stationName(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .serif) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static let readout = Font.system(size: 26, weight: .bold, design: .monospaced)
}

// MARK: - Reusable hardware

/// A polished brass ring used around the dial and the meter glass.
struct BrassBezel: View {
    var corner: CGFloat = 18
    var line: CGFloat = 10
    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .strokeBorder(Theme.brassBezel, lineWidth: line)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.black.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
    }
}

/// A subtle glass reflection to lay over illuminated panels.
struct GlassReflection: View {
    var corner: CGFloat = 14
    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Theme.glass)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }
}

/// A small cabinet screw for the four corners.
struct Screw: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(colors: [Theme.ivoryDark, Theme.currentVariant.metalDeep],
                               center: .topLeading, startRadius: 0, endRadius: 10))
            .overlay(
                Rectangle().fill(.black.opacity(0.5))
                    .frame(width: 9, height: 1.4)
                    .rotationEffect(.degrees(35)))
            .overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 0.8))
            .frame(width: 12, height: 12)
            .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
    }
}

/// Lit indicator lamp (e.g. "rig online").
struct IndicatorLamp: View {
    var on: Bool
    var color: Color = Theme.activeGlow
    var body: some View {
        Circle()
            .fill(on ? color : Color.black.opacity(0.6))
            .frame(width: 11, height: 11)
            .overlay(Circle().strokeBorder(.black.opacity(0.5), lineWidth: 1))
            .shadow(color: on ? color.opacity(0.9) : .clear, radius: on ? 6 : 0)
            .overlay(
                Circle().fill(.white.opacity(on ? 0.5 : 0.1))
                    .frame(width: 3, height: 3).offset(x: -2, y: -2))
    }
}

extension View {
    /// Soft amber glow used on lit text / needles.
    func amberGlow(_ radius: CGFloat = 6, color: Color = Theme.amber) -> some View {
        shadow(color: color.opacity(0.7), radius: radius)
    }
}
