//
//  HelpView.swift
//  EiBi-Tuner
//
//  The Help window: a themed, sectioned guide to every control in the tuner.
//  A sidebar lists the topics; the detail pane renders the selected one as a
//  series of illustrated "cards". Opened from the HELP button (and Help menu).
//

import SwiftUI
import AppKit

// MARK: - Content model

private struct HelpItem: Identifiable {
    let id = UUID()
    var term: String? = nil      // bold lead-in
    var symbol: String? = nil    // optional SF symbol bullet
    var detail: String
}

private struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    var intro: String? = nil
    var items: [HelpItem] = []
}

// MARK: - View

struct HelpView: View {
    @State private var selection: HelpSection.ID?

    private let sections = HelpView.allSections

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle(AppLanguage.t("EiBi-Tuner · Hilfe", "EiBi-Tuner · Help"))
        .frame(minWidth: 760, minHeight: 560)
        .background(Theme.cabinet)
        .background(HelpWindowFronter())
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(sections, selection: $selection) { section in
            Label(section.title, systemImage: section.icon)
                .font(Theme.label(12))
                .foregroundStyle(Theme.ivory.opacity(0.9))
                .tag(section.id)
                .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.cabinetPanel)
        .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 2) {
                Divider().overlay(Theme.brassDark)
                Text("Version 2.0")
                    .font(Theme.label(10)).tracking(1)
                    .foregroundStyle(Theme.amber.opacity(0.8))
                Text("© DD2ZG · Peter Betz")
                    .font(.system(size: 9, design: .serif))
                    .foregroundStyle(Theme.ivory.opacity(0.5))
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.cabinetPanel)
        }
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let id = selection ?? sections.first?.id,
           let section = sections.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sectionHeader(section)
                    if let intro = section.intro {
                        Text(intro)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Theme.ivory.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(section.items) { item in
                        HelpItemRow(item: item)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.dialBackdrop)
        } else {
            Text(AppLanguage.t("Thema wählen", "Select a topic"))
                .foregroundStyle(Theme.amberDim)
        }
    }

    private func sectionHeader(_ section: HelpSection) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.brassBezel)
                    .frame(width: 48, height: 48)
                Image(systemName: section.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black.opacity(0.72))
            }
            Text(section.title)
                .font(.system(size: 26, weight: .heavy, design: .serif))
                .foregroundStyle(Theme.ivory)
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Item row

private struct HelpItemRow: View {
    let item: HelpItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbol ?? "circle.fill")
                .font(.system(size: item.symbol == nil ? 6 : 14, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .frame(width: 18)
                .padding(.top, item.symbol == nil ? 6 : 2)
            VStack(alignment: .leading, spacing: 3) {
                if let term = item.term {
                    Text(term)
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.amberBright)
                }
                Text(item.detail)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Theme.ivory.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black.opacity(0.28))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.brassDark.opacity(0.6), lineWidth: 1))
        )
    }
}

// MARK: - Bring the window to the front when it opens

/// `openWindow` can place a freshly-created Window scene behind the main
/// window; this nudges the hosting window to the front when Help appears.
private struct HelpWindowFronter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let window = v.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Content

/// File-local shorthand for the German / English string pair.
private func t(_ de: String, _ en: String) -> String { AppLanguage.t(de, en) }

