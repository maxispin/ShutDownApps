# ShutDownApps

macOS-sovellus, joka piilottaa ja sulkee sovelluksia, joita ei ole käytetty tiettyyn aikaan. Esimerkiksi WhatsApp piilotetaan 2 minuutin ja suljetaan 5 minuutin käyttämättömyyden jälkeen.

- **Käytetty** tarkoittaa, että sovellus on ollut etualalla.
- **Piilotus** toimii kuten Cmd-H: kaikki ikkunat katoavat ruudulta.
- **Sulkeminen** toimii kuten Cmd-Q.
- Kumpikaan ei tuo sovellusta etualalle, eikä Esteettömyys-oikeuksia tarvita.

Asetukset ovat sovelluskohtaisia: valvonta päälle tai pois sekä piilotus- ja sulkemisaika minuutteina. Ne tallentuvat tiedostoon `~/Library/Application Support/ShutDownApps/rules.json`.

## Asennus

Vaatii macOS 14:n tai uudemman ja Xcoden komentorivityökalut.

```sh
./build.sh           # kääntää build/ShutDownApps.app
./build.sh install   # kopioi /Applications-kansioon ja käynnistää
```

Asetukset aukeavat Dock-kuvakkeesta, valikkopalkin tiimalasista tai näppäinyhdistelmällä Cmd-,.
