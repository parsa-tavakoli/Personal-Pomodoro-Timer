import Foundation

/// Checks GitHub Releases for a newer version: at launch and then once a day.
/// Only fetches the public "latest release" info; nothing about the user is sent.
@MainActor
final class UpdateChecker: ObservableObject {
    struct Update: Equatable {
        let version: String
        let url: URL
    }

    /// Set when the latest release is newer than this app.
    @Published private(set) var available: Update?

    private static let latestRelease = URL(string:
        "https://api.github.com/repos/parsa-tavakoli/Personal-Pomodoro-Timer/releases/latest")!
    private var timer: Timer?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    init() {
        Task { await check() }
        let t = Timer(timeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check() async {
        var request = URLRequest(url: Self.latestRelease)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              let url = URL(string: release.html_url) else { return }

        let latest = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        available = Self.isNewer(latest, than: currentVersion) ? Update(version: latest, url: url) : nil
    }

    /// Compares dotted versions number by number ("1.0.10" > "1.0.9"; "1.1" > "1.0.3").
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }
}
