import AppKit

/// Seuraa milloin kutakin sovellusta on viimeksi käytetty (= ollut etualalla)
/// ja piilottaa tai sulkee sen sääntöjen mukaan tuomatta sitä etualalle.
@MainActor
final class Monitor: NSObject, ObservableObject {
    /// Päivittyy joka sekunti, jotta asetusikkunan tilatekstit päivittyvät.
    @Published private(set) var now = Date()

    private let store: RuleStore
    private var lastUsed: [String: Date] = [:]
    private var timer: Timer?

    init(store: RuleStore) {
        self.store = store
        super.init()

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appDeactivated(_:)),
                       name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appActivated(_:)),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appLaunched(_:)),
                       name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appTerminated(_:)),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Tapahtumat

    private func bundleId(_ note: Notification) -> String? {
        (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
    }

    @objc private func appDeactivated(_ note: Notification) {
        if let id = bundleId(note) { lastUsed[id] = Date() }
    }

    @objc private func appActivated(_ note: Notification) {
        if let id = bundleId(note) { lastUsed[id] = Date() }
    }

    @objc private func appLaunched(_ note: Notification) {
        if let id = bundleId(note) { lastUsed[id] = Date() }
    }

    @objc private func appTerminated(_ note: Notification) {
        if let id = bundleId(note) { lastUsed[id] = nil }
    }

    // MARK: - Valvonta

    private func runningApps(_ bundleId: String) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { !$0.isTerminated }
    }

    /// Kuinka kauan sovellus on ollut käyttämättä. Jos ajankohtaa ei tiedetä
    /// (sovellus oli jo käynnissä kun tämä ohjelma käynnistyi), aloitetaan laskenta nyt.
    private func idleTime(_ bundleId: String, apps: [NSRunningApplication]) -> TimeInterval {
        if apps.contains(where: \.isActive) {
            lastUsed[bundleId] = now
            return 0
        }
        if lastUsed[bundleId] == nil { lastUsed[bundleId] = now }
        return now.timeIntervalSince(lastUsed[bundleId]!)
    }

    private func tick() {
        now = Date()
        guard !store.paused else { return }

        for rule in store.rules where rule.enabled {
            let apps = runningApps(rule.bundleId)
            guard !apps.isEmpty else { continue }
            let idle = idleTime(rule.bundleId, apps: apps)
            guard idle > 0 else { continue }

            if rule.quitEnabled && idle >= TimeInterval(rule.quitMinutes * 60) {
                // terminate() lähettää tavallisen lopetuspyynnön (kuten Cmd-Q)
                // eikä aktivoi sovellusta.
                apps.forEach { $0.terminate() }
            } else if rule.hideEnabled && idle >= TimeInterval(rule.hideMinutes * 60) {
                // hide() piilottaa kaikki sovelluksen ikkunat (kuten Cmd-H)
                // eikä aktivoi sovellusta.
                apps.filter { !$0.isHidden }.forEach { $0.hide() }
            }
        }
    }

    /// Lyhyt tilateksti asetusikkunaan ja valikkoon.
    func status(for rule: AppRule) -> String {
        let apps = runningApps(rule.bundleId)
        if apps.isEmpty { return "Ei käynnissä" }
        if apps.contains(where: \.isActive) { return "Käytössä nyt" }
        let idle = idleTime(rule.bundleId, apps: apps)

        var parts = ["käyttämättä \(Self.format(idle))"]
        if rule.enabled && !store.paused {
            if rule.hideEnabled {
                let left = TimeInterval(rule.hideMinutes * 60) - idle
                parts.append(left > 0 ? "piilotus \(Self.format(left))" : "piilotettu")
            }
            if rule.quitEnabled {
                let left = TimeInterval(rule.quitMinutes * 60) - idle
                parts.append("sulkeminen \(Self.format(max(left, 0)))")
            }
        }
        return parts.joined(separator: " · ").capitalizedFirst
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.down))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
