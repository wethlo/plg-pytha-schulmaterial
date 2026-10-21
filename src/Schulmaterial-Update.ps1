param(
    [switch]$Leise,             # stiller Lauf aus der Aufgabenplanung
    [switch]$Einrichten,        # vom Installer: laden + Zusatzschritte laut Einstellungen
    [switch]$Manuell,           # von Hand ueber die Desktop-Verknuepfung
    [switch]$Entfernen,         # vom Deinstaller: Aufgabe entfernen
    [switch]$EntferneRegistry,  # zusammen mit -Entfernen: Schuleinstellungen austragen
    [string]$ErgebnisDatei = '' # vom Installer: hier landet eine kurze Zusammenfassung
)

# ==============================================================
#   PLG PYTHA-Schulmaterial - Aktualisierung
#   Teil des Installers. Die Einstellungen (Schule, Automatik, ...)
#   stehen in einstellungen.ini im selben Ordner und werden vom
#   Installer geschrieben. Diese Datei bitte nicht von Hand aendern.
#
#   Lizenz: MIT (siehe LICENSE im Projekt)
# ==============================================================

# --- Schulen und ihre Freigaben -----------------------------------
# Die Adressen sind absichtlich unlesbar abgelegt (XOR+Base64), damit
# im Editor kein anklickbarer Link ins Auge faellt. Das ist Sichtschutz,
# keine Verschluesselung: Die Freigaben sind oeffentlich und nur lesbar.
$Fassungen = @(
    @{ Kuerzel = 'RV';  Bezeichnung = 'Ravensburg';       LinkDaten = 'ODgzXSNje2ciQS0iSVRZXlMjYiBefTYyLiRDICJfVR5WU38/aEI7KT9wG1wTM24GSgYCOw==' },
    @{ Kuerzel = 'RZ';  Bezeichnung = 'Radolfzell';       LinkDaten = 'ODgzXSNje2ciQS0iSVRZXlMjYiBefTYyLiRDICJfVR5WU38/aBUVMw18MX0QLU5lZHh+Ng==' },
    @{ Kuerzel = 'OF';  Bezeichnung = 'Offenburg';        LinkDaten = 'ODgzXSNje2ciQS0iSVRZXlMjYiBefTYyLiRDICJfVR5WU38/aEQWHyQtMn10PXp8fUN4Iw==' },
    @{ Kuerzel = 'SHA'; Bezeichnung = 'Schwaebisch Hall'; LinkDaten = 'ODgzXSNje2ciQS0iSVRZXlMjYiBefTYyLiRDICJfVR5WU38/aGgKCAd6cxkOOERjaQpEZQ==' },
    @{ Kuerzel = 'EM';  Bezeichnung = 'Emmendingen';      LinkDaten = 'ODgzXSNje2ciQS0iSVRZXlMjYiBefTYyLiRDICJfVR5WU38/aBQ+Oi4uGx52H252QAUDFw==' }
)
# "Andere Schule": gemeinsamer Stand (Mutterordner)
$StandardBezeichnung = 'Andere Schule'
$StandardLinkDaten = 'ODgzXSNje2ciQS0iSVRZXlMjYiBefTYyLiRDICJfVR5WU38/aGpjFwMSD3R3NmlLY3ZvYw=='

$SharePassword = ''
$ZielOrdner = Join-Path $env:PUBLIC 'PYTHA\Schulmaterial'
$Unterordner = ''
$Ausgabe = 'kurz'

$SetupHolen = $true
$SetupUrl = 'https://download.pytha.de/setup/setup_pytha_26.exe'
$SetupOrdner = '00_Installationsexe'

$RegistrierungsPfad = 'HKLM:\SOFTWARE\PYTHA Lab GmbH\ZENTRALE26.0'
$TransferOrdner = '99_Transferdatei'

$AufgabenName = 'PLG PYTHA-Schulmaterial aktualisieren'
$AlterAufgabenName = 'PYTHA Schulmaterial aktualisieren'   # aus der .cmd-Zeit
$HoechstensEinmalTaeglich = $false
$Rahmenstil = 'modern'

$EinstellDatei = Join-Path $PSScriptRoot 'einstellungen.ini'

# ==============================================================
#            A B   H I E R   N I C H T S   A E N D E R N
# ==============================================================

$ScriptVersion = '3.0'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:Origin = ''
$script:LogPfad = $null
$script:Leise = [bool]$Leise
$script:InstallErzwingen = $false
$script:Neu = 0
$script:Aktualisiert = 0
$script:Aktuell = 0
$script:Fehler = 0
$script:SummeBytes = 0
$script:Geschuetzt = 0
$script:InstallErgebnis = [ordered]@{}


# --------------------------------------------------------------
# Protokoll und Ausgabe
# --------------------------------------------------------------
function Start-Protokoll {
    try {
        $basis = $env:LOCALAPPDATA
        if (-not $basis) { $basis = $env:TEMP }
        $dir = Join-Path $basis 'PYTHA-Update'
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $script:LogPfad = Join-Path $dir 'update-protokoll.txt'
        if (Test-Path -LiteralPath $script:LogPfad) {
            if ((Get-Item -LiteralPath $script:LogPfad).Length -gt 1MB) {
                Remove-Item -LiteralPath $script:LogPfad -Force
            }
        }
    } catch { $script:LogPfad = $null }
}

function Schreib {
    param([string]$Text, [string]$Farbe = 'Gray', [switch]$NurProtokoll)
    if (-not $NurProtokoll) {
        Loesche-Balken
        Write-Host $Text -ForegroundColor $Farbe
    }
    if ($script:LogPfad) {
        try {
            Add-Content -LiteralPath $script:LogPfad -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text) -Encoding UTF8
        } catch { }
    }
}

function Schreib-Detail {
    param([string]$Text, [string]$Farbe = 'DarkGray')
    if ($Ausgabe -eq 'ausfuehrlich') { Schreib $Text $Farbe } else { Schreib $Text $Farbe -NurProtokoll }
}

# --------------------------------------------------------------
# Darstellung: helles Thema, Rahmen- und Blockzeichen
# --------------------------------------------------------------
$script:Farbe = @{}
$script:Z = @{}

function Konsolen-Breite {
    $b = 0
    try { $b = [int][Console]::WindowWidth } catch { $b = 0 }
    if ($b -lt 40) { $b = 80 }
    if ($b -gt 104) { $b = 104 }
    return $b
}

function Setze-Darstellung {
    $hell = $false
    # Im stillen Lauf nichts am Fenster verstellen - es sieht ohnehin niemand.
    if ($script:Leise) { $env:WT_SESSION = '1' }
    # Windows Terminal zeichnet den Fensterhintergrund nach seinem eigenen
    # Farbschema. Dort erst gar nicht auf hell umschalten, sonst stuende
    # womoeglich schwarze Schrift auf dunklem Grund.
    if (-not $env:WT_SESSION) {
        try {
            [Console]::BackgroundColor = [ConsoleColor]::White
            [Console]::ForegroundColor = [ConsoleColor]::Black
            Clear-Host
            $hell = $true
        } catch { }
    }

    if ($hell) {
        $script:Farbe = @{
            Titel = 'DarkCyan'; Label = 'DarkGray'; Text = 'Black'; Leise = 'DarkGray';
            Neu = 'DarkGreen'; Alt = 'DarkCyan'; Warn = 'DarkYellow'; Fehler = 'DarkRed';
            Gut = 'DarkGreen'; Voll = 'DarkCyan'; Rest = 'Gray'
        }
    } else {
        $script:Farbe = @{
            Titel = 'Cyan'; Label = 'DarkGray'; Text = 'Gray'; Leise = 'DarkGray';
            Neu = 'Green'; Alt = 'Cyan'; Warn = 'Yellow'; Fehler = 'Red';
            Gut = 'Green'; Voll = 'Cyan'; Rest = 'DarkGray'
        }
    }

    $modern = ($Rahmenstil -ne 'einfach')
    if ($modern) {
        try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { $modern = $false }
    }
    if ($modern) {
        $script:Z = @{
            Waag = [string][char]0x2500; Senk = [string][char]0x2502
            OL = [string][char]0x250C; OR = [string][char]0x2510
            UL = [string][char]0x2514; UR = [string][char]0x2518
            Voll = [string][char]0x2588; Leer = [string][char]0x2591
            Punkt = [string][char]0x00B7; Neu = '+'; Alt = [string][char]0x00BB
        }
    } else {
        $script:Z = @{
            Waag = '-'; Senk = '|'; OL = '+'; OR = '+'; UL = '+'; UR = '+'
            Voll = '#'; Leer = '.'; Punkt = '-'; Neu = '+'; Alt = '>'
        }
    }
}

