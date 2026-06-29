//
//  FlrigClient.swift
//  EiBi-Tuner
//
//  A tiny, dependency-free XML-RPC client for FLRIG, mirroring the calls the
//  Python app made (rig.get_vfo / main.set_frequency) and adding the methods
//  needed for the S-meter and mode/bandwidth controls.
//
//  Every call is failure-tolerant: on any error it returns nil / [] so the UI
//  can degrade gracefully when FLRIG isn't running.
//

import Foundation

nonisolated struct FlrigClient: Sendable {
    var host: String
    var port: Int

    private var endpoint: URL? {
        URL(string: "http://\(host):\(port)/RPC2")
    }

    // MARK: - Public API (method names match FLRIG's XML-RPC interface)

    /// Current VFO frequency in Hz, or nil if unavailable.
    func getVFO() async -> Double? {
        guard let raw = await callScalar("rig.get_vfo") else { return nil }
        return Double(raw)
    }

    /// Sets the VFO frequency (Hz). Matches the Python `main.set_frequency`.
    func setFrequency(_ hz: Double) async {
        _ = await call("main.set_frequency", params: [.double(hz)])
    }

    /// S-meter reading. FLRIG returns roughly 0…100 (% of scale).
    func getSMeter() async -> Double? {
        guard let raw = await callScalar("rig.get_smeter") else { return nil }
        return Double(raw)
    }

    func getMode() async -> String? { await callScalar("rig.get_mode") }

    func setMode(_ mode: String) async {
        _ = await call("rig.set_mode", params: [.string(mode)])
    }

    func getModes() async -> [String] { await callArray("rig.get_modes") }

    func getBandwidth() async -> String? { await callScalar("rig.get_bw") }

    func setBandwidth(_ bw: String) async {
        _ = await call("rig.set_bandwidth", params: [.string(bw)])
    }

    func getBandwidths() async -> [String] {
        // FLRIG's get_bws may return a flat list or nested label arrays;
        // we flatten and keep anything that looks like a width.
        await callArray("rig.get_bws")
    }

    /// Lightweight reachability probe (used to show the "rig online" lamp).
    func isReachable() async -> Bool {
        await callScalar("rig.get_vfo") != nil
    }

    /// All XML-RPC methods FLRIG exposes (used to discover whether this rig
    /// supports volume / AGC, whose exact method names vary by build).
    func listMethods() async -> [String] {
        await callArray("system.listMethods")
    }

    /// Generic integer getter/setter for discovered methods (volume, AGC…).
    func getInt(_ method: String) async -> Int? {
        guard let raw = await callScalar(method) else { return nil }
        if let i = Int(raw) { return i }
        if let d = Double(raw) { return Int(d.rounded()) }
        return nil
    }

    func setInt(_ method: String, _ value: Int) async {
        _ = await call(method, params: [.int(value)])
    }

    // MARK: - XML-RPC parameter values

    enum Param {
        case double(Double)
        case string(String)
        case int(Int)

        var xml: String {
            switch self {
            case .double(let d): return "<value><double>\(String(format: "%.1f", d))</double></value>"
            case .int(let i):    return "<value><i4>\(i)</i4></value>"
            case .string(let s): return "<value><string>\(Self.escape(s))</string></value>"
            }
        }

        static func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
    }

    // MARK: - Transport

    private func call(_ method: String, params: [Param] = []) async -> String? {
        guard let endpoint else { return nil }

        let paramXML = params.map { "<param>\($0.xml)</param>" }.joined()
        let body = """
        <?xml version="1.0"?>
        <methodCall><methodName>\(method)</methodName><params>\(paramXML)</params></methodCall>
        """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)
        request.timeoutInterval = 2.0

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func callScalar(_ method: String, params: [Param] = []) async -> String? {
        guard let xml = await call(method, params: params) else { return nil }
        if xml.contains("<fault>") { return nil }
        return Self.firstValue(in: xml)
    }

    private func callArray(_ method: String, params: [Param] = []) async -> [String] {
        guard let xml = await call(method, params: params) else { return [] }
        if xml.contains("<fault>") { return [] }
        return Self.arrayValues(in: xml)
    }

    // MARK: - Response parsing

    /// Text of the first scalar <value> in the response.
    static func firstValue(in xml: String) -> String? {
        guard let raw = match(#"<value>(.*?)</value>"#, in: xml, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        return clean(raw)
    }

    /// All scalar <value> entries inside the response's <data> block.
    static func arrayValues(in xml: String) -> [String] {
        let region: String
        if let data = match(#"<data>(.*?)</data>"#, in: xml, options: [.dotMatchesLineSeparators]) {
            region = data
        } else {
            region = xml
        }
        return matches(#"<value>(.*?)</value>"#, in: region, options: [.dotMatchesLineSeparators])
            .map(clean)
            .filter { !$0.isEmpty }
    }

    /// Strips XML-RPC type wrappers and unescapes the basic entities.
    private static func clean(_ s: String) -> String {
        var t = s
        for tag in ["string", "double", "i4", "int", "boolean", "dateTime.iso8601"] {
            t = t.replacingOccurrences(of: "<\(tag)>", with: "")
                 .replacingOccurrences(of: "</\(tag)>", with: "")
        }
        t = t.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func match(_ pattern: String, in text: String,
                              options: NSRegularExpression.Options = []) -> String? {
        matches(pattern, in: text, options: options).first
    }

    private static func matches(_ pattern: String, in text: String,
                                options: NSRegularExpression.Options = []) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).compactMap { result in
            guard result.numberOfRanges > 1,
                  let r = Range(result.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }
}
