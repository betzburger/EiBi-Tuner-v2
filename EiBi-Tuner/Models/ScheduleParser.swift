//
//  ScheduleParser.swift
//  EiBi-Tuner
//
//  Parses the two schedule formats handled by eibi_tuner.py:
//   • EIBI  — semicolon CSV, header "kHz:..;Time(UTC):..;Days:..;ITU:..;Station:.."
//   • ILG   — wide semicolon CSV (ILGADATA.CSV) with a "FREQkhz" header row.
//
//  Unlike the Python app, parsing keeps every row and filtering (active-only,
//  target, search) happens reactively in the view model — so toggling a filter
//  no longer needs to re-read the file from disk.
//

import Foundation

nonisolated enum ScheduleParser {

    /// Auto-detects EIBI vs ILG and parses accordingly.
    static func parse(contents: String) -> (stations: [Station], type: FileType) {
        let lower = contents.prefix(4000).lowercased()
        if lower.contains("freqkhz") {
            return (parseILG(contents), .ilg)
        }
        return (parseEIBI(contents), .eibi)
    }

    // MARK: - EIBI

    static func parseEIBI(_ contents: String) -> [Station] {
        var lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return [] }

        // Header: column names are "Name:width" — keep the part before ':'.
        let header = lines.removeFirst()
        let columns = header.split(separator: ";").map {
            $0.split(separator: ":").first.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? ""
        }
        let idx = columnIndex(columns)

        var result: [Station] = []
        result.reserveCapacity(lines.count)
        for line in lines {
            let parts = line.split(separator: ";", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard let first = parts.first, let freq = Double(first) else { continue }

            result.append(Station(
                freqKHz: freq,
                time: field(parts, idx["Time(UTC)"]),
                days: field(parts, idx["Days"]),
                itu: field(parts, idx["ITU"]),
                station: field(parts, idx["Station"]),
                language: field(parts, idx["Lng"]),
                target: field(parts, idx["Target"]),
                remarks: field(parts, idx["Remarks"]),
                source: .eibi
            ))
        }
        return result
    }

    // MARK: - ILG (ILGADATA.CSV)

    static func parseILG(_ contents: String) -> [Station] {
        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)

        // Find the header row: contains "FREQkhz" and is not a "##" filler row.
        guard let headerIndex = lines.firstIndex(where: {
            $0.contains("FREQkhz") && !$0.hasPrefix("##") && !$0.hasPrefix("###")
        }) else { return [] }

        // Clean column names (strip ## / ### markers); empties are dropped so the
        // index alignment matches the Python loader.
        let rawColumns = lines[headerIndex].split(separator: ";", omittingEmptySubsequences: false)
        let columns = rawColumns
            .map { $0.replacingOccurrences(of: "##", with: "")
                     .replacingOccurrences(of: "###", with: "")
                     .trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let idx = columnIndex(columns)

        var result: [Station] = []
        for line in lines[(headerIndex + 1)...] {
            let parts = line.split(separator: ";", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard let first = parts.first, let freq = Double(first) else { continue }

            let time = field(parts, idx["TIMES:UTC"])
            // Skip legend / filler rows (their time/station fields are '#' runs).
            if time.contains("#") { continue }
            let station = parts.count > 1 ? parts[1] : ""
            if station.replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespaces).isEmpty { continue }

            result.append(Station(
                freqKHz: freq,
                time: time,
                days: field(parts, idx["1=Sun"]),
                itu: field(parts, idx["ITU"]),
                station: station,
                language: field(parts, idx["LANGUAGE"]),
                target: field(parts, idx["TARGET"]),
                remarks: ilgRemarks(parts, idx),
                source: .ilg
            ))
        }
        return result
    }

    /// Builds a readable remarks line for ILG rows: location, power, notes, call sign.
    private static func ilgRemarks(_ parts: [String], _ idx: [String: Int]) -> String {
        var bits: [String] = []
        let loc = field(parts, idx["LOCATION OF TRANSMITTER"])
        if !loc.isEmpty { bits.append(loc) }
        let pwr = field(parts, idx["POWERkw"])
        if let p = Double(pwr), p > 0 { bits.append(String(format: "%g kW", p)) }
        let notes = field(parts, idx["NOTES - FURTHER INFO"])
        if !notes.isEmpty { bits.append(notes) }
        let call = field(parts, idx["CALL SIGN - NETWORK IDENTIFICATION"])
        if !call.isEmpty, call != notes { bits.append(call) }
        return bits.joined(separator: " · ")
    }

    // MARK: - Helpers

    private static func columnIndex(_ columns: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, name) in columns.enumerated() where map[name] == nil {
            map[name] = i
        }
        return map
    }

    private static func field(_ parts: [String], _ index: Int?) -> String {
        guard let i = index, i >= 0, i < parts.count else { return "" }
        return parts[i]
    }
}
