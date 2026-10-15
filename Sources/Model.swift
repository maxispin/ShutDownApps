import AppKit

/// Asetukset yhdelle valvottavalle sovellukselle.
struct AppRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var bundleId: String
    var name: String
    var enabled = true
    var hideEnabled = true
    var hideMinutes = 2
    var quitEnabled = true
    var quitMinutes = 5
}

/// Pitää sääntölistan ja tallentaa sen JSON-tiedostoon:
/// ~/Library/Application Support/ShutDownApps/rules.json
@MainActor
final class RuleStore: ObservableObject {
    @Published var rules: [AppRule] = [] {
        didSet { if rules != oldValue { save() } }
    }
    @Published var paused = false

    private(set) var isFirstLaunch = false
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShutDownApps", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("rules.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([AppRule].self, from: data) {
            rules = decoded
        } else {
            isFirstLaunch = true
            rules = [AppRule(bundleId: "net.whatsapp.WhatsApp", name: "WhatsApp")]
            save()
        }
    }

    func contains(bundleId: String) -> Bool {
        rules.contains { $0.bundleId == bundleId }
    }

    func add(bundleId: String, name: String) {
        guard !contains(bundleId: bundleId) else { return }
        rules.append(AppRule(bundleId: bundleId, name: name))
    }

    func remove(_ rule: AppRule) {
        rules.removeAll { $0.id == rule.id }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(rules) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
