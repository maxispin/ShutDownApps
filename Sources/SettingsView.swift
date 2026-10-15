import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: RuleStore
    @ObservedObject var monitor: Monitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Valvottavat sovellukset")
                .font(.title2.bold())
            Text("Sovellus piilotetaan tai suljetaan, kun sitä ei ole käytetty (se ei ole ollut etualalla) annettuun aikaan. Sovellusta ei tuoda etualalle.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.rules.isEmpty {
                Text("Ei sovelluksia. Lisää sovellus alta.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($store.rules) { $rule in
                        RuleRow(rule: $rule,
                                status: monitor.status(for: rule),
                                onDelete: { store.remove(rule) })
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            HStack {
                Menu("Lisää käynnissä oleva…") {
                    ForEach(addableRunningApps(), id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier!) {
                            store.add(bundleId: app.bundleIdentifier!,
                                      name: app.localizedName ?? app.bundleIdentifier!)
                        }
                    }
                }
                .fixedSize()
                Button("Valitse sovellus…", action: chooseApp)
                Spacer()
                Toggle("Keskeytä valvonta", isOn: $store.paused)
                Toggle("Käynnistä kirjautuessa", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 380)
    }

    private func addableRunningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular
                    && $0.bundleIdentifier != nil
                    && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                    && !store.contains(bundleId: $0.bundleIdentifier!)
            }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            store.add(bundleId: id, name: name)
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Käynnistä kirjautuessa -asetus epäonnistui: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

struct RuleRow: View {
    @Binding var rule: AppRule
    let status: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Toggle("", isOn: $rule.enabled)
                .labelsHidden()
                .help("Valvonta päällä tälle sovellukselle")

            Image(nsImage: icon)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name).font(.headline)
                Text(status)
                    .lineLimit(2)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 170, alignment: .leading)

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 4) {
                MinutesField(label: "Piilota", enabled: $rule.hideEnabled, minutes: $rule.hideMinutes)
                MinutesField(label: "Sulje", enabled: $rule.quitEnabled, minutes: $rule.quitMinutes)
                if rule.hideEnabled && rule.quitEnabled && rule.quitMinutes <= rule.hideMinutes {
                    Text("Sulkeminen tapahtuu ennen piilotusta")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .fixedSize()
            .disabled(!rule.enabled)
            .opacity(rule.enabled ? 1 : 0.5)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Poista")
        }
        .padding(.vertical, 6)
    }

    private var icon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}

struct MinutesField: View {
    let label: String
    @Binding var enabled: Bool
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 6) {
            Toggle(label, isOn: $enabled)
                .frame(width: 80, alignment: .leading)
            Text("kun käyttämättä").foregroundStyle(.secondary).fixedSize()
            TextField("", value: $minutes, format: .number)
                .frame(width: 44)
                .multilineTextAlignment(.trailing)
                .onChange(of: minutes) { _, v in minutes = min(max(v, 1), 1440) }
            Stepper("", value: $minutes, in: 1...1440)
                .labelsHidden()
            Text("min")
        }
        .disabled(!enabled)
        .controlSize(.small)
    }
}
