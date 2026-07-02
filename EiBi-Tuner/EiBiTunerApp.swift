//
//  EiBiTunerApp.swift
//  EiBi-Tuner
//
//  App entry point. Owns the RadioViewModel, wires the File ▸ Open command,
//  and an About panel crediting the original author.
//

import SwiftUI
import AppKit

/// The cabinet's fixed design size: also its aspect ratio (window resizing is
/// locked to this ratio) and its minimum window size.
enum CabinetAspect {
    static let width: CGFloat = 1140
    static let height: CGFloat = 880
    static var ratio: CGFloat { width / height }
}

@main
struct EiBiTunerApp: App {
    @State private var vm = RadioViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .onAppear { vm.start() }
                .background(WindowConfigurator())
        }
        .defaultSize(width: CabinetAspect.width, height: CabinetAspect.height)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Schedule…") { vm.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About EiBi-Tuner") { showAbout() }
            }
            CommandGroup(replacing: .help) {
                HelpMenuCommands()
            }
        }

        // Dedicated, reusable Help window opened from the HELP button / menu.
        Window("EiBi-Tuner · Hilfe", id: "help") {
            HelpView()
        }
        .windowResizability(.contentMinSize)
    }

    private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "EiBi-Tuner",
            .applicationVersion: "2.0",
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"):
                "A retro shortwave tuner for FLRIG.\nVersion 2.0 · created by Peter Betz (DD2ZG).",
        ])
    }
}

/// The Help menu entry; lives in a view so it can use the openWindow action.
private struct HelpMenuCommands: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button(AppLanguage.t("EiBi-Tuner Hilfe", "EiBi-Tuner Help")) { openWindow(id: "help") }
            .keyboardShortcut("?", modifiers: .command)
    }
}

/// Gives the window an appliance feel (unified dark title bar).
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let window = v.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(red: 0.09, green: 0.05, blue: 0.028, alpha: 1)
            // Must stay false: dragging the background would otherwise steal the
            // knob/dial drag gestures. The window still moves via its title bar.
            window.isMovableByWindowBackground = false
            // Single fresh window per launch (no duplicate from state restoration).
            window.isRestorable = false
            // Launch size doubles as the hard floor, and AppKit keeps that exact
            // aspect ratio locked while dragging any edge/corner larger. Setting
            // this once and never touching it again also matters: toggling it
            // from a windowWillEnter/didExitFullScreen hook (delegate- or
            // notification-based) reliably left the window stuck unable to
            // leave fullscreen again — AppKit is fine with the constraint being
            // simply present throughout the whole fullscreen lifecycle.
            let launchSize = NSSize(width: CabinetAspect.width, height: CabinetAspect.height)
            window.contentMinSize = launchSize
            window.contentAspectRatio = launchSize
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
