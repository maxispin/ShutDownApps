import Foundation
import ServiceManagement

/// "Käynnistä kirjautuessa" -asetus. Muistaa mistä sijainnista kohde rekisteröitiin,
/// jotta se voidaan päivittää, jos sovellus siirretään (esim. build/ → /Applications).
enum LoginItem {
    private static let pathKey = "loginItemRegisteredPath"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(Bundle.main.bundlePath, forKey: pathKey)
            } else {
                try SMAppService.mainApp.unregister()
                UserDefaults.standard.removeObject(forKey: pathKey)
            }
        } catch {
            NSLog("Käynnistä kirjautuessa -asetus epäonnistui: \(error)")
        }
    }

    /// Jos kohde on päällä mutta rekisteröity toisesta sijainnista, rekisteröidään se uudelleen tähän.
    static func refreshLocation() {
        guard isEnabled,
              UserDefaults.standard.string(forKey: pathKey) != Bundle.main.bundlePath else { return }
        try? SMAppService.mainApp.unregister()
        set(true)
    }
}