private extension HelpView {
    static var allSections: [HelpSection] {
        [
            HelpSection(
                title: t("Willkommen", "Welcome"),
                icon: "antenna.radiowaves.left.and.right",
                intro: t("EiBi-Tuner ist ein Empfänger-Pult im Stil eines alten Röhrenradios, das deinen Transceiver über FLRIG fernsteuert und dazu die Sendepläne der EiBi- bzw. ILG-Datenbank einblendet. Du drehst an der Skala – die App stimmt den Rig ab und zeigt dir, welche Stationen gerade auf dieser Frequenz senden.",
                         "EiBi-Tuner is a receiver console styled like an old valve radio that remote-controls your transceiver through FLRIG and overlays the broadcast schedules from the EiBi / ILG database. You turn the dial — the app tunes the rig and shows which stations are transmitting on that frequency right now."),
                items: [
                    HelpItem(term: t("So fängst du an", "Getting started"), symbol: "1.circle.fill",
                             detail: t("Starte FLRIG und verbinde es mit deinem Rig. Trage unten bei FLRIG die HOST-Adresse und den PORT ein (Standard: 127.0.0.1 : 12345). Leuchtet die Lampe „FLRIG ONLINE“, ist die Verbindung aktiv.",
                                       "Start FLRIG and connect it to your rig. Enter the HOST address and PORT under FLRIG below (default: 127.0.0.1 : 12345). When the “FLRIG ONLINE” lamp is lit, the connection is active.")),
                    HelpItem(term: t("Sendeplan laden", "Load a schedule"), symbol: "2.circle.fill",
                             detail: t("Öffne über „Open Schedule…“ (oder ⌘O) eine EiBi- oder ILG-Datei. Danach erscheinen die Stationen auf der Skala und in der Stationsliste.",
                                       "Open an EiBi or ILG file via “Open Schedule…” (or ⌘O). The stations then appear on the dial and in the station list.")),
                    HelpItem(term: t("Abstimmen", "Tuning"), symbol: "3.circle.fill",
                             detail: t("Ziehe an der Skala oder nutze das Mausrad über Skala bzw. Abstimmknopf. Mit den Band- und Preset-Knöpfen springst du blitzschnell an die gewünschte Stelle.",
                                       "Drag the dial or use the mouse wheel over the dial or tuning knob. The Band and Preset buttons jump you instantly to the spot you want.")),
                ]),

            HelpSection(
                title: t("Abstimmen & Skala", "Tuning & Dial"),
                icon: "dial.medium.fill",
                intro: t("Die große, amberfarbene Skala ist das Herz des Geräts. Ein fester roter Index in der Mitte markiert die aktuelle Empfangsfrequenz; die Frequenzlinie wandert beim Abstimmen darunter durch.",
                         "The large amber dial is the heart of the set. A fixed red index in the centre marks the current receive frequency; the frequency scale scrolls underneath it as you tune."),
                items: [
                    HelpItem(term: t("Ziehen", "Drag"), symbol: "hand.draw.fill",
                             detail: t("Mit gedrückter Maustaste die Skala nach links/rechts ziehen, um kontinuierlich abzustimmen. FLRIG folgt dabei in Echtzeit (mit kurzer Drosselung, damit der Rig nicht überlastet wird).",
                                       "Hold the mouse button and drag the dial left/right to tune continuously. FLRIG follows in real time (lightly throttled so the rig isn’t flooded).")),
                    HelpItem(term: t("Mausrad", "Mouse wheel"), symbol: "computermouse.fill",
                             detail: t("Zeiger über Skala oder Abstimmknopf halten und scrollen – jede Rastung verstimmt um 1 kHz. Kurz nach dem Loslassen rastet die Frequenz (siehe SNAP) auf die nächste Station ein.",
                                       "Hover over the dial or tuning knob and scroll — each detent shifts by 1 kHz. Shortly after you stop, the frequency snaps (see SNAP) to the nearest station.")),
                    HelpItem(term: t("Stations-Schildchen", "Station tags"), symbol: "tag.fill",
                             detail: t("Die naheliegenden Stationen erscheinen als beschriftete Schildchen entlang der Skala. Ein Klick darauf stimmt direkt auf diese Frequenz ab.",
                                       "Nearby stations appear as labelled tags along the dial. Click one to tune straight to that frequency.")),
                    HelpItem(term: t("Abstimmknopf", "Tuning knob"), symbol: "circle.circle",
                             detail: t("Der große geriffelte Knopf rechts dient zum Feinabstimmen, der Empfindlichkeit der Skala vergleichbar.",
                                       "The large knurled knob on the right is for fine-tuning, comparable to the sensitivity of the dial.")),
                ]),

            HelpSection(
                title: t("Stationsliste", "Station list"),
                icon: "list.bullet.rectangle.fill",
                intro: t("Rechts neben der Skala listet das Pult die bis zu zehn Stationen, die der aktuellen Frequenz am nächsten liegen – gut lesbar mit Frequenz, Name, Sprache/Ziel und Sendezeit.",
                         "To the right of the dial the console lists up to ten stations closest to the current frequency — clearly showing frequency, name, language/target and broadcast time."),
                items: [
                    HelpItem(term: t("Weiß hervorgehoben", "Highlighted white"), symbol: "circle.fill",
                             detail: t("Diese Station liegt exakt auf der eingestellten Frequenz.",
                                       "This station sits exactly on the tuned frequency.")),
                    HelpItem(term: t("Amber „ON AIR“", "Amber “ON AIR”"), symbol: "dot.radiowaves.left.and.right",
                             detail: t("Die Station sendet laut Sendeplan genau jetzt (Uhrzeit und Wochentag stimmen). Die Bewertung erfolgt in UTC.",
                                       "The station is on the air right now according to the schedule (time and weekday match). Evaluation is in UTC.")),
                    HelpItem(term: t("Klick zum Abstimmen", "Click to tune"), symbol: "hand.tap.fill",
                             detail: t("Ein Klick auf eine Zeile stimmt FLRIG sofort auf diese Station ab.",
                                       "Click a row to tune FLRIG to that station immediately.")),
                ]),

            HelpSection(
                title: t("Bänder", "Bands"),
                icon: "square.stack.3d.up.fill",
                intro: t("Der BAND-Knopf öffnet ein Fenster mit allen Kurzwellen-Meterbändern. Sie sind farblich getrennt: Rundfunkbänder in Amber, Amateurfunkbänder in Phosphor-Grün.",
                         "The BAND button opens a window with all shortwave meter bands. They are colour-coded: broadcast bands in amber, amateur bands in phosphor green."),
                items: [
                    HelpItem(term: t("Rundfunkbänder", "Broadcast bands"), symbol: "radio.fill",
                             detail: t("LW, MW und die SW-Meterbänder von 120 m bis 11 m (z. B. 49 m, 41 m, 31 m, 25 m, 19 m …) – die klassischen Broadcast-Bereiche.",
                                       "LW, MW and the SW meter bands from 120 m to 11 m (e.g. 49 m, 41 m, 31 m, 25 m, 19 m …) — the classic broadcast ranges.")),
                    HelpItem(term: t("Amateurfunkbänder", "Amateur bands"), symbol: "antenna.radiowaves.left.and.right",
                             detail: "160 m, 80 m, 60 m, 40 m, 30 m, 20 m, 17 m, 15 m, 12 m, 10 m."),
                    HelpItem(term: t("Sprung ins Band", "Jump to a band"), symbol: "arrow.right.circle.fill",
                             detail: t("Ein Klick auf ein Band stimmt auf dessen Mitte ab. Enthält der geladene Sendeplan eine Station in diesem Band, landest du direkt auf der bandmittennächsten Station. Unter jedem Knopf steht der Frequenzbereich.",
                                       "Clicking a band tunes to its centre. If the loaded schedule has a station inside that band, you land directly on the station nearest the band centre. The frequency range is shown under each button.")),
                ]),

            HelpSection(
                title: "Presets",
                icon: "square.grid.3x3.fill",
                intro: t("Der PRESET-Knopf öffnet 20 frei belegbare Speicherplätze für deine Lieblingsfrequenzen. Jeder Platz lässt sich benennen, speichern, abrufen und wieder löschen.",
                         "The PRESET button opens 20 freely assignable memory slots for your favourite frequencies. Each slot can be named, stored, recalled and cleared again."),
                items: [
                    HelpItem(term: t("Speichern (2 s halten)", "Store (hold 2 s)"), symbol: "square.and.arrow.down.fill",
                             detail: t("Stimme zuerst auf die gewünschte Frequenz ab. Halte dann einen Preset-Knopf gedrückt: ein Balken läuft im Knopf nach oben. Nach zwei Sekunden blinkt der Knopf – die aktuelle Frequenz (samt Betriebsart) ist gespeichert. Lässt du vorher los, passiert nichts.",
                                       "First tune to the frequency you want. Then press and hold a preset button: a bar rises inside it. After two seconds the button blinks — the current frequency (and mode) is stored. Release earlier and nothing happens.")),
                    HelpItem(term: t("Abrufen (tippen)", "Recall (tap)"), symbol: "hand.tap.fill",
                             detail: t("Ein kurzer Klick auf einen belegten Knopf stimmt sofort auf die gespeicherte Frequenz ab und stellt – wenn möglich – die gespeicherte Betriebsart wieder her.",
                                       "A short click on a filled button tunes to the stored frequency immediately and — where possible — restores the stored mode.")),
                    HelpItem(term: t("Benennen", "Rename"), symbol: "pencil",
                             detail: t("Klicke in das Textfeld über dem Knopf und tippe einen eigenen Namen ein, z. B. „BBC 49 m“ oder „DWD Wetter“.",
                                       "Click the text field above the button and type your own name, e.g. “BBC 49 m” or “Weather Fax”.")),
                    HelpItem(term: t("Löschen", "Delete"), symbol: "trash",
                             detail: t("Rechtsklick auf einen Knopf öffnet das Kontextmenü mit „Löschen“. Der Name bleibt erhalten, nur die Frequenz wird entfernt.",
                                       "Right-click a button to open the context menu with “Delete”. The name is kept, only the frequency is removed.")),
                ]),

            HelpSection(
                title: t("Betriebsart, Bandbreite & AGC", "Mode, Bandwidth & AGC"),
                icon: "waveform",
                intro: t("Diese Regler spiegeln die Einstellungen deines Rigs über FLRIG wider und schreiben Änderungen zurück.",
                         "These controls mirror your rig’s settings through FLRIG and write changes back."),
                items: [
                    HelpItem(term: t("Schnellwahl-Tasten", "Quick keys"), symbol: "square.fill",
                             detail: t("Oben rechts liegen USB, LSB, AM und CW als Direkttasten. Nicht vom Rig unterstützte Modi sind ausgegraut.",
                                       "USB, LSB, AM and CW sit at the top right as direct keys. Modes the rig doesn’t support are greyed out.")),
                    HelpItem(term: "MODE & BANDWIDTH", symbol: "slider.horizontal.3",
                             detail: t("Unten lassen sich Betriebsart und Bandbreite aus den vom Rig gemeldeten Listen auswählen.",
                                       "At the bottom you can pick the mode and bandwidth from the lists reported by the rig.")),
                    HelpItem(term: "AGC", symbol: "gauge.with.dots.needle.50percent",
                             detail: t("Tippt durch die Regelzeitkonstanten (OFF / FAST / MED / SLOW), sofern der Rig AGC über FLRIG anbietet.",
                                       "Cycles through the AGC time constants (OFF / FAST / MED / SLOW), if the rig exposes AGC through FLRIG.")),
                ]),

            HelpSection(
                title: t("Lautstärke & S-Meter", "Volume & S-Meter"),
                icon: "speaker.wave.3.fill",
                intro: t("Die Hardware-Anmutung setzt sich bei Pegel und Anzeige fort.",
                         "The hardware feel continues with the level and the meter."),
                items: [
                    HelpItem(term: t("VOLUME-Knopf", "VOLUME knob"), symbol: "dial.low.fill",
                             detail: t("Der rechte Drehknopf stellt die NF-Verstärkung (0…100) ein, sofern der Rig sie über FLRIG meldet – sonst ist er ausgegraut.",
                                       "The right-hand knob sets the AF gain (0…100), if the rig reports it through FLRIG — otherwise it is greyed out.")),
                    HelpItem(term: "S-Meter", symbol: "gauge.with.needle.fill",
                             detail: t("Die Anzeige folgt dem von FLRIG gemeldeten Signalpegel. Bei Verbindungsabbruch fällt die Nadel sanft zurück.",
                                       "The meter follows the signal level reported by FLRIG. On connection loss the needle falls back gently.")),
                ]),

            HelpSection(
                title: t("Filter & Suche", "Filters & Search"),
                icon: "line.3.horizontal.decrease.circle.fill",
                intro: t("Mit den Filtern verkleinerst du die angezeigte Stationsmenge, ganz ohne die Datei neu zu laden.",
                         "The filters narrow down the displayed set of stations without reloading the file."),
                items: [
                    HelpItem(term: "TARGET", symbol: "globe.europe.africa.fill",
                             detail: t("Filtert nach Zielgebiet (z. B. „Eu“ für Europa). Es werden nur Stationen mit passendem Zielgebiet angezeigt.",
                                       "Filters by target area (e.g. “Eu” for Europe). Only stations with a matching target are shown.")),
                    HelpItem(term: "SEARCH", symbol: "magnifyingglass",
                             detail: t("Volltextsuche über Frequenz, Stationsname, Sprache, Ziel und Bemerkungen.",
                                       "Full-text search across frequency, station name, language, target and remarks.")),
                    HelpItem(term: "ACTIVE now", symbol: "clock.fill",
                             detail: t("Zeigt nur Stationen, die laut Sendeplan gerade jetzt (UTC) auf Sendung sind. Die Liste aktualisiert sich minütlich.",
                                       "Shows only stations that are on the air right now (UTC) according to the schedule. The list refreshes every minute.")),
                    HelpItem(term: "SNAP station", symbol: "scope",
                             detail: t("Ist SNAP aktiv, rastet die Frequenz nach dem Abstimmen automatisch auf die nächste Station ein. Aus für freies, stufenloses Abstimmen.",
                                       "When SNAP is on, the frequency snaps to the nearest station after tuning. Turn it off for free, continuous tuning.")),
                ]),

            HelpSection(
                title: t("FLRIG-Verbindung", "FLRIG connection"),
                icon: "cable.connector.horizontal",
                intro: t("EiBi-Tuner spricht über das XML-RPC-Protokoll mit FLRIG und fragt rund einmal pro Sekunde Frequenz, Betriebsart, Bandbreite, Pegel und (falls vorhanden) Lautstärke/AGC ab.",
                         "EiBi-Tuner talks to FLRIG over the XML-RPC protocol, polling frequency, mode, bandwidth, level and (if available) volume/AGC about once per second."),
                items: [
                    HelpItem(term: "HOST / PORT", symbol: "network",
                             detail: t("Adresse und Port deiner FLRIG-Instanz. Auf demselben Rechner ist das 127.0.0.1 : 12345. Die Werte werden gespeichert.",
                                       "Address and port of your FLRIG instance. On the same machine that’s 127.0.0.1 : 12345. The values are saved.")),
                    HelpItem(term: t("Online-Lampe", "Online lamp"), symbol: "lightbulb.fill",
                             detail: t("Leuchtet, sobald FLRIG antwortet. Erlischt sie, prüfe, ob FLRIG läuft und mit dem Rig verbunden ist.",
                                       "Lights up as soon as FLRIG responds. If it goes dark, check that FLRIG is running and connected to the rig.")),
                    HelpItem(term: t("Zwei-Wege-Steuerung", "Two-way control"), symbol: "arrow.left.arrow.right",
                             detail: t("Drehst du in FLRIG oder am Rig, folgt die Skala automatisch – und umgekehrt.",
                                       "Tune in FLRIG or on the rig and the dial follows automatically — and vice versa.")),
                ]),

            HelpSection(
                title: t("Sendepläne laden", "Loading schedules"),
                icon: "folder.fill",
                intro: t("EiBi-Tuner liest die frei verfügbaren Frequenzlisten der EiBi-Datenbank sowie ILG-Dateien.",
                         "EiBi-Tuner reads the freely available frequency lists from the EiBi database as well as ILG files."),
                items: [
                    HelpItem(term: t("Öffnen", "Open"), symbol: "doc.badge.plus",
                             detail: t("„Open Schedule…“ unten rechts oder Menü „File“ bzw. ⌘O. Die geladene Datei steht klein neben dem Knopf.",
                                       "“Open Schedule…” at the bottom right, or the “File” menu / ⌘O. The loaded file is shown small next to the button.")),
                    HelpItem(term: t("Formate", "Formats"), symbol: "doc.text.fill",
                             detail: t("EiBi-CSV und ILG werden automatisch erkannt. Auch nicht-UTF-8-Dateien (Latin-1) werden korrekt eingelesen, damit Sonderzeichen in Stationsnamen erhalten bleiben.",
                                       "EiBi CSV and ILG are detected automatically. Non-UTF-8 files (Latin-1) are read correctly too, so special characters in station names are preserved.")),
                    HelpItem(term: t("Merken", "Remembered"), symbol: "clock.arrow.circlepath",
                             detail: t("Die zuletzt geöffnete Datei wird in der App gespeichert und beim nächsten Start automatisch wieder geladen.",
                                       "The last opened file is stored in the app and reloaded automatically on the next launch.")),
                ]),

            HelpSection(
                title: t("Einstellungen merken", "Remembered settings"),
                icon: "externaldrive.fill.badge.checkmark",
                intro: t("EiBi-Tuner merkt sich deine Sitzung und stellt sie beim nächsten Start wieder her.",
                         "EiBi-Tuner remembers your session and restores it on the next launch."),
                items: [
                    HelpItem(symbol: "checkmark.circle.fill",
                             detail: t("Zuletzt eingestellte Frequenz und Betriebsart.", "Last tuned frequency and mode.")),
                    HelpItem(symbol: "checkmark.circle.fill",
                             detail: t("Alle 20 Presets samt Namen.", "All 20 presets including their names.")),
                    HelpItem(symbol: "checkmark.circle.fill",
                             detail: t("FLRIG HOST und PORT.", "FLRIG HOST and PORT.")),
                    HelpItem(symbol: "checkmark.circle.fill",
                             detail: t("Die Schalter SNAP und ACTIVE now.", "The SNAP and ACTIVE now switches.")),
                    HelpItem(symbol: "checkmark.circle.fill",
                             detail: t("Die zuletzt geladene Sendeplan-Datei.", "The last loaded schedule file.")),
                ]),

            HelpSection(
                title: t("Über & Tastatur", "About & Keyboard"),
                icon: "info.circle.fill",
                intro: t("EiBi-Tuner Version 2.0 – ein nostalgischer Kurzwellenempfänger für FLRIG.",
                         "EiBi-Tuner version 2.0 — a nostalgic shortwave receiver for FLRIG."),
                items: [
                    HelpItem(term: t("Tastatur", "Keyboard"), symbol: "keyboard.fill",
                             detail: t("⌘O öffnet einen Sendeplan.", "⌘O opens a schedule.")),
                    HelpItem(term: t("Autor", "Author"), symbol: "person.fill",
                             detail: t("Entwickelt von Peter Betz, DD2ZG. Basiert auf dem Original „eibi_tuner“.",
                                       "Developed by Peter Betz, DD2ZG. Based on the original “eibi_tuner”.")),
                    HelpItem(term: t("Daten", "Data"), symbol: "globe",
                             detail: t("Die Sendepläne stammen aus der EiBi-Datenbank (eibspace) und kompatiblen ILG-Listen. Vielen Dank an die Betreiber dieser Sammlungen.",
                                       "The schedules come from the EiBi database (eibspace) and compatible ILG lists. Many thanks to the maintainers of these collections.")),
                ]),
        ]
    }
}
