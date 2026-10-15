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
    enum Page: String, CaseIterable {
        case timer = "Timer"
        case history = "History"
        case stats = "Stats"

        var symbol: String {
            switch self {
            case .timer: return "timer"
            case .history: return "clock.arrow.circlepath"
            case .stats: return "chart.bar.xaxis"
            }
        }
    }

    @AppStorage("selectedPage") private var page: Page = .timer

    var body: some View {
        Group {
            switch page {
            case .timer: TimerView()
            case .history: HistoryView()
            case .stats: StatsView()
            }
        }
        .padding()
        .frame(width: 380, height: 460)
        .background { AmbientBackground() }
        .toolbar {
            // Toolbar items get Liquid Glass automatically.
            ToolbarItem(placement: .principal) {
                Picker("Page", selection: $page) {
                    ForEach(Page.allCases, id: \.self) { page in
                        Label(page.rawValue, systemImage: page.symbol).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleAndIcon)
            }
        }
        .toolbar(removing: .title)
    }
}

struct MenuBarMenu: View {
    @EnvironmentObject private var timer: SessionTimer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let block = timer.currentBlock, timer.state != .idle {
            let name = timer.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
            Text("\(name.isEmpty ? "" : name + " · ")\(block.kind.rawValue)\(timer.isInOvertime ? " · Overtime" : "") · \(timer.progressText)")
            Divider()
        }
        Button(timer.state == .running ? "Pause" : (timer.state == .paused ? "Resume" : "Start Session")) {
            timer.toggle()
        }
        .disabled(timer.isInOvertime)
        Button("Skip Block") { timer.skip() }
            .disabled(timer.state == .idle || timer.isInOvertime)
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
