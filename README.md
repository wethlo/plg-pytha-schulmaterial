# PLG PYTHA-Schulmaterial

> **English summary:** Windows installer (Inno Setup) for the PYTHA school library maintained by the "Professionelle Lerngruppe PYTHA", a working group of teachers at four vocational schools in Baden-Württemberg, Germany (since 2023). It downloads the shared teaching material (templates, logos, transfer file for the PYTHA 3D CAD software) from a public read-only cloud share to `C:\Users\Public\PYTHA\Schulmaterial`, keeps it up to date via a scheduled task and, with admin rights, can install PYTHA and set the school defaults. Free for schools and students, MIT licensed. The UI is German only.

Installer für die PYTHA-Schulbibliothek der **Professionellen Lerngruppe PYTHA**.
Er lädt das Schulmaterial aus einer Cloud auf den PC und hält es danach aktuell.

## Über das Projekt

Das PYTHA-Schulmaterial ist eine Schulbibliothek für PYTHA mit zugehöriger Transferdatei. Entwickelt wurde es von

- Clemens Kastner (Gewerbliche Schule Schwäbisch Hall)
- Theo Weber (Gewerbliche Schule Ravensburg)
- Ralf Sigmund (Berufsschulzentrum Radolfzell)
- Ralf Huber (Gewerblich-Technische Schule Offenburg)

im Rahmen der Professionellen Lerngruppe. Seit 2023 pflegen wir es gemeinsam und erweitern es fortlaufend.

PYTHA ist ein Produkt der PYTHA Lab GmbH. Dieses Projekt ist kein Angebot der PYTHA Lab GmbH. Für den Betrieb von PYTHA ist eine gültige PYTHA-Lizenz erforderlich.

## Was der Installer macht

| | Ohne Adminrechte | Mit Adminrechten |
|---|:---:|:---:|
| Schulmaterial nach `C:\Users\Public\PYTHA\Schulmaterial` laden | ✔ | ✔ |
| Desktop-Verknüpfung „PYTHA-Schulmaterial aktualisieren“ | ✔ | ✔ |
| PYTHA 26 installieren, falls noch nicht vorhanden | – | ✔ |
| Schuleinstellungen eintragen (Transferdatei-Pfad, Lesemodus 0/1/2) | – | ✔ |
| Tägliche Aktualisierung (Uhrzeit wählbar, auch bei Anmeldung) für alle Benutzer | – | ✔ |

- **Start per Doppelklick:** Windows fragt nach Adminrechten. Mit **Ja** gibt es die volle Installation. Mit **Nein** läuft der Installer ohne Adminrechte weiter, die Admin-Punkte sind dann ausgegraut.
- **Schulauswahl:** Ravensburg, Offenburg, Radolfzell, Schwäbisch Hall, Emmendingen oder **Andere Schule**.
- **Andere Schule:** Ein eigenes Logo ist Pflicht (JPG, PNG, BMP, GIF oder TIFF). Es wird im Assistenten auf 472 × 115 Pixel zugeschnitten (zoomen und verschieben) und als `13_Material\Logos\Logo.jpg` gespeichert. Aktualisierungen überschreiben diese Datei nie.
- **Aktualisieren:** Es werden nur neue und geänderte Dateien geladen. Eigene Dateien im Ordner werden nie gelöscht.
- **Erneut starten:** Ist das Programm schon installiert, bietet der Installer Folgendes an: Aktualisieren/Reparieren, Schule oder Einstellungen ändern, Logo ändern, Deinstallieren.
- **Deinstallation** über „Apps“ in den Windows-Einstellungen. Das Schulmaterial bleibt auf Wunsch erhalten.

## Datenschutz

Das Programm erhebt keine personenbezogenen Daten und überträgt keine. Es baut nur diese Verbindungen auf:

- zur öffentlichen, nur lesbaren Cloud-Freigabe der Lerngruppe, um das Schulmaterial zu laden,
- zu `download.pytha.de`, um die PYTHA-Installationsdatei zu laden (nur mit Adminrechten und wenn PYTHA fehlt).

Ein Protokoll der letzten Läufe bleibt lokal auf dem PC (`%LOCALAPPDATA%\PYTHA-Update\update-protokoll.txt`).

## Projektaufbau

```
installer/PLG-Schulmaterial.iss   Inno-Setup-Skript (Assistent, Seiten, Ablauf)
src/Schulmaterial-Update.ps1      Laden/Aktualisieren, Registry, Aufgabenplanung
src/Logo-Zuschnitt.ps1            Dialog zum Zuschneiden des Schullogos
src/Aktualisieren.cmd             Starter für die Desktop-Verknüpfung
src/Aktualisieren-still.vbs       unsichtbarer Starter für die Aufgabenplanung
texte/ueber-das-projekt.txt       Seite „Über das Projekt“ im Installer
assets/                           PLG-Logo, Symbol, Bilder des Assistenten
.github/workflows/build.yml       Build und Signatur auf GitHub
.signpath/                        Vorlage der SignPath-Artefakt-Konfiguration
```

## Bauen

**Automatisch:** Jeder Push baut den Installer über GitHub Actions. Ein Tag wie `v3.0.0` erzeugt zusätzlich ein Release.

**Von Hand (Windows):**

1. [Inno Setup 6](https://jrsoftware.org/isinfo.php) installieren.
2. `"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DAppVersion=3.0.0 installer\PLG-Schulmaterial.iss`
3. Der Installer liegt danach in `ausgabe\PLG-PYTHA-Schulmaterial-Setup.exe`.

Die Skripte in `src/` müssen ASCII bzw. UTF-8 mit BOM sein und CRLF-Zeilenenden haben. Dafür sorgt `.gitattributes`. Sie müssen außerdem mit Windows PowerShell 5.1 laufen.

## Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).

Kostenlose Code-Signatur durch SignPath.io, Zertifikat der SignPath Foundation.

- Signiert werden nur Installer, die GitHub Actions aus diesem Repository baut. Lokal gebaute Dateien werden nicht signiert.
- Jede Signatur für ein Release wird vorher von Hand freigegeben.

**Rollen**

| Rolle | Personen |
|---|---|
| Committer und Reviewer (Committers and reviewers) | [Theo Weber (wethlo)](https://github.com/wethlo) |
| Freigabe (Approvers) | [Theo Weber (wethlo)](https://github.com/wethlo) |

**Privacy policy:** This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it. It only downloads the school material from the project's public read-only cloud share and, if requested during installation, the official PYTHA installer from download.pytha.de. See [Datenschutz](#datenschutz).

## Lizenz

Der Quellcode steht unter der [MIT-Lizenz](LICENSE).
**Ausgenommen** sind das PLG-Logo und die daraus abgeleiteten Bilder in `assets/`. Sie dürfen nur für dieses Projekt verwendet werden.
