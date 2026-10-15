import AppKit
import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var history: HistoryStore
    @StateObject private var timer: SessionTimer

    init() {
        let history = HistoryStore()
        _history = StateObject(wrappedValue: history)
        _timer = StateObject(wrappedValue: SessionTimer(history: history))
        // Show a Dock icon and window even when launched as a bare executable.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Pomodoro", id: "main") {
            ContentView()
                .environmentObject(timer)
                .environmentObject(history)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(timer)
        } label: {
            Text(timer.menuBarText)
        }

        Settings {
            SettingsView()
                .environmentObject(timer)
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .padding()
        .frame(width: 380, height: 480)
    }
}

struct MenuBarMenu: View {
    @EnvironmentObject private var timer: SessionTimer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let block = timer.currentBlock, timer.state != .idle {
            Text("\(block.kind.rawValue) · Pomodoro \(block.pomodoro)/\(timer.config.totalPomodoros)")
            Divider()
        }
        Button(timer.state == .running ? "Pause" : (timer.state == .paused ? "Resume" : "Start Session")) {
            timer.toggle()
        }
        Button("Skip Block") { timer.skip() }
            .disabled(timer.state == .idle)
        Button("Stop Session") { timer.stop() }
            .disabled(timer.state == .idle)
        Divider()
        Button("Open Pomodoro…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
