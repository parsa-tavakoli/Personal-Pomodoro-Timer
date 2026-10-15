import AppKit
import Foundation
import UserNotifications

/// Runs one big session, stepping through its focus/break blocks.
@MainActor
final class SessionTimer: ObservableObject {
    enum State { case idle, running, paused }

    @Published var config: SessionConfig {
        didSet {
            guard config != oldValue else { return }
            Self.saveConfig(config)
            if state == .idle { reset() }
        }
    }
    @Published private(set) var blocks: [Block] = []
    @Published private(set) var index = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var state: State = .idle
    /// Config snapshot for the running session, so edits in Settings apply to the next one.
    @Published private(set) var sessionConfig = SessionConfig()
    /// Flexible mode: a finished countdown keeps counting up until you choose what's next.
    @Published private(set) var isInOvertime = false
    @Published private(set) var overtime: TimeInterval = 0

    private let history: HistoryStore
    private var endDate: Date?
    private var ticker: Timer?
    private var sessionStart: Date?
    private var focusSeconds: TimeInterval = 0
    private var completedPomodoros = 0
    /// Countdown time used before overtime began (less than the full block if skipped).
    private var countdownElapsed: TimeInterval = 0

    init(history: HistoryStore) {
        self.history = history
        self.config = Self.loadConfig()
        reset()
    }

    // MARK: - Derived

    var currentBlock: Block? { blocks.indices.contains(index) ? blocks[index] : nil }

    var isFlexible: Bool { sessionConfig.mode == .flexible }

    /// 0…1 progress through the current block.
    var blockProgress: Double {
        if isInOvertime { return 1 }
        guard let block = currentBlock, block.duration > 0 else { return 0 }
        return 1 - remaining / block.duration
    }

    var remainingText: String {
        isInOvertime ? "+" + Self.format(overtime) : Self.format(remaining)
    }

    /// Number of pomodoros in the session so far (flexible) or in total (fixed).
    var pomodoroCount: Int {
        isFlexible ? (currentBlock?.pomodoro ?? 1) : sessionConfig.totalPomodoros
    }

    var progressText: String {
        let n = currentBlock?.pomodoro ?? 1
        return isFlexible ? "Pomodoro \(n)" : "Pomodoro \(n) of \(sessionConfig.totalPomodoros)"
    }

    /// Menu bar shows only the time, no icons.
    var menuBarText: String { remainingText }

    // MARK: - Controls

    func start() {
        guard state == .idle else { return resume() }
        requestNotificationPermission()
        reset()
        sessionStart = Date()
        run()
    }

    func pause() {
        guard state == .running, !isInOvertime else { return }
        tick()
        state = .paused
        endDate = nil
        ticker?.invalidate()
    }

    func resume() {
        guard state == .paused else { return }
        run()
    }

    func toggle() {
        switch state {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        }
    }

    /// Ends the current block early. Fixed: moves to the next block.
    /// Flexible: jumps straight to overtime, where you choose what's next.
    func skip() {
        guard state != .idle, !isInOvertime else { return }
        if isFlexible {
            if state == .paused { state = .running; startTicker() }
            endDate = Date()
            enterOvertime()
        } else {
            advance(completedNaturally: false)
        }
    }

    /// Flexible: after a pomodoro's overtime, take a short or long break.
    func continueWithBreak(_ kind: Block.Kind) {
        guard isInOvertime, let block = currentBlock, block.kind == .focus, kind != .focus else { return }
        tick()
        focusSeconds += countdownElapsed + overtime
        completedPomodoros += 1
        blocks.append(Block(kind: kind, duration: sessionConfig.duration(of: kind), pomodoro: block.pomodoro))
        index += 1
        beginCurrentBlock()
    }

    /// Flexible: after a break's overtime, start the next pomodoro.
    func startNextPomodoro() {
        guard isInOvertime, let block = currentBlock, block.kind != .focus else { return }
        blocks.append(Block(kind: .focus, duration: sessionConfig.duration(of: .focus), pomodoro: block.pomodoro + 1))
        index += 1
        beginCurrentBlock()
    }

