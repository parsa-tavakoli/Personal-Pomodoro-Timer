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
    /// Ticking values live in `clock`, so views that don't show the time
    /// (e.g. the glass controls) aren't redrawn twice a second.
    let clock = TimerClock()
    private(set) var remaining: TimeInterval {
        get { clock.remaining }
        set { clock.remaining = newValue }
    }
    @Published private(set) var state: State = .idle
    /// Config snapshot for the running session, so edits in Settings apply to the next one.
    @Published private(set) var sessionConfig = SessionConfig()
    /// Flexible mode: a finished countdown keeps counting up until you choose what's next.
    @Published private(set) var isInOvertime = false
    private(set) var overtime: TimeInterval {
        get { clock.overtime }
        set { clock.overtime = newValue }
    }
    /// Optional name for the big session; editable before and during it.
    @Published var sessionName = ""

    private let history: HistoryStore
    private var endDate: Date?
    private var ticker: Timer?
    private var sessionStart: Date?
    private var focusSeconds: TimeInterval = 0
    private var completedPomodoros = 0
    /// Countdown time used before overtime began (less than the full block if skipped).
    private var countdownElapsed: TimeInterval = 0

    /// Block log for the History timeline: finished segments, plus the start of the open one.
    @Published private(set) var blockLog: [LoggedBlock] = []
    @Published private(set) var segmentStart: Date?

    private let notificationDelegate = NotificationDelegate()
    private var activationObserver: NSObjectProtocol?

    init(history: HistoryStore) {
        self.history = history
        self.config = Self.loadConfig()
        reset()
        if canNotify {
            UNUserNotificationCenter.current().delegate = notificationDelegate
            // Opening the app counts as having seen its notifications.
            activationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.clearNotifications() }
            }
        }
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

    /// The running session's blocks so far, including the segment in progress.
    func liveBlocks(now: Date = Date()) -> [LoggedBlock] {
        guard let segmentStart, let kind = currentBlock?.kind else { return blockLog }
        return blockLog + [LoggedBlock(start: segmentStart, end: now, kind: kind)]
    }

    var sessionStartedAt: Date? { sessionStart }

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
        closeSegment()
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
            if state == .paused { state = .running; startTicker(); openSegment() }
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
        closeSegment()
        blocks.append(Block(kind: kind, duration: sessionConfig.duration(of: kind), pomodoro: block.pomodoro))
        index += 1
        beginCurrentBlock()
        openSegment()
    }

    /// Flexible: after a break's overtime, start the next pomodoro.
    func startNextPomodoro() {
        guard isInOvertime, let block = currentBlock, block.kind != .focus else { return }
        closeSegment()
        blocks.append(Block(kind: .focus, duration: sessionConfig.duration(of: .focus), pomodoro: block.pomodoro + 1))
        index += 1
        beginCurrentBlock()
        openSegment()
    }

    /// Ends the whole session and saves what was done.
    func stop() {
        guard state != .idle else { return }
        clearNotifications()
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
        openSegment()
    }

    private func openSegment() {
        guard state == .running, segmentStart == nil else { return }
        segmentStart = Date()
    }

    /// Ends the open segment, logging it under the current block's kind.
    private func closeSegment() {
        guard let start = segmentStart else { return }
        segmentStart = nil
        guard let kind = currentBlock?.kind else { return }
        let end = Date()
        if end.timeIntervalSince(start) >= 1 {
            blockLog.append(LoggedBlock(start: start, end: end, kind: kind))
        }
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
            notify(title: "Pomodoro \(block.pomodoro) complete",
                   body: "Nice work. Take a short or long break when you're ready.")
        } else {
            notify(title: "Break's over",
                   body: "Ready for pomodoro \(block.pomodoro + 1)? Start whenever you are.")
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

        closeSegment()
        index += 1
        guard let next = currentBlock else {
            let count = "\(completedPomodoros) pomodoro\(completedPomodoros == 1 ? "" : "s")"
            notify(title: "Session complete",
                   body: "\(count) · \(formatDuration(focusSeconds)) of focus. Well done.")
            finish(finished: true)
            return
        }

        if completedNaturally {
            let total = sessionConfig.totalPomodoros
            let length = Self.minutes(next.duration)
            switch next.kind {
            case .shortBreak, .longBreak:
                notify(title: next.kind == .shortBreak ? "Time for a short break" : "Time for a long break",
                       body: "\(length) · pomodoro \(block.pomodoro) of \(total) done")
            case .focus:
                notify(title: "Back to focus",
                       body: "\(length) · pomodoro \(next.pomodoro) of \(total)")
            }
        }
        remaining = next.duration
        if state == .running {
            endDate = Date().addingTimeInterval(remaining)
            openSegment()
        }
    }

    private func finish(finished: Bool) {
        closeSegment()
        // Ignore sessions with under a minute of focus (accidental start/stop).
        if let sessionStart, focusSeconds >= 60 {
            history.add(SessionRecord(
                startedAt: sessionStart,
                endedAt: Date(),
                config: sessionConfig,
                completedPomodoros: completedPomodoros,
                focusSeconds: focusSeconds,
                finished: finished,
                name: sessionName.trimmingCharacters(in: .whitespacesAndNewlines),
                blocks: blockLog
            ))
        }
        // Cleared here, not in reset(): start() resets, and must keep a name typed beforehand.
        sessionName = ""
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
        blockLog = []
        segmentStart = nil
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
        let name = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { content.subtitle = name }
        // Only the latest status matters: drop earlier ones (which otherwise pile up in
        // Notification Center and stack behind each new banner), and reuse one ID so
        // macOS replaces rather than adds.
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil)
        center.add(request)
    }

    private static let notificationID = "pomodoro.status"

    /// Removes Pomodoro's own delivered notifications (never other apps').
    private func clearNotifications() {
        guard canNotify else { return }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    /// "1 minute", "25 minutes".
    static func minutes(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        return "\(m) minute\(m == 1 ? "" : "s")"
    }

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

/// Shows banners even while Pomodoro is the frontmost app (macOS hides them by default).
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

/// The values that change on every tick.
@MainActor
final class TimerClock: ObservableObject {
    @Published var remaining: TimeInterval = 0
    @Published var overtime: TimeInterval = 0
}
