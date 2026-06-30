//
//  RadioTheme.swift
//  EiBi-Tuner
//
//  Shared palette, gradients and reusable "hardware" pieces (brass bezel,
//  glass reflection, cabinet screws) that give every view the same warm,
//  amber-backlit valve-radio look.
//

import SwiftUI

/// The interchangeable part of the look: the accent ("backlight") colour family
/// and the dial glow. The cabinet, brass and ivory stay shared across variants
/// so every palette feels like the same radio with a different tube colour.
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

    static let green = ThemePalette(
        amber:       Color(red: 0.46, green: 0.92, blue: 0.55),
        amberBright: Color(red: 0.74, green: 1.00, blue: 0.80),
        amberDeep:   Color(red: 0.16, green: 0.55, blue: 0.24),
        amberDim:    Color(red: 0.26, green: 0.55, blue: 0.30),
        activeGlow:  Color(red: 0.62, green: 1.00, blue: 0.66))

    static let blue = ThemePalette(
        amber:       Color(red: 0.40, green: 0.74, blue: 1.00),
        amberBright: Color(red: 0.72, green: 0.89, blue: 1.00),
        amberDeep:   Color(red: 0.13, green: 0.40, blue: 0.72),
        amberDim:    Color(red: 0.26, green: 0.46, blue: 0.70),
        activeGlow:  Color(red: 0.56, green: 0.86, blue: 1.00))

    static let red = ThemePalette(
        amber:       Color(red: 1.00, green: 0.46, blue: 0.40),
        amberBright: Color(red: 1.00, green: 0.68, blue: 0.58),
        amberDeep:   Color(red: 0.66, green: 0.18, blue: 0.13),
        amberDim:    Color(red: 0.62, green: 0.26, blue: 0.20),
        activeGlow:  Color(red: 1.00, green: 0.56, blue: 0.46))
}

/// User-selectable colour variants (persisted; see RadioViewModel.themeVariant).
nonisolated enum ThemeVariant: String, CaseIterable, Identifiable, Sendable {
    case amber, green, blue, red
    var id: String { rawValue }
    var palette: ThemePalette {
        switch self {
        case .amber: return .amber
        case .green: return .green
        case .blue:  return .blue
        case .red:   return .red
        }
    }
    var label: String {
        switch self {
        case .amber: return "Amber"
        case .green: return "Green"
        case .blue:  return "Blue"
        case .red:   return "Red"
        }
    }
}

/// Which signal indicator is shown: the moving-coil S-meter or the green
/// "magic eye" tuning tube (persisted; see RadioViewModel.meterStyle).
nonisolated enum MeterStyle: String, CaseIterable, Sendable {
    case sMeter, magicEye
}

enum Theme {

    /// The active palette. Swapped by RadioViewModel.themeVariant (always on the
    /// main thread); views re-read it when the tree re-renders.
    nonisolated(unsafe) static var current: ThemePalette = .amber

    // MARK: Colours (accent family forwards to the active palette)
    nonisolated static var amber: Color       { current.amber }
    nonisolated static var amberBright: Color { current.amberBright }
    nonisolated static var amberDeep: Color   { current.amberDeep }
    nonisolated static var amberDim: Color    { current.amberDim }
    nonisolated static var activeGlow: Color  { current.activeGlow }

    static let dialInk     = Color(red: 0.05, green: 0.040, blue: 0.022)
    static let dialInk2    = Color(red: 0.10, green: 0.075, blue: 0.035)

    static let ivory       = Color(red: 0.93, green: 0.89, blue: 0.80)
    static let ivoryDark   = Color(red: 0.74, green: 0.69, blue: 0.58)
    static let pointer     = Color(red: 0.93, green: 0.27, blue: 0.18)

    static let brass       = Color(red: 0.78, green: 0.64, blue: 0.36)
    static let brassDark   = Color(red: 0.34, green: 0.26, blue: 0.13)

    // MARK: Gradients
    static let cabinet = LinearGradient(
        colors: [
            Color(red: 0.26, green: 0.16, blue: 0.10),
            Color(red: 0.16, green: 0.095, blue: 0.055),
            Color(red: 0.09, green: 0.05, blue: 0.028),
        ],
        startPoint: .top, endPoint: .bottom)

    static let cabinetPanel = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.125, blue: 0.075),
            Color(red: 0.115, green: 0.07, blue: 0.04),
        ],
        startPoint: .top, endPoint: .bottom)

    static let dialBackdrop = RadialGradient(
        colors: [dialInk2, dialInk, Color.black],
        center: .center, startRadius: 4, endRadius: 520)

    nonisolated static var amberLamp: RadialGradient { current.lamp }

    static let brassBezel = LinearGradient(
        colors: [
            Color(red: 0.88, green: 0.76, blue: 0.46),
            Color(red: 0.55, green: 0.43, blue: 0.21),
            Color(red: 0.82, green: 0.68, blue: 0.40),
            Color(red: 0.40, green: 0.30, blue: 0.14),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let metalKnob = LinearGradient(
        colors: [ivory, ivoryDark, Color(red: 0.55, green: 0.50, blue: 0.40)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

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
                RadialGradient(colors: [Theme.ivoryDark, Color(red: 0.4, green: 0.36, blue: 0.28)],
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