function Zeige-Kopf {
    param([string]$Titel, [string]$Rechts)
    $innen = (Konsolen-Breite) - 6
    $links = ' ' + $Titel
    $rechtsText = ''
    if ($Rechts) { $rechtsText = $Rechts + ' ' }
    $fuell = $innen - $links.Length - $rechtsText.Length
    if ($fuell -lt 1) { $fuell = 1 }
    $mitte = $links + (' ' * $fuell) + $rechtsText
    if ($mitte.Length -gt $innen) { $mitte = $mitte.Substring(0, $innen) }
    Write-Host ''
    Write-Host ('  ' + $script:Z.OL + ($script:Z.Waag * $innen) + $script:Z.OR) -ForegroundColor $script:Farbe.Titel
    Write-Host ('  ' + $script:Z.Senk + $mitte.PadRight($innen) + $script:Z.Senk) -ForegroundColor $script:Farbe.Titel
    Write-Host ('  ' + $script:Z.UL + ($script:Z.Waag * $innen) + $script:Z.UR) -ForegroundColor $script:Farbe.Titel
    Write-Host ''
}

function Zeige-Linie {
    Loesche-Balken
    Write-Host ('  ' + ($script:Z.Waag * ((Konsolen-Breite) - 5))) -ForegroundColor $script:Farbe.Leise
}

function Zeige-Feld {
    param([string]$Name, [string]$Wert, [string]$Farbe = '')
    Loesche-Balken
    if (-not $Farbe) { $Farbe = $script:Farbe.Text }
    Write-Host ('   ' + $Name.PadRight(18)) -NoNewline -ForegroundColor $script:Farbe.Label
    Write-Host $Wert -ForegroundColor $Farbe
    Schreib ("{0}: {1}" -f $Name.Trim(), $Wert) 'Gray' -NurProtokoll
}

function Zeige-Eintrag {
    param([string]$Symbol, [string]$Farbe, [string]$Text, [string]$LogWort)
    Loesche-Balken
    Write-Host ('    ' + $Symbol + '  ') -NoNewline -ForegroundColor $Farbe
    Write-Host $Text -ForegroundColor $script:Farbe.Text
    Schreib ("{0}  {1}" -f $LogWort.PadRight(9), $Text) 'Gray' -NurProtokoll
}

function Zeige-Meldung {
    param([string]$Text, [string]$Farbe = '')
    Loesche-Balken
    if (-not $Farbe) { $Farbe = $script:Farbe.Text }
    Write-Host ('   ' + $Text) -ForegroundColor $Farbe
    Schreib $Text 'Gray' -NurProtokoll
}

# --------------------------------------------------------------
# Hinterlegte Adressen wieder lesbar machen
# --------------------------------------------------------------
function Entschluessle {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    try {
        $b = [Convert]::FromBase64String($Text.Trim())
        $k = [Text.Encoding]::UTF8.GetBytes('PLG-PYTHA-BW-2026')
        for ($i = 0; $i -lt $b.Length; $i++) {
            $b[$i] = [byte](($b[$i] -bxor $k[$i % $k.Length]) -band 0xFF)
        }
        return [Text.Encoding]::UTF8.GetString($b)
    } catch { return '' }
}

# Kennzeichen der Freigabe in Meldungen unkenntlich machen
function Maskiere {
    param([string]$Text)
    if (-not $Text) { return '' }
    return ($Text -replace '(/s/)[^/?&\s]+', '$1***')
}

# --------------------------------------------------------------
# Freigabelink zerlegen
# --------------------------------------------------------------
function Split-ShareUrl {
    param([string]$Url)

    $u = $Url.Trim()
    $u = $u.Trim('"')
    $u = $u.Trim("'")
    if ($u -notmatch '^https?://') { throw "Der Freigabelink muss mit https:// beginnen." }

    $pfadTeil = $u.Split('#')[0]
    $query = ''
    if ($pfadTeil.Contains('?')) {
        $query = $pfadTeil.Substring($pfadTeil.IndexOf('?') + 1)
        $pfadTeil = $pfadTeil.Substring(0, $pfadTeil.IndexOf('?'))
    }

    $uri = [Uri]$pfadTeil
    $origin = "{0}://{1}" -f $uri.Scheme, $uri.Authority

    $segmente = @($uri.AbsolutePath.Split('/') | Where-Object { $_ -ne '' })
    $idx = -1
    for ($i = 0; $i -lt $segmente.Count; $i++) {
        if ($segmente[$i] -eq 's') { $idx = $i; break }
    }
    if ($idx -lt 0 -or ($idx + 1) -ge $segmente.Count) {
        throw "Aus dem Freigabelink laesst sich kein Freigabe-Kennzeichen lesen. Erwartet wird z. B. https://cloud.example.de/s/AbCdEf12345"
    }
    $token = $segmente[$idx + 1]

    $prefix = ''
    if ($idx -gt 0) { $prefix = '/' + (($segmente[0..($idx - 1)]) -join '/') }
    $basis = $origin + $prefix
    $basis = $basis -replace '/index\.php$', ''

    $pfadAusQuery = ''
    if ($query) {
        foreach ($paar in $query.Split('&')) {
            $pos = $paar.IndexOf('=')
            if ($pos -gt 0) {
                $feldName = $paar.Substring(0, $pos)
                $wert = $paar.Substring($pos + 1)
                # Nextcloud verwendet je nach Version 'dir' oder 'path'
                if ($feldName -eq 'path' -or $feldName -eq 'dir') {
                    $pfadAusQuery = [Uri]::UnescapeDataString($wert.Replace('+', ' '))
                }
            }
        }
    }

    return [pscustomobject]@{
        Origin       = $origin
        Basis        = $basis
        Token        = $token
        PfadAusQuery = $pfadAusQuery
    }
}

# --------------------------------------------------------------
# HTTP-Grundlagen
# --------------------------------------------------------------
function Initialisiere-HttpClient {
    try { Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue } catch { }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
    } catch { }

    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    try { $handler.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate } catch { }
    try {
        $proxy = [Net.WebRequest]::GetSystemWebProxy()
        $proxy.Credentials = [Net.CredentialCache]::DefaultCredentials
        $handler.Proxy = $proxy
        $handler.UseProxy = $true
    } catch { }

    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromMinutes(30)
    return $client
}

function Neue-Anfrage {
    param([string]$Methode, [string]$Url, [string]$Benutzer, [string]$Passwort, [switch]$OhneAnmeldung)
    $verb = New-Object System.Net.Http.HttpMethod($Methode)
    $req = New-Object System.Net.Http.HttpRequestMessage($verb, $Url)
    if (-not $OhneAnmeldung) {
        $roh = [Text.Encoding]::UTF8.GetBytes(("{0}:{1}" -f $Benutzer, $Passwort))
        $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Basic', [Convert]::ToBase64String($roh))
        $req.Headers.Add('X-Requested-With', 'XMLHttpRequest')
    }
    $req.Headers.Add('User-Agent', ("PYTHA-Schulmaterial-Update/" + $ScriptVersion))
    return $req
}

# --------------------------------------------------------------
# Ein Verzeichnis der Freigabe auflisten (WebDAV PROPFIND, Tiefe 1)
# --------------------------------------------------------------
function Lies-Verzeichnis {
    param($Client, [string]$Url, [string]$Benutzer, [string]$Passwort)

    $req = Neue-Anfrage -Methode 'PROPFIND' -Url $Url -Benutzer $Benutzer -Passwort $Passwort
    $req.Headers.Add('Depth', '1')
    $body = '<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>'
    $req.Content = New-Object System.Net.Http.StringContent($body, [Text.Encoding]::UTF8, 'application/xml')

    $antwort = $Client.SendAsync($req).GetAwaiter().GetResult()
    $text = $antwort.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $code = [int]$antwort.StatusCode
    $antwort.Dispose()
    $req.Dispose()

    $eintraege = New-Object System.Collections.ArrayList
    if ($code -ne 207) {
        return [pscustomobject]@{ Ok = $false; Code = $code; Eintraege = $eintraege }
    }

    $xml = New-Object System.Xml.XmlDocument
    $xml.LoadXml($text)

    $eigenerPfad = ([Uri]$Url).AbsolutePath.TrimEnd('/')

    foreach ($r in $xml.GetElementsByTagName('response', 'DAV:')) {
        $hrefKnoten = $r.GetElementsByTagName('href', 'DAV:')
        if ($hrefKnoten.Count -eq 0) { continue }
        $href = $hrefKnoten[0].InnerText
        $hrefPfad = $href
        $istAbsolut = ($href -match '^https?://')
        if ($istAbsolut) { $hrefPfad = ([Uri]$href).AbsolutePath }
        if ($hrefPfad.TrimEnd('/') -eq $eigenerPfad) { continue }

        $istOrdner = ($r.GetElementsByTagName('collection', 'DAV:').Count -gt 0)

        [long]$laenge = -1
        $lk = $r.GetElementsByTagName('getcontentlength', 'DAV:')
        if ($lk.Count -gt 0 -and $lk[0].InnerText) {
            $tmp = [long]0
            if ([long]::TryParse($lk[0].InnerText, [ref]$tmp)) { $laenge = $tmp }
        }

        $geaendert = [DateTime]::MinValue
        $mk = $r.GetElementsByTagName('getlastmodified', 'DAV:')
        if ($mk.Count -gt 0 -and $mk[0].InnerText) {
            try {
                $geaendert = ([DateTimeOffset]::Parse($mk[0].InnerText, [Globalization.CultureInfo]::InvariantCulture)).UtcDateTime
            } catch { }
        }

        $name = [Uri]::UnescapeDataString(($hrefPfad.TrimEnd('/').Split('/'))[-1])
        if (-not $name) { continue }

        if ($istAbsolut) { $vollUrl = $href } else { $vollUrl = $script:Origin + $href }

        [void]$eintraege.Add([pscustomobject]@{
            Name      = $name
            IstOrdner = $istOrdner
            Groesse   = $laenge
            Geaendert = $geaendert
            Url       = $vollUrl
        })
    }

    return [pscustomobject]@{ Ok = $true; Code = $code; Eintraege = $eintraege }
}

