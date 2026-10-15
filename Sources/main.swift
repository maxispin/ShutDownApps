import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = RuleStore()
    private lazy var monitor = Monitor(store: store)
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = monitor

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "ShutDownApps")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        NSApp.mainMenu = makeMainMenu()
        LoginItem.refreshLocation()
        if store.isFirstLaunch { openSettings() }
    }

    /// Avataan asetukset, kun Dock-kuvaketta klikataan tai sovellus avataan uudelleen.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if store.rules.isEmpty {
            menu.addItem(withTitle: "Ei valvottavia sovelluksia", action: nil, keyEquivalent: "")
        }
        for rule in store.rules {
            let item = NSMenuItem(title: "\(rule.name) — \(rule.enabled ? monitor.status(for: rule) : "Ei valvota")",
                                  action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Keskeytä valvonta", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = store.paused ? .on : .off
        menu.addItem(pause)

        let settings = NSMenuItem(title: "Asetukset…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Lopeta ShutDownApps", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    /// Pikavalinnat Dock-kuvakkeen valikkoon (oikea klikkaus).
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let pause = NSMenuItem(title: "Keskeytä valvonta", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = store.paused ? .on : .off
        menu.addItem(pause)
        let settings = NSMenuItem(title: "Asetukset…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        return menu
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        let settings = NSMenuItem(title: "Asetukset…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Kätke ShutDownApps", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Lopeta ShutDownApps", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "ShutDownApps", action: nil, keyEquivalent: "").submenu = appMenu

        let editMenu = NSMenu(title: "Muokkaa")
        editMenu.addItem(withTitle: "Leikkaa", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Kopioi", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Sijoita", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Valitse kaikki", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Muokkaa", action: nil, keyEquivalent: "").submenu = editMenu

        let windowMenu = NSMenu(title: "Ikkuna")
        windowMenu.addItem(withTitle: "Sulje", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Pienennä", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(withTitle: "Ikkuna", action: nil, keyEquivalent: "").submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        return main
    }

    @objc private func togglePause() {
        store.paused.toggle()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 440),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "ShutDownApps – Asetukset"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store, monitor: monitor))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

// `ShutDownApps --enable-login-item` kytkee "Käynnistä kirjautuessa" -asetuksen päälle
// tälle sijainnille ja lopettaa (käytetään esim. asennuksen jälkeen).
if CommandLine.arguments.contains("--enable-login-item") {
    LoginItem.set(true)
    print(LoginItem.isEnabled ? "Käynnistä kirjautuessa: päällä (\(Bundle.main.bundlePath))"
                              : "Käynnistä kirjautuessa: ei onnistunut")
    exit(LoginItem.isEnabled ? 0 : 1)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