    /// Ends the whole session and saves what was done.
    func stop() {
        guard state != .idle else { return }
        if state == .running { tick() }
        if isInOvertime {
            // Flexible: the countdown already ran out, so this is a normal ending.
            if currentBlock?.kind == .focus {
                focusSeconds += countdownElapsed + overtime
                completedPomodoros += 1
            }
            finish(finished: true)
            return
        }
        if currentBlock?.kind == .focus, let block = currentBlock {
            focusSeconds += block.duration - remaining
        }
        finish(finished: false)
    }

    // MARK: - Engine

    private func run() {
        state = .running
        endDate = Date().addingTimeInterval(remaining)
        startTicker()
    }

    private func startTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard state == .running, let endDate else { return }
        // Computed from the end date so it stays accurate across sleep.
        let left = endDate.timeIntervalSinceNow
        if isInOvertime {
            overtime = max(0, (-left).rounded(.down))
            return
        }
        remaining = max(0, left.rounded(.up))
        guard remaining <= 0 else { return }
        if isFlexible { enterOvertime() } else { advance(completedNaturally: true) }
    }

    /// Countdown is over; keep counting up from `endDate` until the user decides.
    private func enterOvertime() {
        guard let block = currentBlock else { return }
        countdownElapsed = block.duration - remaining
        remaining = 0
        overtime = 0
        isInOvertime = true
        if block.kind == .focus {
            notify(title: "Pomodoro \(block.pomodoro) done 🍅", body: "Take a short or long break when you're ready.")
        } else {
            notify(title: "Break over ☕️", body: "Start the next pomodoro when you're ready.")
        }
    }

    private func beginCurrentBlock() {
        isInOvertime = false
        overtime = 0
        countdownElapsed = 0
        remaining = currentBlock?.duration ?? 0
        endDate = Date().addingTimeInterval(remaining)
    }

    private func advance(completedNaturally: Bool) {
        guard let block = currentBlock else { return }
        if block.kind == .focus {
            focusSeconds += completedNaturally ? block.duration : block.duration - remaining
            if completedNaturally { completedPomodoros += 1 }
        }

        index += 1
        guard let next = currentBlock else {
            notify(title: "Session complete 🎉", body: "\(completedPomodoros) pomodoros done.")
            finish(finished: true)
            return
        }

        if completedNaturally {
            notify(title: "\(block.kind.rawValue) finished", body: "Next: \(next.kind.rawValue) (\(Self.format(next.duration)))")
        }
        remaining = next.duration
        if state == .running { endDate = Date().addingTimeInterval(remaining) }
    }

    private func finish(finished: Bool) {
        // Ignore sessions with under a minute of focus (accidental start/stop).
        if let sessionStart, focusSeconds >= 60 {
            history.add(SessionRecord(
                startedAt: sessionStart,
                endedAt: Date(),
                config: sessionConfig,
                completedPomodoros: completedPomodoros,
                focusSeconds: focusSeconds,
                finished: finished
            ))
        }
        reset()
    }

    private func reset() {
        ticker?.invalidate()
        ticker = nil
        state = .idle
        endDate = nil
        sessionStart = nil
        focusSeconds = 0
        completedPomodoros = 0
        isInOvertime = false
        overtime = 0
        countdownElapsed = 0
        sessionConfig = config
        blocks = Session.blocks(for: config)
        index = 0
        remaining = blocks.first?.duration ?? 0
    }

    // MARK: - Notifications

    /// Notifications need a real app bundle; skip them when run via `swift run`.
    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil }

    private func requestNotificationPermission() {
        guard canNotify else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        NSSound(named: "Glass")?.play()
        guard canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private static let configKey = "sessionConfig"

    private static func loadConfig() -> SessionConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(SessionConfig.self, from: data) else { return SessionConfig() }
        return config
    }

    private static func saveConfig(_ config: SessionConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
}