# --------------------------------------------------------------
# Rekursiv alle Dateien der Freigabe sammeln
# --------------------------------------------------------------
function Sammle-Dateien {
    param($Client, [string]$StartUrl, [string]$Benutzer, [string]$Passwort)

    $dateien = New-Object System.Collections.ArrayList
    $ordnerListe = New-Object System.Collections.ArrayList
    $ordnerZahl = 0
    $warteschlange = New-Object System.Collections.Queue
    $warteschlange.Enqueue((New-Object psobject -Property @{ Url = $StartUrl; Rel = '' }))
    $besucht = New-Object 'System.Collections.Generic.HashSet[string]'

    while ($warteschlange.Count -gt 0) {
        $akt = $warteschlange.Dequeue()
        if (-not $besucht.Add($akt.Url)) { continue }

        $erg = Lies-Verzeichnis -Client $Client -Url $akt.Url -Benutzer $Benutzer -Passwort $Passwort
        if (-not $erg.Ok) {
            if ($akt.Rel -eq '') {
                return [pscustomobject]@{ Ok = $false; Code = $erg.Code; Dateien = $dateien; Ordner = $ordnerListe }
            }
            Zeige-Meldung ("Ordner nicht lesbar (Code {0}): {1}" -f $erg.Code, $akt.Rel) $script:Farbe.Warn
            continue
        }

        foreach ($e in $erg.Eintraege) {
            if ($akt.Rel) { $rel = $akt.Rel + '/' + $e.Name } else { $rel = $e.Name }
            if ($e.IstOrdner) {
                [void]$ordnerListe.Add($rel)
                $u = $e.Url
                if (-not $u.EndsWith('/')) { $u = $u + '/' }
                $warteschlange.Enqueue((New-Object psobject -Property @{ Url = $u; Rel = $rel }))
            } else {
                [void]$dateien.Add([pscustomobject]@{
                    Rel       = $rel
                    Url       = $e.Url
                    Groesse   = $e.Groesse
                    Geaendert = $e.Geaendert
                })
            }
        }
        $ordnerZahl++
        Zeige-Status ("Lese die Dateiliste ...   {0} Ordner, {1} Datei(en) gefunden" -f $ordnerZahl, $dateien.Count)
        Schreib-Detail ("  gelesen: /" + $akt.Rel)
    }
    Loesche-Balken

    return [pscustomobject]@{ Ok = $true; Code = 207; Dateien = $dateien; Ordner = $ordnerListe }
}

# --------------------------------------------------------------
# Vergleich und Download
# --------------------------------------------------------------
# Ordner der Freigabe nachbilden - auch die, in denen (noch) nichts liegt
function Lege-Ordner-An {
    param([string]$Basis, $Ordnerliste)
    $neue = 0
    foreach ($rel in $Ordnerliste) {
        if (-not $rel) { continue }
        $pfad = $Basis
        foreach ($teil in $rel.Split('/')) { if ($teil) { $pfad = Join-Path $pfad $teil } }
        if (-not (Test-Path -LiteralPath $pfad)) {
            try {
                New-Item -ItemType Directory -Path $pfad -Force | Out-Null
                $neue++
                Schreib ("ORDNER     " + $rel) 'Gray' -NurProtokoll
            } catch {
                Schreib ("Ordner konnte nicht angelegt werden: " + $rel) 'DarkYellow' -NurProtokoll
            }
        }
    }
    return $neue
}

function Braucht-Download {
    param([string]$Pfad, [long]$Groesse, [DateTime]$Geaendert)
    if (-not (Test-Path -LiteralPath $Pfad)) { return 'neu' }
    $fi = Get-Item -LiteralPath $Pfad
    if ($Groesse -ge 0 -and $fi.Length -ne $Groesse) { return 'geaendert' }
    if ($Geaendert -ne [DateTime]::MinValue) {
        if ($Geaendert -gt $fi.LastWriteTimeUtc.AddSeconds(2)) { return 'geaendert' }
    }
    return 'aktuell'
}

function Entsperre-Datei {
    param([string]$Pfad)
    if (Test-Path -LiteralPath $Pfad) {
        try {
            $f = Get-Item -LiteralPath $Pfad -Force
            if ($f.IsReadOnly) { $f.IsReadOnly = $false }
        } catch { }
    }
}

function Hole-Datei {
    param($Client, [string]$Url, [string]$Ziel, [string]$Benutzer, [string]$Passwort, [DateTime]$Geaendert,
          [switch]$MitFortschritt, [switch]$OhneAnmeldung)

    $ordner = Split-Path -Parent $Ziel
    if ($ordner -and -not (Test-Path -LiteralPath $ordner)) {
        New-Item -ItemType Directory -Path $ordner -Force | Out-Null
    }

    $temp = $Ziel + '.pytha-temp'
    $req = Neue-Anfrage -Methode 'GET' -Url $Url -Benutzer $Benutzer -Passwort $Passwort -OhneAnmeldung:$OhneAnmeldung
    $antwort = $Client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    try {
        if (-not $antwort.IsSuccessStatusCode) { throw ("Serverantwort " + [int]$antwort.StatusCode) }
        $quelle = $antwort.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $zielStrom = [IO.File]::Open($temp, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $puffer = New-Object byte[] 65536
            while ($true) {
                $gelesen = $quelle.Read($puffer, 0, $puffer.Length)
                if ($gelesen -le 0) { break }
                $zielStrom.Write($puffer, 0, $gelesen)
                if ($MitFortschritt) {
                    $script:GeladeneBytes += $gelesen
                    Zeichne-Balken
                }
            }
        } finally { $zielStrom.Dispose(); $quelle.Dispose() }
    } finally {
        $antwort.Dispose()
        $req.Dispose()
    }

    $groesse = (Get-Item -LiteralPath $temp).Length
    Entsperre-Datei -Pfad $Ziel
    Move-Item -LiteralPath $temp -Destination $Ziel -Force
    if ($Geaendert -ne [DateTime]::MinValue) {
        try { (Get-Item -LiteralPath $Ziel).LastWriteTimeUtc = $Geaendert } catch { }
    }
    return $groesse
}

function Formatiere-Bytes {
    param([double]$b)
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N0} KB' -f ($b / 1KB)) }
    return ('{0:N0} Bytes' -f $b)
}

function Formatiere-Zeit {
    param([double]$s)
    if ($s -lt 0) { $s = 0 }
    $s = [int][Math]::Round($s)
    if ($s -ge 3600) { return ('{0}:{1:00}:{2:00} Std' -f [int]($s / 3600), [int](($s % 3600) / 60), ($s % 60)) }
    if ($s -ge 60)   { return ('{0}:{1:00} Min' -f [int]($s / 60), ($s % 60)) }
    return ('{0} Sek' -f $s)
}

# --------------------------------------------------------------
# Fortschrittsbalken (wird laufend in derselben Zeile aktualisiert)
# --------------------------------------------------------------
$script:BalkenAktiv = $false
$script:TaktUhr = [Diagnostics.Stopwatch]::StartNew()
$script:LetzterStatus = -1000
$script:Spinner = 0
$script:SpinnerZeichen = '-\|/'
$script:GeladeneBytes = 0
$script:GesamtBytes = 0
$script:DateiNummer = 0
$script:DateiAnzahl = 0
$script:Uhr = $null
$script:LetzteAusgabe = -1000

function Balken-Moeglich {
    if ($script:Leise) { return $false }
    try { if ([Console]::IsOutputRedirected) { return $false } } catch { return $false }
    return $true
}

