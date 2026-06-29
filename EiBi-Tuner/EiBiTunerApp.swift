//
//  EiBiTunerApp.swift
//  EiBi-Tuner
//
//  App entry point. Owns the RadioViewModel, wires the File ▸ Open command,
//  and an About panel crediting the original author.
//

import SwiftUI
import AppKit

@main
struct EiBiTunerApp: App {
    @State private var vm = RadioViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .onAppear { vm.start() }
                .background(WindowConfigurator())
        }
        .defaultSize(width: 1140, height: 880)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Schedule…") { vm.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About EiBi-Tuner") { showAbout() }
            }
        }
    }

    private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "EiBi-Tuner",
            .applicationVersion: "1.0",
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"):
                "A retro shortwave tuner for FLRIG.\nBased on eibi_tuner by Peter Betz (DD2ZG).",
        ])
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
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
