//
//  Band.swift
//  EiBi-Tuner
//
//  The shortwave "meter bands" a listener jumps between: the broadcast bands
//  (75 m, 49 m, 31 m …) and the amateur HF bands (80 m, 40 m, 20 m …). Each
//  band carries its edge frequencies so the Band picker can show the range and
//  tune the dial to a sensible spot inside it.
//

import Foundation

/// Whether a band is a broadcast (Rundfunk) or amateur-radio (Amateurfunk) band.
/// The picker colours the two groups differently.
nonisolated enum BandKind: String, Sendable {
    case broadcast = "Rundfunk"
    case amateur   = "Amateurfunk"
}

/// One named meter band with its lower / upper edge in kHz.
nonisolated struct Band: Identifiable, Sendable, Hashable {
    let id = UUID()
    /// Short label, e.g. "49 m".
    let name: String
    let kind: BandKind
    let loKHz: Double
    let hiKHz: Double

    /// Geometric middle of the band — the default tuning target.
    var centerKHz: Double { (loKHz + hiKHz) / 2 }

    /// "5900–6200 kHz" style range caption.
    var rangeText: String {
        "\(Self.fmt(loKHz))–\(Self.fmt(hiKHz)) kHz"
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    // MARK: - Band plans

    /// International shortwave broadcast meter bands (plus LW/MW for completeness).
    static let broadcast: [Band] = [
        Band(name: "LW",     kind: .broadcast, loKHz: 148.5,  hiKHz: 283.5),
        Band(name: "MW",     kind: .broadcast, loKHz: 526.5,  hiKHz: 1606.5),
        Band(name: "120 m",  kind: .broadcast, loKHz: 2300,   hiKHz: 2495),
        Band(name: "90 m",   kind: .broadcast, loKHz: 3200,   hiKHz: 3400),
        Band(name: "75 m",   kind: .broadcast, loKHz: 3900,   hiKHz: 4000),
        Band(name: "60 m",   kind: .broadcast, loKHz: 4750,   hiKHz: 5060),
        Band(name: "49 m",   kind: .broadcast, loKHz: 5900,   hiKHz: 6200),
        Band(name: "41 m",   kind: .broadcast, loKHz: 7200,   hiKHz: 7450),
        Band(name: "31 m",   kind: .broadcast, loKHz: 9400,   hiKHz: 9900),
        Band(name: "25 m",   kind: .broadcast, loKHz: 11600,  hiKHz: 12100),
        Band(name: "22 m",   kind: .broadcast, loKHz: 13570,  hiKHz: 13870),
        Band(name: "19 m",   kind: .broadcast, loKHz: 15100,  hiKHz: 15800),
        Band(name: "16 m",   kind: .broadcast, loKHz: 17480,  hiKHz: 17900),
        Band(name: "15 m",   kind: .broadcast, loKHz: 18900,  hiKHz: 19020),
        Band(name: "13 m",   kind: .broadcast, loKHz: 21450,  hiKHz: 21850),
        Band(name: "11 m",   kind: .broadcast, loKHz: 25670,  hiKHz: 26100),
    ]

    /// Amateur-radio HF bands (IARU Region 1 edges; close enough for tuning).
    static let amateur: [Band] = [
        Band(name: "160 m",  kind: .amateur, loKHz: 1810,    hiKHz: 2000),
        Band(name: "80 m",   kind: .amateur, loKHz: 3500,    hiKHz: 3800),
        Band(name: "60 m",   kind: .amateur, loKHz: 5351.5,  hiKHz: 5366.5),
        Band(name: "40 m",   kind: .amateur, loKHz: 7000,    hiKHz: 7200),
        Band(name: "30 m",   kind: .amateur, loKHz: 10100,   hiKHz: 10150),
        Band(name: "20 m",   kind: .amateur, loKHz: 14000,   hiKHz: 14350),
        Band(name: "17 m",   kind: .amateur, loKHz: 18068,   hiKHz: 18168),
        Band(name: "15 m",   kind: .amateur, loKHz: 21000,   hiKHz: 21450),
        Band(name: "12 m",   kind: .amateur, loKHz: 24890,   hiKHz: 24990),
        Band(name: "10 m",   kind: .amateur, loKHz: 28000,   hiKHz: 29700),
    ]
}