function Zeichne-Balken {
    param([switch]$Erzwingen)
    if (-not (Balken-Moeglich)) { return }
    if ($null -eq $script:Uhr) { return }

    # hoechstens ca. fuenfmal pro Sekunde neu zeichnen
    $jetzt = $script:Uhr.ElapsedMilliseconds
    if (-not $Erzwingen -and ($jetzt - $script:LetzteAusgabe) -lt 200) { return }
    $script:LetzteAusgabe = $jetzt

    if ($script:GesamtBytes -gt 0) {
        $anteil = $script:GeladeneBytes / $script:GesamtBytes
    } elseif ($script:DateiAnzahl -gt 0) {
        $anteil = $script:DateiNummer / $script:DateiAnzahl
    } else {
        $anteil = 0
    }
    if ($anteil -gt 1) { $anteil = 1 }
    if ($anteil -lt 0) { $anteil = 0 }

    $breite = 26
    $voll = [int][Math]::Round($anteil * $breite)
    if ($voll -gt $breite) { $voll = $breite }
    if ($voll -lt 0) { $voll = 0 }

    $rest = ''
    $sek = $jetzt / 1000
    if ($sek -gt 2 -and $anteil -gt 0.02 -and $anteil -lt 1) {
        $rest = '   noch ca. ' + (Formatiere-Zeit (($sek / $anteil) - $sek))
    }

    $text = ("   {0,3} %   {1} von {2} {3} {4} / {5}{6}" -f `
        [int]($anteil * 100), $script:DateiNummer, $script:DateiAnzahl, $script:Z.Punkt, `
        (Formatiere-Bytes $script:GeladeneBytes), (Formatiere-Bytes $script:GesamtBytes), $rest)

    try {
        $platz = (Konsolen-Breite) - 1
        $frei = $platz - 4 - $breite
        if ($frei -lt 1) { $frei = 1 }
        if ($text.Length -gt $frei) { $text = $text.Substring(0, $frei) }

        Write-Host "`r    " -NoNewline
        Write-Host ($script:Z.Voll * $voll) -NoNewline -ForegroundColor $script:Farbe.Voll
        Write-Host ($script:Z.Leer * ($breite - $voll)) -NoNewline -ForegroundColor $script:Farbe.Rest
        Write-Host $text.PadRight($frei) -NoNewline -ForegroundColor $script:Farbe.Leise
        $script:BalkenAktiv = $true
        Setze-Titel ("PYTHA Schulmaterial - {0} %" -f [int]($anteil * 100))
    } catch { }
}

# Fensterbeschriftung mitlaufen lassen - in Windows Terminal
# sieht man den Fortschritt dann sogar im Reiter.
function Setze-Titel {
    param([string]$Text)
    try { $Host.UI.RawUI.WindowTitle = $Text } catch { }
}

# Lebenszeichen waehrend laengerer Arbeitsschritte
function Zeige-Status {
    param([string]$Text, [switch]$Erzwingen)
    if (-not (Balken-Moeglich)) { return }
    $jetzt = $script:TaktUhr.ElapsedMilliseconds
    if (-not $Erzwingen -and ($jetzt - $script:LetzterStatus) -lt 130) { return }
    $script:LetzterStatus = $jetzt
    $script:Spinner = ($script:Spinner + 1) % 4
    $zeichen = $script:SpinnerZeichen.Substring($script:Spinner, 1)
    try {
        $platz = (Konsolen-Breite) - 1
        $zeile = '   ' + $zeichen + '  ' + $Text
        if ($zeile.Length -gt $platz) { $zeile = $zeile.Substring(0, $platz) }
        Write-Host ("`r" + $zeile.PadRight($platz)) -NoNewline -ForegroundColor $script:Farbe.Leise
        $script:BalkenAktiv = $true
    } catch { }
}

function Loesche-Balken {
    if (-not $script:BalkenAktiv) { return }
    try {
        $platz = (Konsolen-Breite) - 1
        Write-Host ("`r" + (' ' * $platz) + "`r") -NoNewline
    } catch { }
    $script:BalkenAktiv = $false
    $script:LetzteAusgabe = -1000
}

