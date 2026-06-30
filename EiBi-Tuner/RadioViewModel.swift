//
//  RadioViewModel.swift
//  EiBi-Tuner
//
//  The brain of the app: holds schedule data + filters, polls FLRIG once a
//  second (mirroring update_view_mode_display in eibi_tuner.py), and exposes
//  everything the retro views render.
//

import SwiftUI
import Observation
import AppKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class RadioViewModel {

    // MARK: - Highlight state (port of the grey / yellow listbox colours)

    enum Highlight {
        case normal      // just nearby
        case onFrequency // frequency matches the dial (Python: grey)
        case active      // frequency matches *and* on air now (Python: yellow)
    }

    // MARK: - Schedule data

    private(set) var stations: [Station] = []
    private(set) var displayedStations: [Station] = []
    /// Up to 10 stations closest to the current dial frequency (for the stack).
    private(set) var nearbyStations: [Station] = []
    private(set) var fileType: FileType?
    private(set) var loadedFileName: String?
    var isLoading = false
    var loadError: String?

    // MARK: - Filters (live, no file reload needed)

    var searchText = "" { didSet { recomputeDisplayed() } }
    var targetFilter = "" { didSet { recomputeDisplayed() } }
    var activeOnly = false {
        didSet {
            UserDefaults.standard.set(activeOnly, forKey: "activeOnly")
            recomputeDisplayed()
        }
    }

    // MARK: - Rig state

    var currentFreqKHz: Double = 1000 { didSet { recomputeNearby() } }
    var smeter: Double = 0          // 0…100 (% of scale), as FLRIG reports
    var rigOnline = false
    var mode: String = "—"
    var availableModes: [String] = []
    var bandwidth: String = "—"
    var availableBandwidths: [String] = []

    /// AF gain 0…100 and AGC, discovered from FLRIG at connect time.
    var volume: Double = 0
    var agcIndex: Int = 0
    private(set) var volumeAvailable = false
    private(set) var agcAvailable = false

    /// Optional receiver controls discovered from FLRIG, shown only when the rig
    /// exposes them: squelch / RF-gain levels (0…100) and a notch on/off.
    var squelch: Double = 0
    var rfGain: Double = 100
    var notchOn = false
    private(set) var squelchAvailable = false
    private(set) var rfGainAvailable = false
    private(set) var notchAvailable = false

    // MARK: - Connection (persisted)

    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "flrigHost") }
    }
    var port: String {
        didSet { UserDefaults.standard.set(port, forKey: "flrigPort") }
    }

    var utcNow = Date()

    // Hover flags so the scroll-wheel monitor knows when to tune.
    var hoverDial = false
    var hoverKnob = false
    /// Place value (kHz) of the frequency-readout digit currently hovered, so
    /// the scroll-wheel monitor can step that digit. nil when none is hovered.
    var hoverFreqPlace: Double? = nil

    /// When on, releasing the tuning knob / dial or stopping the wheel snaps
    /// to the nearest station. On by default.
    var snapToStation = true {
        didSet { UserDefaults.standard.set(snapToStation, forKey: "snapToStation") }
    }

    // MARK: - Memory presets (persisted as JSON)

    /// Number of freely-assignable preset slots shown in the Preset picker.
    static let presetCount = 20

    /// The user's preset slots. Writing the array re-persists the whole set.
    var presets: [FrequencyPreset] = [] {
        didSet { persistPresets() }
    }

    // MARK: - Frequency span of the loaded data (for the dial scale)

    private(set) var minFreqKHz: Double = 150
    private(set) var maxFreqKHz: Double = 30_000

    // MARK: - Private

    private var pollTask: Task<Void, Never>?
    private var suppressVFOReadUntil: Date = .distantPast
    private var suppressVolumeReadUntil: Date = .distantPast
    private var suppressAgcReadUntil: Date = .distantPast
    private var suppressSquelchReadUntil: Date = .distantPast
    private var suppressRfReadUntil: Date = .distantPast
    private var suppressNotchReadUntil: Date = .distantPast
    private var lastMinute: Int = -1
    private var listRefreshCounter = 0

    // Discovered FLRIG method names (volume / AGC vary by rig build).
    private var methodsLoaded = false
    private var volGetMethod: String?
    private var volSetMethod: String?
    private var agcGetMethod: String?
    private var agcSetMethod: String?
    private var sqlGetMethod: String?
    private var sqlSetMethod: String?
    private var rfGetMethod: String?
    private var rfSetMethod: String?
    private var notchGetMethod: String?
    private var notchSetMethod: String?

    init() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "flrigHost") ?? "127.0.0.1"
        port = defaults.string(forKey: "flrigPort") ?? "12345"

        // Restore last session settings (assignments in init don't fire didSet,
        // so these neither re-persist nor recompute before data is loaded).
        activeOnly = defaults.bool(forKey: "activeOnly")
        if defaults.object(forKey: "snapToStation") != nil {
            snapToStation = defaults.bool(forKey: "snapToStation")
        }
        if let f = defaults.object(forKey: "lastFreqKHz") as? Double, f > 0 {
            currentFreqKHz = f
        }
        if let m = defaults.string(forKey: "lastMode"), !m.isEmpty {
            mode = m
        }
        presets = Self.loadPresets()
    }

    // MARK: - Lifecycle

    func start() {
        guard pollTask == nil else { return }
        loadRememberedFile()
        installScrollMonitor()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
    }

    // MARK: - Mouse-wheel tuning (over the dial or tuning knob)

    private var scrollMonitor: Any?
    private let scrollStepKHz = 1.0
    private var scrollIdleTask: Task<Void, Never>?

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            // Read the (Sendable) scalar here; don't pass NSEvent across the actor hop.
            // Prefer the precise scrolling delta but fall back to the legacy one.
            let deltaY = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            let consumed = MainActor.assumeIsolated { self.handleScroll(deltaY: deltaY) }
            return consumed ? nil : event
        }
    }

    /// Returns true when the scroll was used to tune (and should be consumed).
    private func handleScroll(deltaY: CGFloat) -> Bool {
        // Over the frequency readout: step the hovered digit by its place value.
        if let place = hoverFreqPlace, deltaY != 0 {
            let dir: Double = deltaY > 0 ? 1 : -1
            tune(toKHz: currentFreqKHz + dir * place)
            return true
        }
        guard hoverDial || hoverKnob, deltaY != 0 else { return false }
        let direction: Double = deltaY > 0 ? 1 : -1
        scrub(toKHz: currentFreqKHz + direction * scrollStepKHz)
        // Snap (or commit) shortly after the wheel stops moving.
        scrollIdleTask?.cancel()
        scrollIdleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            self?.endTuneGesture()
        }
        return true
    }

    private var client: FlrigClient {
        FlrigClient(host: host, port: Int(port) ?? 12345)
    }

    // MARK: - Polling

    private func tick() async {
        utcNow = Date()
        let rig = client

        if let vfo = await rig.getVFO() {
            rigOnline = true
            if Date() >= suppressVFOReadUntil {
                let newKHz = vfo / 1000
                if abs(newKHz - currentFreqKHz) >= 0.01 { // 10 Hz tolerance
                    currentFreqKHz = newKHz
                }
            }
            // Reading-only data
            smeter = await rig.getSMeter() ?? max(0, smeter - 8)
            if let m = await rig.getMode() { mode = m }
            if let bw = await rig.getBandwidth() { bandwidth = bw }
            // Refresh the mode/bandwidth lists when first seen and every ~10 s
            // afterwards, so they update if the rig is changed in FLRIG.
            listRefreshCounter += 1
            if availableModes.isEmpty || availableBandwidths.isEmpty || listRefreshCounter % 10 == 0 {
                let m = await rig.getModes(); if !m.isEmpty { availableModes = m }
                let b = await rig.getBandwidths(); if !b.isEmpty { availableBandwidths = b }
            }

            // Discover optional volume / AGC support once.
            if !methodsLoaded {
                let methods = await rig.listMethods()
                if !methods.isEmpty {
                    methodsLoaded = true
                    func find(_ needle: String) -> String? {
                        methods.first { $0.lowercased().contains(needle) }
                    }
                    volGetMethod = find("get_volume"); volSetMethod = find("set_volume")
                    agcGetMethod = find("get_agc");    agcSetMethod = find("set_agc")
                    sqlGetMethod = find("get_sql") ?? find("get_squelch")
                    sqlSetMethod = find("set_sql") ?? find("set_squelch")
                    rfGetMethod = find("get_rfgain");  rfSetMethod = find("set_rfgain")
                    notchGetMethod = find("get_notch"); notchSetMethod = find("set_notch")
                    volumeAvailable = volSetMethod != nil || volGetMethod != nil
                    agcAvailable = agcSetMethod != nil || agcGetMethod != nil
                    squelchAvailable = sqlSetMethod != nil || sqlGetMethod != nil
                    rfGainAvailable = rfSetMethod != nil || rfGetMethod != nil
                    notchAvailable = notchSetMethod != nil || notchGetMethod != nil
                }
            }
            if let g = volGetMethod, Date() >= suppressVolumeReadUntil,
               let v = await rig.getInt(g) { volume = Double(v) }
            if let g = agcGetMethod, Date() >= suppressAgcReadUntil,
               let a = await rig.getInt(g) { agcIndex = a }
            if let g = sqlGetMethod, Date() >= suppressSquelchReadUntil,
               let v = await rig.getInt(g) { squelch = Double(v) }
            if let g = rfGetMethod, Date() >= suppressRfReadUntil,
               let v = await rig.getInt(g) { rfGain = Double(v) }
            if let g = notchGetMethod, Date() >= suppressNotchReadUntil,
               let v = await rig.getInt(g) { notchOn = v != 0 }
        } else {
            rigOnline = false
            smeter = max(0, smeter - 12) // let the needle fall back
        }

        // When "only active now" is on, the active set changes over time.
        let minute = Calendar.current.component(.minute, from: utcNow)
        if minute != lastMinute {
            lastMinute = minute
            if activeOnly { recomputeDisplayed() } else { recomputeNearby() }
        }
    }

    // MARK: - Tuning (two-way)

    func tune(toKHz khz: Double) {
        let clamped = min(max(khz, minFreqKHz), maxFreqKHz)
        currentFreqKHz = clamped
        UserDefaults.standard.set(clamped, forKey: "lastFreqKHz")
        suppressVFOReadUntil = Date().addingTimeInterval(1.2)
        let hz = clamped * 1000
        Task { await client.setFrequency(hz) }
    }

    private var lastScrubSend: Date = .distantPast

    /// Continuous tuning while dragging the dial: updates the display
    /// immediately but throttles the FLRIG writes (~10/s) to avoid flooding.
    func scrub(toKHz khz: Double) {
        let clamped = min(max(khz, minFreqKHz), maxFreqKHz)
        currentFreqKHz = clamped
        suppressVFOReadUntil = Date().addingTimeInterval(1.0)
        let now = Date()
        if now.timeIntervalSince(lastScrubSend) >= 0.1 {
            lastScrubSend = now
            let hz = clamped * 1000
            Task { await client.setFrequency(hz) }
        }
    }

    func nudge(byKHz delta: Double) {
        tune(toKHz: currentFreqKHz + delta)
    }

    /// Parses a user-typed frequency in kHz (tolerant of grouping separators and
    /// either ',' or '.' as the decimal mark) and tunes to it.
    func tuneToTypedFrequency(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "_", with: "")
        let dot = s.lastIndex(of: "."), comma = s.lastIndex(of: ",")
        if let d = dot, let c = comma {
            // The right-most of the two is the decimal mark; the other is grouping.
            if c > d {
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        } else if comma != nil {
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        guard let v = Double(s), v > 0 else { return }
        tune(toKHz: v)
    }

    // MARK: - Band jumping

    /// Jumps the dial to a meter band. Lands on the nearest real station inside
    /// the band when the loaded schedule has one, otherwise on the band centre.
    func tuneToBand(_ band: Band) {
        let inBand = displayedStations.filter { $0.freqKHz >= band.loKHz && $0.freqKHz <= band.hiKHz }
        if let nearest = inBand.min(by: {
            abs($0.freqKHz - band.centerKHz) < abs($1.freqKHz - band.centerKHz)
        }) {
            tune(toKHz: nearest.freqKHz)
        } else {
            tune(toKHz: band.centerKHz)
        }
    }

    // MARK: - Presets

    /// Stores the current frequency (and mode) into a slot, keeping its name.
    func savePreset(at index: Int) {
        guard presets.indices.contains(index) else { return }
        presets[index].freqKHz = currentFreqKHz
        presets[index].mode = (mode == "—") ? nil : mode
    }

    /// Recalls a slot: tunes the dial and restores the mode when the rig has it.
    func recallPreset(at index: Int) {
        guard presets.indices.contains(index), let f = presets[index].freqKHz else { return }
        tune(toKHz: f)
        if let m = presets[index].mode, modeAvailable(m) { setMode(m) }
    }

    func renamePreset(at index: Int, to name: String) {
        guard presets.indices.contains(index) else { return }
        presets[index].name = name
    }

    /// Empties a slot but keeps its (renamed) label.
    func clearPreset(at index: Int) {
        guard presets.indices.contains(index) else { return }
        presets[index].freqKHz = nil
        presets[index].mode = nil
    }

    /// The displayed station closest to the current dial frequency.
    var nearestStation: Station? {
        displayedStations.min {
            abs($0.freqKHz - currentFreqKHz) < abs($1.freqKHz - currentFreqKHz)
        }
    }

    /// Called when a tuning gesture (knob/dial drag, or wheel) finishes:
    /// snaps to the nearest station when enabled, otherwise commits the
    /// current frequency precisely to FLRIG.
    func endTuneGesture() {
        if snapToStation, let s = nearestStation {
            tune(toKHz: s.freqKHz)
        } else {
            tune(toKHz: currentFreqKHz)
        }
    }

    func setMode(_ m: String) {
        mode = m
        UserDefaults.standard.set(m, forKey: "lastMode")
        Task { await client.setMode(m) }
    }

    /// The base name of a rig mode, e.g. "CW-U" → "CW", "USB" → "USB".
    private func modeBase(_ m: String) -> String {
        m.split(separator: "-").first.map(String.init) ?? m
    }

    /// Resolves a quick-button label (USB/LSB/AM/CW) to the actual mode string
    /// the connected rig uses. A Yaesu, for instance, reports CW as "CW-U", so
    /// tapping CW must select "CW-U". Returns the label itself when offline.
    func resolvedMode(for quick: String) -> String? {
        guard !availableModes.isEmpty else { return quick }
        if let exact = availableModes.first(where: { $0.caseInsensitiveCompare(quick) == .orderedSame }) {
            return exact
        }
        let variants = availableModes.filter {
            modeBase($0).caseInsensitiveCompare(quick) == .orderedSame
        }
        // Prefer the upper-sideband variant (e.g. CW-U) when the rig offers a choice.
        return variants.first { $0.uppercased().hasSuffix("U") } ?? variants.first
    }

    /// Whether the rig exposes a mode for this quick label (used to enable/grey
    /// the quick buttons). When the list is unknown (offline) all are allowed.
    func modeAvailable(_ m: String) -> Bool {
        availableModes.isEmpty || resolvedMode(for: m) != nil
    }

    /// Whether the current rig mode belongs to a quick label's family, so that
    /// e.g. "CW-U" lights up the CW button.
    func isQuickModeActive(_ quick: String) -> Bool {
        modeBase(mode).caseInsensitiveCompare(quick) == .orderedSame
    }

    /// Selects the resolved rig mode for a quick-button label.
    func selectQuickMode(_ quick: String) {
        setMode(resolvedMode(for: quick) ?? quick)
    }

    func setBandwidth(_ bw: String) {
        bandwidth = bw
        Task { await client.setBandwidth(bw) }
    }

    private var lastVolumeSend: Date = .distantPast

    /// Sets AF gain (0…100). Throttles writes during a drag; `commit` forces a
    /// final send on release.
    func setVolume(_ v: Double, commit: Bool = false) {
        volume = min(max(v, 0), 100)
        suppressVolumeReadUntil = Date().addingTimeInterval(1.0)
        guard let m = volSetMethod else { return }
        let now = Date()
        if commit || now.timeIntervalSince(lastVolumeSend) >= 0.1 {
            lastVolumeSend = now
            let level = Int(volume.rounded())
            Task { await client.setInt(m, level) }
        }
    }

    /// Cycles AGC through 0…3 (OFF / FAST / MED / SLOW on most rigs).
    func cycleAGC() {
        guard agcAvailable else { return }
        agcIndex = (agcIndex + 1) % 4
        suppressAgcReadUntil = Date().addingTimeInterval(1.0)
        if let m = agcSetMethod {
            let value = agcIndex
            Task { await client.setInt(m, value) }
        }
    }

    /// Human label for the current AGC index (best-effort; rigs vary).
    var agcLabel: String {
        switch agcIndex {
        case 0: return "OFF"
        case 1: return "FAST"
        case 2: return "MED"
        case 3: return "SLOW"
        default: return "\(agcIndex)"
        }
    }

    // MARK: - Optional receiver controls (squelch / RF-gain / notch)

    private var lastSquelchSend: Date = .distantPast
    private var lastRfSend: Date = .distantPast

    /// Sets the squelch threshold (0…100). Throttles during a drag; `commit`
    /// forces a final send on release.
    func setSquelch(_ v: Double, commit: Bool = false) {
        squelch = min(max(v, 0), 100)
        suppressSquelchReadUntil = Date().addingTimeInterval(1.0)
        guard let m = sqlSetMethod else { return }
        let now = Date()
        if commit || now.timeIntervalSince(lastSquelchSend) >= 0.1 {
            lastSquelchSend = now
            let level = Int(squelch.rounded())
            Task { await client.setInt(m, level) }
        }
    }

    /// Sets the RF gain (0…100). Throttles during a drag; `commit` forces a
    /// final send on release.
    func setRfGain(_ v: Double, commit: Bool = false) {
        rfGain = min(max(v, 0), 100)
        suppressRfReadUntil = Date().addingTimeInterval(1.0)
        guard let m = rfSetMethod else { return }
        let now = Date()
        if commit || now.timeIntervalSince(lastRfSend) >= 0.1 {
            lastRfSend = now
            let level = Int(rfGain.rounded())
            Task { await client.setInt(m, level) }
        }
    }

    /// Toggles the notch filter on/off.
    func toggleNotch() {
        guard notchAvailable else { return }
        notchOn.toggle()
        suppressNotchReadUntil = Date().addingTimeInterval(1.0)
        if let m = notchSetMethod {
            let value = notchOn ? 1 : 0
            Task { await client.setInt(m, value) }
        }
    }

    // MARK: - Highlighting (port of update_view_mode_display colours)

    func highlight(for station: Station) -> Highlight {
        guard abs(station.freqKHz - currentFreqKHz) < 0.01 else { return .normal }
        return station.isActive(at: utcNow) ? .active : .onFrequency
    }

    /// True when no displayed station sits exactly on the dial frequency
    /// (Python inserted a "---- freq" marker in that case).
    var hasExactMatch: Bool {
        displayedStations.contains { abs($0.freqKHz - currentFreqKHz) < 0.01 }
    }

    // MARK: - Filtering

    private func recomputeDisplayed() {
        let target = targetFilter.lowercased()
        let search = searchText.lowercased()
        let now = utcNow

        var result = stations
        if activeOnly { result = result.filter { $0.isActive(at: now) } }
        if !target.isEmpty { result = result.filter { $0.target.lowercased().contains(target) } }
        if !search.isEmpty { result = result.filter { $0.searchHaystack.contains(search) } }
        result.sort { $0.freqKHz < $1.freqKHz }

        displayedStations = result
        recomputeNearby()
    }

    private func recomputeNearby() {
        guard !displayedStations.isEmpty else { nearbyStations = []; return }
        let nearest = displayedStations
            .sorted { abs($0.freqKHz - currentFreqKHz) < abs($1.freqKHz - currentFreqKHz) }
            .prefix(10)
        nearbyStations = nearest.sorted { $0.freqKHz < $1.freqKHz }
    }

    // MARK: - File loading

    /// Presents an NSOpenPanel and loads the chosen EIBI/ILG file.
    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .text]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Open an EIBI or ILG schedule file"
        if panel.runModal() == .OK, let url = panel.url {
            load(url: url, remember: true)
        }
    }

    private func load(url: URL, remember: Bool, displayName: String? = nil) {
        isLoading = true
        loadError = nil
        let name = displayName ?? url.lastPathComponent
        let dest = remember ? cacheURL : nil
        Task {
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            let parsed: (stations: [Station], type: FileType)? = await Task.detached {
                guard let data = try? Data(contentsOf: url) else { return nil }
                // EIBI/ILG files are often Latin-1; fall back like the Python's
                // errors="ignore" read so accented station names don't abort it.
                let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
                    ?? String(decoding: data, as: UTF8.self)
                let result = ScheduleParser.parse(contents: text)
                // Cache a copy inside our sandbox container so we can reload it
                // on next launch without re-prompting (security-scoped bookmarks
                // are unreliable for files on external volumes).
                if !result.stations.isEmpty, let dest { try? data.write(to: dest) }
                return result
            }.value

            await MainActor.run {
                isLoading = false
                guard let parsed, !parsed.stations.isEmpty else {
                    loadError = "Could not read \(name)."
                    return
                }
                if remember { UserDefaults.standard.set(name, forKey: "lastFileName") }
                applyParsed(parsed, fileName: name)
            }
        }
    }

    private func applyParsed(_ parsed: (stations: [Station], type: FileType), fileName: String) {
        stations = parsed.stations
        fileType = parsed.type
        loadedFileName = fileName
        if let lo = stations.map(\.freqKHz).min(), let hi = stations.map(\.freqKHz).max(), hi > lo {
            minFreqKHz = lo
            maxFreqKHz = hi
        }
        lastMinute = -1
        recomputeDisplayed()
    }

    // MARK: - Remembered file (cached inside the sandbox container)

    private var cacheURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EiBi-Tuner", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("lastSchedule.dat")
    }

    private func loadRememberedFile() {
        let cache = cacheURL
        guard FileManager.default.fileExists(atPath: cache.path),
              let name = UserDefaults.standard.string(forKey: "lastFileName") else { return }
        load(url: cache, remember: false, displayName: name)
    }

    // MARK: - Preset persistence

    private static let presetsKey = "presets"

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.presetsKey)
        }
    }

    /// Loads the saved preset slots, padding/truncating to `presetCount` and
    /// falling back to blank "P1…Pn" slots on first run.
    private static func loadPresets() -> [FrequencyPreset] {
        var slots = (1...presetCount).map { FrequencyPreset(name: "P\($0)", freqKHz: nil, mode: nil) }
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([FrequencyPreset].self, from: data) {
            for (i, saved) in decoded.prefix(presetCount).enumerated() { slots[i] = saved }
        }
        return slots
    }
}
