//
//  Localization.swift
//  EiBi-Tuner
//
//  A lightweight runtime language switch. The fixed instrument UI (MODE,
//  STATIONS, the knobs …) stays English in every language, but the Help
//  window and the Band / Preset pop-ups are shown in German when the Mac's
//  preferred language is German, and in English otherwise.
//

import Foundation

nonisolated enum AppLanguage {
    /// True when the system's top preferred language is German.
    static var isGerman: Bool {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("de")
    }

    /// Returns the German or English variant depending on the system language.
    static func t(_ german: String, _ english: String) -> String {
        isGerman ? german : english
    }
}