# --------------------------------------------------------------
# Notfallweg: kompletten Ordner als ZIP holen
# (falls der Server oder ein Filter im Schulnetz WebDAV blockiert)
# --------------------------------------------------------------
function Hole-UeberZip {
    param($Client, $Share, [string]$Passwort, [string]$ZielOrdner, [string]$UnterPfad)

    $zipUrl = "{0}/s/{1}/download" -f $Share.Basis, $Share.Token
    if ($UnterPfad) {
        $zipUrl = $zipUrl + '?path=' + [Uri]::EscapeDataString('/' + ($UnterPfad -replace '\\', '/'))
    }
    Zeige-Meldung 'WebDAV nicht verfuegbar - versuche den kompletten Ordner als ZIP zu laden ...' $script:Farbe.Warn

    $tempZip = Join-Path $env:TEMP ('pytha-schulmaterial-' + [Guid]::NewGuid().ToString('N') + '.zip')
    $tempDir = Join-Path $env:TEMP ('pytha-entpackt-' + [Guid]::NewGuid().ToString('N'))

    try {
        $req = Neue-Anfrage -Methode 'GET' -Url $zipUrl -Benutzer $Share.Token -Passwort $Passwort
        $antwort = $Client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            if (-not $antwort.IsSuccessStatusCode) { throw ("Serverantwort " + [int]$antwort.StatusCode) }
            $script:GesamtBytes = 0
            try { if ($antwort.Content.Headers.ContentLength) { $script:GesamtBytes = [long]$antwort.Content.Headers.ContentLength } } catch { }
            $script:GeladeneBytes = 0
            $script:DateiNummer = 1
            $script:DateiAnzahl = 1
            $script:Uhr = [Diagnostics.Stopwatch]::StartNew()
            $quelle = $antwort.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $zielStrom = [IO.File]::Open($tempZip, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try {
                $puffer = New-Object byte[] 65536
                while ($true) {
                    $gelesen = $quelle.Read($puffer, 0, $puffer.Length)
                    if ($gelesen -le 0) { break }
                    $zielStrom.Write($puffer, 0, $gelesen)
                    $script:GeladeneBytes += $gelesen
                    Zeichne-Balken
                }
            } finally { $zielStrom.Dispose(); $quelle.Dispose() }
            Loesche-Balken
        } finally { $antwort.Dispose(); $req.Dispose() }

        try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue } catch { }
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        [IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempDir)

        # Nextcloud packt alles in einen Ordner mit dem Namen der Freigabe
        $wurzel = $tempDir
        $kinder = @(Get-ChildItem -LiteralPath $tempDir -Force)
        if ($kinder.Count -eq 1 -and $kinder[0].PSIsContainer) { $wurzel = $kinder[0].FullName }

        # Sicherung: Wurde ein Unterordner angefordert, muss das ZIP auch diesen
        # enthalten. Sonst haette der Server die ganze Freigabe geschickt.
        if ($UnterPfad) {
            $erwartet = @($UnterPfad -split '[\\/]+' | Where-Object { $_ -ne '' })[-1]
            if ((Split-Path -Leaf $wurzel) -ne $erwartet) {
                throw ("Der Ordner '{0}' war im ZIP der Freigabe nicht enthalten - der Freigabelink zeigt vermutlich ins Leere. Es wurde nichts kopiert." -f $UnterPfad)
            }
        }

        $ordnerImZip = New-Object System.Collections.ArrayList
        foreach ($o in @(Get-ChildItem -LiteralPath $wurzel -Recurse -Force | Where-Object { $_.PSIsContainer })) {
            [void]$ordnerImZip.Add($o.FullName.Substring($wurzel.Length).TrimStart('\', '/').Replace('\', '/'))
        }
        $neueOrdner = Lege-Ordner-An -Basis $ZielOrdner -Ordnerliste $ordnerImZip
        if ($neueOrdner -gt 0) {
            Zeige-Meldung ("{0} neue(r) Ordner angelegt." -f $neueOrdner) $script:Farbe.Leise
        }

        $alle = @(Get-ChildItem -LiteralPath $wurzel -Recurse -File -Force)
        Zeige-Meldung ("Im ZIP enthalten: {0} Datei(en)." -f $alle.Count) $script:Farbe.Leise
        Write-Host ''

        $zuKopieren = New-Object System.Collections.ArrayList
        foreach ($f in $alle) {
            $rel = $f.FullName.Substring($wurzel.Length).TrimStart('\', '/')
            $zielDatei = Join-Path $ZielOrdner $rel
            if ((Braucht-Download -Pfad $zielDatei -Groesse $f.Length -Geaendert $f.LastWriteTimeUtc) -eq 'aktuell') {
                $script:Aktuell++
                Schreib-Detail ("  aktuell   " + $rel)
            } else {
                [void]$zuKopieren.Add($f)
            }
        }

        $script:GeladeneBytes = 0
        $script:GesamtBytes = 0
        $script:DateiNummer = 0
        $script:DateiAnzahl = $zuKopieren.Count
        foreach ($f in $zuKopieren) { $script:GesamtBytes += $f.Length }
        $script:Uhr = [Diagnostics.Stopwatch]::StartNew()

        foreach ($f in $zuKopieren) {
            $script:DateiNummer++
            $rel = $f.FullName.Substring($wurzel.Length).TrimStart('\', '/')
            $zielDatei = Join-Path $ZielOrdner $rel
            $grund = Braucht-Download -Pfad $zielDatei -Groesse $f.Length -Geaendert $f.LastWriteTimeUtc
            $ordner = Split-Path -Parent $zielDatei
            if ($ordner -and -not (Test-Path -LiteralPath $ordner)) { New-Item -ItemType Directory -Path $ordner -Force | Out-Null }
            Entsperre-Datei -Pfad $zielDatei
            Copy-Item -LiteralPath $f.FullName -Destination $zielDatei -Force
            $script:SummeBytes += $f.Length
            $script:GeladeneBytes += $f.Length
            Zeichne-Balken
            if ($grund -eq 'neu') {
                $script:Neu++
                Zeige-Eintrag $script:Z.Neu $script:Farbe.Neu $rel 'NEU'
            } else {
                $script:Aktualisiert++
                Zeige-Eintrag $script:Z.Alt $script:Farbe.Alt $rel 'ERNEUERT'
            }
        }
        Loesche-Balken
        return $true
    } catch {
        Loesche-Balken
        $script:LetzterZipFehler = $_.Exception.Message
        Schreib ("  ZIP-Weg fehlgeschlagen: " + $_.Exception.Message) 'DarkYellow' -NurProtokoll
        return $false
    } finally {
        try { if (Test-Path -LiteralPath $tempZip) { Remove-Item -LiteralPath $tempZip -Force } } catch { }
        try { if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force } } catch { }
    }
}

# --------------------------------------------------------------
# PYTHA-Installationsdatei holen (nur wenn noetig)
# --------------------------------------------------------------
function Hole-Installationsdatei {
    param($Client, [string]$Url, [string]$Ordner)

    $name = ($Url.Split('?')[0].TrimEnd('/').Split('/'))[-1]
    if (-not $name) { $name = 'setup_pytha.exe' }
    $zielDatei = Join-Path $Ordner $name

    Zeige-Status 'Frage die Installationsdatei beim Hersteller ab ...' -Erzwingen

    # Kopfdaten des Servers erfragen
    [long]$fern = -1
    $ferngeaendert = [DateTime]::MinValue
    try {
        $kopf = Neue-Anfrage -Methode 'HEAD' -Url $Url -OhneAnmeldung
        $antwort = $Client.SendAsync($kopf).GetAwaiter().GetResult()
        if ($antwort.IsSuccessStatusCode) {
            try { if ($antwort.Content.Headers.ContentLength) { $fern = [long]$antwort.Content.Headers.ContentLength } } catch { }
            # Hinweis: PowerShell packt Nullable-Werte selbst aus, .Value gibt es hier nicht.
            try {
                $lm = $antwort.Content.Headers.LastModified
                if ($lm) { $ferngeaendert = ([DateTimeOffset]$lm).UtcDateTime }
            } catch { }
        }
        $antwort.Dispose()
        $kopf.Dispose()
    } catch {
        Schreib ("  Setup: Kopfdaten nicht abrufbar - " + $_.Exception.Message) 'DarkYellow' -NurProtokoll
    }

    $vorhanden = Test-Path -LiteralPath $zielDatei
    if ($vorhanden -and $fern -lt 0) {
        Zeige-Eintrag '=' $script:Farbe.Leise ($name + '   (vorhanden, Server nicht befragbar)') 'SETUP'
        return
    }
    if ($vorhanden) {
        $lokal = (Get-Item -LiteralPath $zielDatei).Length
        if ($lokal -eq $fern) {
            $script:Aktuell++
            Zeige-Eintrag '=' $script:Farbe.Leise ($name + '   (bereits aktuell, ' + (Formatiere-Bytes $fern) + ')') 'SETUP'
            return
        }
    }

    if (-not (Test-Path -LiteralPath $Ordner)) { New-Item -ItemType Directory -Path $Ordner -Force | Out-Null }

    $script:GeladeneBytes = 0
    $script:GesamtBytes = [Math]::Max(0, $fern)
    $script:DateiNummer = 1
    $script:DateiAnzahl = 1
    $script:Uhr = [Diagnostics.Stopwatch]::StartNew()
    Zeichne-Balken -Erzwingen

    if ($null -eq $ferngeaendert) { $ferngeaendert = [DateTime]::MinValue }
    $geholt = Hole-Datei -Client $Client -Url $Url -Ziel $zielDatei -Geaendert $ferngeaendert -MitFortschritt -OhneAnmeldung
    Loesche-Balken
    $script:SummeBytes += $geholt
    if ($vorhanden) {
        $script:Aktualisiert++
        Zeige-Eintrag $script:Z.Alt $script:Farbe.Alt ($name + '   (' + (Formatiere-Bytes $geholt) + ')') 'SETUP'
    } else {
        $script:Neu++
        Zeige-Eintrag $script:Z.Neu $script:Farbe.Neu ($name + '   (' + (Formatiere-Bytes $geholt) + ')') 'SETUP'
    }
}


function Automatik-Ordner {
    $b = $env:LOCALAPPDATA
    if (-not $b) { $b = $env:TEMP }
    return (Join-Path $b 'PYTHA-Update')
}

function Heute-Schon-Gelaufen {
    try {
        $d = Join-Path (Automatik-Ordner) 'letzter-lauf.txt'
        if (-not (Test-Path -LiteralPath $d)) { return $false }
        $inhalt = ''
        $zeilen = @(Get-Content -LiteralPath $d -ErrorAction SilentlyContinue)
        if ($zeilen.Count -gt 0) { $inhalt = ([string]$zeilen[0]).Trim() }
        return ($inhalt -eq (Get-Date -Format 'yyyy-MM-dd'))
    } catch { return $false }
}

function Merke-Lauf {
    try {
        $o = Automatik-Ordner
        if (-not (Test-Path -LiteralPath $o)) { New-Item -ItemType Directory -Path $o -Force | Out-Null }
        Set-Content -LiteralPath (Join-Path $o 'letzter-lauf.txt') -Value (Get-Date -Format 'yyyy-MM-dd')
    } catch { }
}


function Automatik-Aktiv {
    # Aktiv = die geplante Aufgabe ist vorhanden
    try {
        $dienst = New-Object -ComObject 'Schedule.Service'
        $dienst.Connect()
        $ordner = $dienst.GetFolder('\')
        $aufgabe = $ordner.GetTask($AufgabenName)
        return ($null -ne $aufgabe)
    } catch { return $false }
}

# Laeuft diese Datei mit Administratorrechten?
function Bin-Ich-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

# --------------------------------------------------------------
# PYTHA: Schuleinstellungen setzen und bei Bedarf installieren
# --------------------------------------------------------------

# Ist PYTHA 26 bereits installiert? Gesucht wird in der Deinstallations-
# Liste von Windows (beide Registrierungs-Sichten) und zusaetzlich am
# Programmschluessel von PYTHA.
# Ist PYTHA 26 wirklich installiert?
# Geprueft wird NUR die Windows-Deinstallationsliste - die wird beim
# Deinstallieren sauber entfernt. Der Schluessel "PYTHA Lab GmbH\PYTHA26.0"
# wird BEWUSST NICHT geprueft: Er bleibt nach einer Deinstallation haeufig
# als Rest zurueck und wuerde faelschlich "installiert" melden.
# Zusaetzlich wird geprueft, ob der Programmordner noch existiert.
function Pytha26-Installiert {
    $orte = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($ort in $orte) {
        try {
            if (-not (Test-Path -LiteralPath $ort)) { continue }
            foreach ($eintrag in (Get-ChildItem -LiteralPath $ort -ErrorAction SilentlyContinue)) {
                $daten = $null
                try { $daten = Get-ItemProperty -LiteralPath $eintrag.PSPath -ErrorAction SilentlyContinue } catch { }
                if (-not $daten) { continue }
                $name = [string]$daten.DisplayName
                if (-not $name) { continue }
                if (-not ($name -match '(?i)PYTHA' -and $name -match '26')) { continue }

                # Gegenprobe: Ist der Programmordner noch da? Sonst ist das
                # ein Ueberbleibsel einer unsauberen Deinstallation.
                $ordner = [string]$daten.InstallLocation
                if ($ordner) {
                    $ordner = $ordner.Trim('"').TrimEnd('\')
                    if (-not (Test-Path -LiteralPath $ordner)) {
                        Schreib ('PRUEFUNG   Ueberbleibsel ignoriert (Ordner fehlt): ' + $name) 'Gray' -NurProtokoll
                        continue
                    }
                }
                Schreib ('PRUEFUNG   installiert erkannt: ' + $name) 'Gray' -NurProtokoll
                return $true
            }
        } catch { }
    }
    Schreib 'PRUEFUNG   PYTHA 26 wurde NICHT als installiert erkannt.' 'Gray' -NurProtokoll
    return $false
}

# Sucht die Schuleinstellungs-ZIP im Transferordner. So muss der Dateiname
# nicht je Schule eingetragen werden.
function Finde-Transferdatei {
    param([string]$Ordner, [string]$Kennung)
    try {
        if (-not (Test-Path -LiteralPath $Ordner)) { return '' }
        $zips = @(Get-ChildItem -LiteralPath $Ordner -Filter '*.zip' -File -ErrorAction SilentlyContinue)
        if ($zips.Count -eq 0) { return '' }
        if ($zips.Count -eq 1) { return $zips[0].FullName }
        if ($Kennung) {
            foreach ($z in $zips) { if ($z.Name -match ('(?i)' + [regex]::Escape($Kennung))) { return $z.FullName } }
        }
        return (@($zips | Sort-Object LastWriteTime -Descending)[0].FullName)
    } catch { return '' }
}

# Traegt die beiden Werte ein. Liefert '' bei Erfolg, sonst den Grund.
function Setze-Schuleinstellungen {
    param([string]$Schluessel, [string]$ZipPfad, [int]$Wert)
    try {
        if (-not (Test-Path -LiteralPath $Schluessel)) {
            New-Item -Path $Schluessel -Force -ErrorAction Stop | Out-Null
        }
        New-ItemProperty -LiteralPath $Schluessel -Name 'Transferdatei lesen' -Value $Wert -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -LiteralPath $Schluessel -Name 'Transferdatei Standardpfad' -Value $ZipPfad -PropertyType String -Force -ErrorAction Stop | Out-Null
        Schreib ('REGISTRY   ' + $Schluessel + ' -> Transferdatei lesen=' + $Wert) 'Gray' -NurProtokoll
        Schreib ('REGISTRY   Standardpfad=' + $ZipPfad) 'Gray' -NurProtokoll
        return ''
    } catch {
        return $_.Exception.Message
    }
}


# --------------------------------------------------------------
# Einstellungen aus einstellungen.ini (vom Installer geschrieben)
# --------------------------------------------------------------
function Lade-Einstellungen {
    $e = @{
        Schule = 'ANDERE'; Registry = '0'; TransferWert = '2'; PythaInstallieren = '0'
        Automatik = '0'; Uhrzeit = '13:00'; BeiAnmeldung = '1'; Geschuetzt = ''
    }
    try {
        if (Test-Path -LiteralPath $EinstellDatei) {
            foreach ($zeile in (Get-Content -LiteralPath $EinstellDatei)) {
                $t = ([string]$zeile).Trim()
                if (-not $t -or $t.StartsWith(';') -or $t.StartsWith('[')) { continue }
                $p = $t.IndexOf('=')
                if ($p -lt 1) { continue }
                $e[$t.Substring(0, $p).Trim()] = $t.Substring($p + 1).Trim()
            }
        }
    } catch { }
    return $e
}

# Geschuetzte Dateien: relative Pfade, durch ; getrennt, z. B.
# 13_Material/Logos/Logo.jpg  -> werden nie ueberschrieben
function Lies-Geschuetzt {
    param([string]$Text)
    $set = @{}
    if (-not $Text) { return $set }
    foreach ($teil in ($Text -split ';')) {
        $t = $teil.Trim().Replace('\', '/').Trim('/')
        if ($t) { $set[$t.ToLowerInvariant()] = $true }
    }
    return $set
}

# Kurze Zusammenfassung fuer den Installer (Schluessel=Wert, ASCII)
function Merke-Ergebnis {
    param([string]$Schluessel, [string]$Wert)
    $script:InstallErgebnis[$Schluessel] = $Wert
}

function Schreibe-Ergebnis {
    if (-not $ErgebnisDatei) { return }
    try {
        $zeilen = @()
        foreach ($k in $script:InstallErgebnis.Keys) { $zeilen += ($k + '=' + $script:InstallErgebnis[$k]) }
        Set-Content -LiteralPath $ErgebnisDatei -Value $zeilen -Encoding ASCII
    } catch { }
}

# --------------------------------------------------------------
# Taegliche Aktualisierung ueber die Aufgabenplanung
#   - laeuft fuer ALLE Benutzer des PCs (Gruppe "Benutzer")
#   - startet unsichtbar ueber Aktualisieren-still.vbs im Programmordner
#   - braucht zum Anlegen Adminrechte
# --------------------------------------------------------------
function Richte-Automatik-Ein {
    param([string]$Uhrzeit, [bool]$BeiAnmeldung)
    $vbs = Join-Path $PSScriptRoot 'Aktualisieren-still.vbs'
    if (-not (Test-Path -LiteralPath $vbs)) {
        Schreib ('AUTOMATIK  Starter fehlt: ' + $vbs) 'DarkYellow' -NurProtokoll
        return ''
    }
    $stunde = 13; $minute = 0
    try {
        $tt = ([string]$Uhrzeit) -split ':'
        if ($tt.Count -ge 2) { $stunde = [int]$tt[0]; $minute = [int]$tt[1] }
    } catch { }
    if ($stunde -lt 0 -or $stunde -gt 23) { $stunde = 13 }
    if ($minute -lt 0 -or $minute -gt 59) { $minute = 0 }
    $zeitText = '{0:00}:{1:00}' -f $stunde, $minute

    foreach ($fuerAlle in @($true, $false)) {
    try {
        $dienst = New-Object -ComObject 'Schedule.Service'
        $dienst.Connect()
        $ordner = $dienst.GetFolder('\')
        # alte Aufgabe aus der .cmd-Zeit aufraeumen
        try { $ordner.DeleteTask($AlterAufgabenName, 0) } catch { }

        $auf = $dienst.NewTask(0)
        $auf.RegistrationInfo.Description = 'Haelt das PLG PYTHA-Schulmaterial aktuell (PLG PYTHA-Schulmaterial).'
        $auf.RegistrationInfo.Author = 'PLG PYTHA-Schulmaterial'
        $auf.Settings.Enabled = $true
        $auf.Settings.StartWhenAvailable = $true
        $auf.Settings.DisallowStartIfOnBatteries = $false
        $auf.Settings.StopIfGoingOnBatteries = $false
        $auf.Settings.ExecutionTimeLimit = 'PT2H'
        $auf.Settings.MultipleInstances = 2          # nicht doppelt laufen
        $start = '{0:yyyy-MM-dd}T{1:00}:{2:00}:00' -f (Get-Date), $stunde, $minute
        $t1 = $auf.Triggers.Create(2)                # taeglich
        $t1.StartBoundary = $start
        $t1.DaysInterval = 1
        $t1.Enabled = $true
        if ($BeiAnmeldung) {
            $t2 = $auf.Triggers.Create(9)            # bei der Anmeldung (jedes Benutzers)
            $t2.Delay = 'PT3M'
            $t2.Enabled = $true
        }
        $auf.Principal.RunLevel = 0                  # ohne erhoehte Rechte
        $aktion = $auf.Actions.Create(0)
        $aktion.Path = 'wscript.exe'
        $aktion.Arguments = '//B //Nologo "' + $vbs + '"'
        if ($fuerAlle) {
            # Gruppe "Benutzer" (S-1-5-32-545): laeuft fuer jeden, der sich anmeldet
            $auf.Principal.GroupId = 'S-1-5-32-545'
            [void]$ordner.RegisterTaskDefinition($AufgabenName, $auf, 6, $null, $null, 4)
            Schreib 'AUTOMATIK  Aufgabe fuer alle Benutzer eingerichtet.' 'Gray' -NurProtokoll
        } else {
            # Rueckfall: nur fuer den Benutzer, der installiert
            [void]$ordner.RegisterTaskDefinition($AufgabenName, $auf, 6, $null, $null, 3)
            Schreib 'AUTOMATIK  Aufgabe fuer den aktuellen Benutzer eingerichtet.' 'Gray' -NurProtokoll
        }
        $text = 'taeglich um ' + $zeitText + ' Uhr'
        if ($BeiAnmeldung) { $text += ' und bei jeder Anmeldung' }
        return $text
    } catch {
        Schreib ('Aufgabenplanung nicht moeglich (fuer alle=' + $fuerAlle + '): ' + $_.Exception.Message) 'DarkYellow' -NurProtokoll
    }
    }
    return ''
}

function Entferne-Automatik {
    $weg = $false
    foreach ($name in @($AufgabenName, $AlterAufgabenName)) {
        try {
            $dienst = New-Object -ComObject 'Schedule.Service'
            $dienst.Connect()
            $dienst.GetFolder('\').DeleteTask($name, 0)
            $weg = $true
        } catch { }
    }
    return $weg
}

# Traegt die Schuleinstellungen nur aus, wenn sie auf UNSEREN Ordner zeigen
function Entferne-Schuleinstellungen {
    try {
        if (-not (Test-Path -LiteralPath $RegistrierungsPfad)) { return }
        $w = Get-ItemProperty -LiteralPath $RegistrierungsPfad -ErrorAction SilentlyContinue
        $pfad = [string]$w.'Transferdatei Standardpfad'
        if ($pfad -and $pfad.StartsWith($ZielOrdner, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-ItemProperty -LiteralPath $RegistrierungsPfad -Name 'Transferdatei lesen' -ErrorAction SilentlyContinue
            Remove-ItemProperty -LiteralPath $RegistrierungsPfad -Name 'Transferdatei Standardpfad' -ErrorAction SilentlyContinue
            Schreib 'REGISTRY   Schuleinstellungen ausgetragen.' 'Gray' -NurProtokoll
        }
    } catch { }
}

# ==============================================================
#                       H A U P T T E I L
# ==============================================================

Start-Protokoll
$einst = Lade-Einstellungen

# ---- Deinstallation: Aufgabe (und ggf. Registry) entfernen, sonst nichts ----
if ($Entfernen) {
    Schreib ('--- Entfernen | Version ' + $ScriptVersion) 'DarkGray' -NurProtokoll
    [void](Entferne-Automatik)
    if ($EntferneRegistry -and (Bin-Ich-Admin)) { Entferne-Schuleinstellungen }
    exit 0
}

Setze-Darstellung

# ---- Welche Schule? Steht in den Einstellungen ----
$gewaehlt = $null
foreach ($f in $Fassungen) { if ($f.Kuerzel -ieq [string]$einst.Schule) { $gewaehlt = $f; break } }
if ($gewaehlt) {
    $LinkDaten = $gewaehlt.LinkDaten
    $Variante = $gewaehlt.Bezeichnung
} else {
    $LinkDaten = $StandardLinkDaten
    $Variante = $StandardBezeichnung
}
$geschuetztSet = Lies-Geschuetzt ([string]$einst.Geschuetzt)
$istAdmin = Bin-Ich-Admin
if ($istAdmin) { Merke-Ergebnis 'Admin' 'ja' } else { Merke-Ergebnis 'Admin' 'nein' }

Zeige-Kopf -Titel 'PLG   PYTHA-Schulmaterial aktualisieren' -Rechts ('[ ' + $Variante + ' ]')
Setze-Titel 'PLG PYTHA-Schulmaterial aktualisieren'
$modus = 'von Hand'
if ($script:Leise) { $modus = 'stiller Lauf' } elseif ($Einrichten) { $modus = 'Installation' }
Schreib ("--- {0} | Version {1} | Start {2} | {3}" -f $Variante, $ScriptVersion, (Get-Date -Format 'dd.MM.yyyy HH:mm'), $modus) 'DarkGray' -NurProtokoll

if ($HoechstensEinmalTaeglich -and $script:Leise -and (Heute-Schon-Gelaufen)) {
    Schreib 'Stiller Lauf uebersprungen - heute wurde bereits geprueft.' 'Gray' -NurProtokoll
    exit 0
}

try {
    $client = Initialisiere-HttpClient

    $ShareUrl = Entschluessle $LinkDaten
    if ([string]::IsNullOrWhiteSpace($ShareUrl)) {
        throw ("Fuer '" + $Variante + "' ist keine gueltige Adresse hinterlegt. Bitte eine neue Version des Installers verwenden.")
    }
    $share = Split-ShareUrl -Url $ShareUrl
    $script:Origin = $share.Origin

    $unterPfad = $Unterordner
    if (-not $unterPfad) { $unterPfad = $share.PfadAusQuery }
    if (-not $unterPfad) { $unterPfad = '' }
    $unterPfad = $unterPfad.Trim('/').Trim('\')

    Zeige-Feld 'Schule' $Variante
    Zeige-Feld 'Zielordner' $ZielOrdner
    if ($geschuetztSet.Count -gt 0) { Zeige-Feld 'Eigenes Logo' 'bleibt erhalten' $script:Farbe.Gut }
    Write-Host ''
    Write-Host '   Das Fenster bitte offen lassen, bis unten "Fertig" steht.' -ForegroundColor $script:Farbe.Warn
    Write-Host ''

    if (-not (Test-Path -LiteralPath $ZielOrdner)) {
        New-Item -ItemType Directory -Path $ZielOrdner -Force | Out-Null
    }

    $varianten = @(
        (New-Object psobject -Property @{ Name = 'Nextcloud (aktuell)';   Url = ("{0}/public.php/dav/files/{1}/" -f $share.Basis, $share.Token); Benutzer = 'anonymous';   Passwort = $SharePassword }),
        (New-Object psobject -Property @{ Name = 'Nextcloud (klassisch)'; Url = ("{0}/public.php/webdav/" -f $share.Basis);                      Benutzer = $share.Token;  Passwort = $SharePassword }),
        (New-Object psobject -Property @{ Name = 'ownCloud';              Url = ("{0}/public.php/webdav/" -f $share.Basis);                      Benutzer = 'anonymous';   Passwort = $SharePassword })
    )

    Zeige-Meldung 'Verbinde mit der Cloud und lese die Dateiliste ...' $script:Farbe.Leise

    $dateien = $null
    $ordnerAusFreigabe = @()
    $benutzt = $null
    foreach ($v in $varianten) {
        $startUrl = $v.Url
        if ($unterPfad) {
            foreach ($t in ($unterPfad -split '[\\/]+')) {
                if ($t) { $startUrl = $startUrl + [Uri]::EscapeDataString($t) + '/' }
            }
        }
        Schreib-Detail ("  Versuch: {0} -> {1}" -f $v.Name, (Maskiere $startUrl))
        $wurzel = $null
        try {
            $wurzel = Lies-Verzeichnis -Client $client -Url $v.Url -Benutzer $v.Benutzer -Passwort $v.Passwort
        } catch {
            Schreib-Detail ("  fehlgeschlagen: " + $_.Exception.Message) 'DarkYellow'
        }
        if ($null -eq $wurzel -or -not $wurzel.Ok) { continue }

        $ergebnis = $null
        try {
            $ergebnis = Sammle-Dateien -Client $client -StartUrl $startUrl -Benutzer $v.Benutzer -Passwort $v.Passwort
        } catch {
            Schreib-Detail ("  fehlgeschlagen: " + $_.Exception.Message) 'DarkYellow'
        }
        if ($null -ne $ergebnis -and $ergebnis.Ok) {
            $dateien = @($ergebnis.Dateien)
            $ordnerAusFreigabe = @($ergebnis.Ordner)
            $benutzt = $v
            break
        }
    }

    if ($null -eq $benutzt) {
        throw "Die Cloud konnte nicht gelesen werden. Moegliche Ursachen: keine Internetverbindung, ein Filter im Netzwerk oder die Freigabe wurde geaendert."
    }

    Schreib ("Zugang ueber: {0}" -f $benutzt.Name) 'DarkGray' -NurProtokoll
    Zeige-Meldung ("In der Cloud liegen {0} Datei(en)." -f $dateien.Count) $script:Farbe.Leise

    $neueOrdner = Lege-Ordner-An -Basis $ZielOrdner -Ordnerliste $ordnerAusFreigabe
    if ($neueOrdner -gt 0) { Zeige-Meldung ("{0} neue(r) Ordner angelegt." -f $neueOrdner) $script:Farbe.Leise }

    # ---- Vergleichen; geschuetzte Dateien (eigenes Logo) bleiben aussen vor ----
    $plan = New-Object System.Collections.ArrayList
    $geprueft = 0
    Zeige-Status ("Vergleiche mit dem Ordner auf diesem PC ...   0 von {0}" -f $dateien.Count) -Erzwingen
    foreach ($d in $dateien) {
        $geprueft++
        Zeige-Status ("Vergleiche mit dem Ordner auf diesem PC ...   {0} von {1}" -f $geprueft, $dateien.Count)
        $relKlein = ([string]$d.Rel).Replace('\', '/').Trim('/').ToLowerInvariant()
        if ($geschuetztSet.ContainsKey($relKlein)) {
            $script:Geschuetzt++
            Schreib ('GESCHUETZT ' + $d.Rel) 'Gray' -NurProtokoll
            continue
        }
        $zielDatei = $ZielOrdner
        foreach ($teil in $d.Rel.Split('/')) { if ($teil) { $zielDatei = Join-Path $zielDatei $teil } }
        $grund = Braucht-Download -Pfad $zielDatei -Groesse $d.Groesse -Geaendert $d.Geaendert
        if ($grund -eq 'aktuell') {
            $script:Aktuell++
            Schreib-Detail ("  aktuell   " + $d.Rel)
        } else {
            [void]$plan.Add([pscustomobject]@{ Datei = $d; Ziel = $zielDatei; Grund = $grund })
        }
    }
    Loesche-Balken

    $script:DateiAnzahl = $plan.Count
    $script:GesamtBytes = 0
    foreach ($p in $plan) { if ($p.Datei.Groesse -gt 0) { $script:GesamtBytes += $p.Datei.Groesse } }

    if ($plan.Count -gt 0) {
        Zeige-Meldung ("Davon zu holen: {0} Datei(en), {1}." -f $plan.Count, (Formatiere-Bytes $script:GesamtBytes)) $script:Farbe.Text
        Write-Host ''
        Zeige-Linie
        Write-Host ''
    } elseif ($dateien.Count -gt 0) {
        Zeige-Meldung 'Alle Dateien sind bereits auf dem aktuellen Stand.' $script:Farbe.Gut
    }

    $script:Uhr = [Diagnostics.Stopwatch]::StartNew()
    foreach ($p in $plan) {
        $d = $p.Datei
        $script:DateiNummer++
        $vorher = $script:GeladeneBytes
        Zeichne-Balken -Erzwingen
        try {
            $geholt = Hole-Datei -Client $client -Url $d.Url -Ziel $p.Ziel -Benutzer $benutzt.Benutzer -Passwort $benutzt.Passwort -Geaendert $d.Geaendert -MitFortschritt
            $script:SummeBytes += $geholt
            $script:GeladeneBytes = $vorher + $geholt
            if ($p.Grund -eq 'neu') {
                $script:Neu++
                Zeige-Eintrag $script:Z.Neu $script:Farbe.Neu $d.Rel 'NEU'
            } else {
                $script:Aktualisiert++
                Zeige-Eintrag $script:Z.Alt $script:Farbe.Alt $d.Rel 'ERNEUERT'
            }
        } catch {
            $script:Fehler++
            $script:GeladeneBytes = $vorher
            if ($d.Groesse -gt 0) { $script:GeladeneBytes += $d.Groesse }
            Zeige-Eintrag '!' $script:Farbe.Fehler ($d.Rel + '   (' + $_.Exception.Message + ')') 'FEHLER'
        }
        Zeichne-Balken -Erzwingen
    }
    Loesche-Balken
    $script:Dauer = ''
    if ($plan.Count -gt 0 -and $script:Uhr) { $script:Dauer = Formatiere-Zeit ($script:Uhr.ElapsedMilliseconds / 1000) }

    # ---- PYTHA-Installationsdatei ----
    if ($SetupHolen -and $SetupUrl) {
        Write-Host ''
        Zeige-Meldung 'PYTHA-Installationsdatei:' $script:Farbe.Leise
        try {
            Hole-Installationsdatei -Client $client -Url $SetupUrl -Ordner (Join-Path $ZielOrdner $SetupOrdner)
        } catch {
            Loesche-Balken
            Zeige-Meldung ('Die Installationsdatei konnte nicht geladen werden: ' + $_.Exception.Message) $script:Farbe.Warn
            Zeige-Meldung 'Das Schulmaterial ist davon nicht betroffen.' $script:Farbe.Warn
        }
    }

    $client.Dispose()
    Loesche-Balken

    Write-Host ''
    Zeige-Linie
    Write-Host ''
    Zeige-Feld 'Neu geladen' ([string]$script:Neu)
    Zeige-Feld 'Erneuert' ([string]$script:Aktualisiert)
    Zeige-Feld 'Bereits aktuell' ([string]$script:Aktuell)
    if ($script:Geschuetzt -gt 0) { Zeige-Feld 'Geschuetzt' ([string]$script:Geschuetzt + '  (eigenes Logo)') $script:Farbe.Gut }
    if ($script:Fehler -gt 0) { Zeige-Feld 'Fehler' ([string]$script:Fehler) $script:Farbe.Fehler }
    $menge = Formatiere-Bytes $script:SummeBytes
    if ($script:Dauer) { $menge = $menge + '   ' + $script:Z.Punkt + '   ' + $script:Dauer }
    Zeige-Feld 'Datenmenge' $menge
    Write-Host ''

    Merke-Ergebnis 'Neu' ([string]$script:Neu)
    Merke-Ergebnis 'Erneuert' ([string]$script:Aktualisiert)
    Merke-Ergebnis 'Fehler' ([string]$script:Fehler)
    if ($script:Fehler -eq 0) {
        Merke-Ergebnis 'Material' 'ok'
        Setze-Titel 'PLG PYTHA-Schulmaterial - fertig'
        Zeige-Meldung 'Fertig. Das Schulmaterial ist auf dem aktuellen Stand.' $script:Farbe.Gut
    } else {
        Merke-Ergebnis 'Material' 'teilweise'
        Setze-Titel 'PLG PYTHA-Schulmaterial - mit Hinweisen beendet'
        Zeige-Meldung 'Fertig, aber einzelne Dateien konnten nicht geladen werden.' $script:Farbe.Warn
        Zeige-Meldung 'Einfach spaeter noch einmal starten - es wird nur Fehlendes geholt.' $script:Farbe.Warn
    }
    Merke-Lauf
    if ($script:LogPfad) { Write-Host ("   Protokoll: " + $script:LogPfad) -ForegroundColor $script:Farbe.Leise }

    # ---- Nur bei der Installation: Schuleinstellungen, Automatik, PYTHA ----
    if ($Einrichten) {
      try {
        Write-Host ''
        Zeige-Linie
        Write-Host ''

        # 1. Schuleinstellungen
        if ([string]$einst.Registry -eq '1') {
            if (-not $istAdmin) {
                Merke-Ergebnis 'Registry' 'keine-adminrechte'
            } else {
                $zipPfad = Finde-Transferdatei -Ordner (Join-Path $ZielOrdner $TransferOrdner) -Kennung $Variante
                $wert = 2
                try { $wert = [int]$einst.TransferWert } catch { $wert = 2 }
                if ($wert -lt 0 -or $wert -gt 2) { $wert = 2 }
                if (-not $zipPfad) {
                    Zeige-Meldung ('Keine Schuleinstellungs-Datei im Ordner ' + $TransferOrdner + ' gefunden.') $script:Farbe.Warn
                    Merke-Ergebnis 'Registry' 'keine-zip'
                } else {
                    $fehler = Setze-Schuleinstellungen -Schluessel $RegistrierungsPfad -ZipPfad $zipPfad -Wert $wert
                    if ($fehler) {
                        Zeige-Meldung ('Schuleinstellungen konnten nicht eingetragen werden: ' + $fehler) $script:Farbe.Fehler
                        Merke-Ergebnis 'Registry' 'fehler'
                    } else {
                        Zeige-Feld 'Schuleinstellungen' ('eingetragen (Wert ' + $wert + ')') $script:Farbe.Gut
                        Merke-Ergebnis 'Registry' ('ok:' + $wert)
                    }
                }
            }
        }

        # 2. Taegliche Aktualisierung
        if ([string]$einst.Automatik -eq '1') {
            if (-not $istAdmin) {
                Merke-Ergebnis 'Automatik' 'keine-adminrechte'
            } else {
                $wie = Richte-Automatik-Ein -Uhrzeit ([string]$einst.Uhrzeit) -BeiAnmeldung ([string]$einst.BeiAnmeldung -eq '1')
                if ($wie) { Zeige-Feld 'Automatik' $wie $script:Farbe.Gut; Merke-Ergebnis 'Automatik' 'ok' }
                else { Zeige-Meldung 'Die taegliche Aktualisierung konnte nicht eingerichtet werden.' $script:Farbe.Warn; Merke-Ergebnis 'Automatik' 'fehler' }
            }
        } elseif ($istAdmin) {
            if (Entferne-Automatik) { Schreib 'AUTOMATIK  abgewaehlt - Aufgabe entfernt.' 'Gray' -NurProtokoll }
        }

        # 3. PYTHA installieren
        if ([string]$einst.PythaInstallieren -eq '1') {
            if (-not $istAdmin) {
                Merke-Ergebnis 'Pytha' 'keine-adminrechte'
            } elseif (Pytha26-Installiert) {
                Zeige-Feld 'PYTHA 26' 'bereits installiert' $script:Farbe.Gut
                Merke-Ergebnis 'Pytha' 'vorhanden'
            } else {
                $setupPfad = Join-Path (Join-Path $ZielOrdner $SetupOrdner) 'setup_pytha_26.exe'
                if (-not (Test-Path -LiteralPath $setupPfad)) {
                    Zeige-Meldung 'PYTHA ist nicht installiert, und die Setup-Datei fehlt.' $script:Farbe.Warn
                    Merke-Ergebnis 'Pytha' 'setup-fehlt'
                } else {
                    Write-Host ''
                    Zeige-Meldung 'PYTHA 26 wird jetzt installiert - bitte den Anweisungen folgen.' $script:Farbe.Text
                    Zeige-Meldung 'Dieses Fenster bitte so lange offen lassen.' $script:Farbe.Leise
                    try {
                        Schreib ('SETUP      starte ' + $setupPfad) 'Gray' -NurProtokoll
                        $lauf = Start-Process -FilePath $setupPfad -Wait -PassThru
                        Schreib ('SETUP      beendet, Code ' + $lauf.ExitCode) 'Gray' -NurProtokoll
                        # manche Installationsprogramme ueberschreiben die Werte - noch einmal setzen
                        if ([string]$einst.Registry -eq '1' -and $zipPfad) {
                            [void](Setze-Schuleinstellungen -Schluessel $RegistrierungsPfad -ZipPfad $zipPfad -Wert $wert)
                        }
                        if (Pytha26-Installiert) { Zeige-Meldung 'PYTHA 26 wurde installiert.' $script:Farbe.Gut; Merke-Ergebnis 'Pytha' 'installiert' }
                        else { Zeige-Meldung 'Die PYTHA-Installation wurde beendet oder abgebrochen.' $script:Farbe.Warn; Merke-Ergebnis 'Pytha' 'abgebrochen' }
                    } catch {
                        Zeige-Meldung ('Die Installation konnte nicht gestartet werden: ' + $_.Exception.Message) $script:Farbe.Fehler
                        Merke-Ergebnis 'Pytha' 'fehler'
                    }
                }
            }
        }
      } catch {
        Zeige-Meldung ('Hinweis: Zusatzschritt nicht abgeschlossen: ' + $_.Exception.Message) $script:Farbe.Warn
        Schreib ('Zusatzschritt fehlgeschlagen: ' + $_.Exception.Message) 'DarkYellow' -NurProtokoll
      }
    }

} catch {
    Loesche-Balken
    Merke-Ergebnis 'Material' 'abbruch'
    Merke-Ergebnis 'Meldung' (([string]$_.Exception.Message) -replace '[\r\n=]', ' ')
    Write-Host ''
    Zeige-Linie
    Write-Host ''
    Write-Host '   Die Aktualisierung konnte nicht durchgefuehrt werden.' -ForegroundColor $script:Farbe.Fehler
    Write-Host ''
    Zeige-Meldung $_.Exception.Message $script:Farbe.Fehler
    Write-Host ''
    if ($script:LogPfad) { Write-Host ("   Protokoll: " + $script:LogPfad) -ForegroundColor $script:Farbe.Leise }
} finally {
    Schreibe-Ergebnis
}

if ($Einrichten) {
    Write-Host ''
    Write-Host '   Weiter geht es im Installationsfenster ...' -ForegroundColor $script:Farbe.Leise
    Start-Sleep -Seconds 3
}
