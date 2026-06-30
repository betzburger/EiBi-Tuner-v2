//
//  FrequencyPreset.swift
//  EiBi-Tuner
//
//  A single user memory slot: a name plus the frequency (and mode) that was
//  stored into it. Empty slots have no frequency. The whole set is persisted
//  as JSON in UserDefaults so presets survive relaunches.
//

import Foundation

nonisolated struct FrequencyPreset: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    /// User-editable label, e.g. "BBC 49 m" — defaults to "P1", "P2", …
    var name: String
    /// Stored dial frequency in kHz, or nil when the slot is empty.
    var freqKHz: Double?
    /// Mode recalled with the frequency (USB/AM/…), best effort.
    var mode: String?

    var isEmpty: Bool { freqKHz == nil }

    /// "6.150,00 kHz" style caption for a filled slot.
    var freqText: String {
        guard let f = freqKHz else { return "—" }
        return f.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
    }
}
