//
//  Station.swift
//  EiBi-Tuner
//
//  A single broadcast-schedule entry plus the time/day validity logic
//  ported 1:1 from eibi_tuner.py (_is_time_valid / _is_day_valid).
//

import Foundation

/// Which schedule file a station came from.
nonisolated enum FileType: String, Sendable {
    case eibi = "EIBI"
    case ilg  = "ILG"
}

/// One row of the EIBI / ILG schedule.
nonisolated struct Station: Identifiable, Hashable, Sendable {
    let id = UUID()

    /// Frequency in kHz (the sort/match key).
    var freqKHz: Double
    /// "0000-2400" style UTC time window (may be empty == all day).
    var time: String
    /// Days string, e.g. "Mo-Fr", "1234567", ".2.4.6." or empty == every day.
    var days: String
    var itu: String
    var station: String
    var language: String
    var target: String
    var remarks: String
    var source: FileType

    /// Frequency formatted the way the Python app printed it ("%.2f").
    var freqText: String { String(format: "%.2f", freqKHz) }

    /// A compact one-line haystack used for free-text search (matches the
    /// Python behaviour of searching the rendered row / all values).
    var searchHaystack: String {
        "\(freqText) \(time) \(days) \(itu) \(station) \(language) \(target) \(remarks)"
            .lowercased()
    }

    // MARK: - Schedule validity (port of _is_time_valid / _is_day_valid)

    /// True if this station is on the air at the given UTC instant
    /// (both the time window and the day-of-week match).
    func isActive(at utc: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.hour, .minute, .weekday], from: utc)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        // Calendar weekday: 1 = Sunday … 7 = Saturday.
        // Python weekday(): 0 = Monday … 6 = Sunday.
        let pyWeekday = ((comps.weekday ?? 1) + 5) % 7
        return Self.isTimeValid(time, hour: hour, minute: minute)
            && Self.isDayValid(days, weekday: pyWeekday)
    }

    /// Port of `_is_time_valid`.
    static func isTimeValid(_ range: String, hour: Int, minute: Int) -> Bool {
        let r = range.trimmingCharacters(in: .whitespaces)
        if r.isEmpty || r == "0000-2400" { return true }

        let parts = r.split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              parts[0].count >= 4, parts[1].count >= 4,
              let startH = Int(parts[0].prefix(2)),
              let startM = Int(parts[0].dropFirst(2).prefix(2)),
              let endH   = Int(parts[1].prefix(2)),
              let endM   = Int(parts[1].dropFirst(2).prefix(2))
        else { return false }

        let current = hour * 60 + minute
        let start = startH * 60 + startM
        let end = endH * 60 + endM

        if start <= end {
            return current >= start && current < end
        } else { // overnight, e.g. 2300-0100
            return current >= start || current < end
        }
    }

    /// Port of `_is_day_valid`.
    static func isDayValid(_ daysStr: String, weekday: Int) -> Bool {
        let s = daysStr.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return true } // empty == all days

        let dayMap: [String: Int] = [
            "Mo": 0, "Tu": 1, "We": 2, "Th": 3, "Fr": 4, "Sa": 5, "Su": 6,
            "1": 0, "2": 1, "3": 2, "4": 3, "5": 4, "6": 5, "7": 6,
        ]

        var validDays = Set<Int>()

        if s.contains("-") {
            let parts = s.split(separator: "-", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let startDay = dayMap[parts[0]],
                  let endDay = dayMap[parts[1]] else { return false }
            if startDay <= endDay {
                for i in startDay...endDay { validDays.insert(i) }
            } else { // wrap-around range, e.g. Fr-Mo
                for i in startDay...6 { validDays.insert(i) }
                for i in 0...endDay { validDays.insert(i) }
            }
        } else {
            var foundDigitDay = false
            for ch in s where ch.isNumber {
                if let d = dayMap[String(ch)] {
                    validDays.insert(d)
                    foundDigitDay = true
                }
            }
            if !foundDigitDay, let d = dayMap[s] {
                validDays.insert(d)
            }
        }

        return validDays.contains(weekday)
    }
}
