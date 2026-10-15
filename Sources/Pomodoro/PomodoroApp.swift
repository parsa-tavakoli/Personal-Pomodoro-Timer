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
                .preferredColorScheme(.dark)
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
                .preferredColorScheme(.dark)
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
            case .history: return "calendar"
            case .stats: return "chart.bar"
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
        .padding(.horizontal, Theme.Space.screen)
        .padding(.vertical, Theme.Space.m)
        .frame(width: 380, height: 460)
        .foregroundStyle(Theme.Palette.textPrimary)
        .font(Theme.Fonts.body(13))
        // Flat ink background (design spec); glass stays on the controls only.
        .background(Theme.Palette.background)
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
                .tint(Theme.Palette.accent)
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Timer settings")
                .help("Timer settings")
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
