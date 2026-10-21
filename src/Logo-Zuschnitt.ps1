param(
    [Parameter(Mandatory = $true)][string]$Ausgabe,   # Ziel, z. B. ...\Logo.jpg
    [string]$Vorschau = '',                           # optional: BMP fuer die Vorschau im Installer
    [string]$Symbol = ''                              # optional: .ico fuer das Fenster
)
# ==============================================================
#   PLG PYTHA-Schulmaterial - Logo zuschneiden
#   Oeffnet ein Bild (JPG, PNG, BMP, GIF, TIFF), zeigt einen festen
#   Rahmen von 472 x 115 Pixeln und speichert genau diesen Ausschnitt
#   als JPG. Durchsichtige Bereiche werden weiss.
#   Rueckgabe: 0 = gespeichert, 3 = abgebrochen, sonst Fehler
#   Fehlertext landet in <Ausgabe>.fehler.txt (fuer den Installer)
#   Lizenz: MIT
# ==============================================================

$ErrorActionPreference = 'Stop'
$FehlerDatei = $Ausgabe + '.fehler.txt'
function Merke-Fehler { param([string]$Text)
    try { [IO.File]::WriteAllText($FehlerDatei, $Text, [Text.Encoding]::UTF8) } catch { }
}
try { if (Test-Path -LiteralPath $FehlerDatei) { Remove-Item -LiteralPath $FehlerDatei -Force } } catch { }
trap {
    Merke-Fehler ($_.Exception.Message + [Environment]::NewLine + $_.InvocationInfo.PositionMessage)
    exit 2
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ZielBreite = 472
$ZielHoehe = 115
$FarbeDunkel = [System.Drawing.Color]::FromArgb(65, 75, 85)     # #414B55
$FarbeBlau = [System.Drawing.Color]::FromArgb(54, 126, 166)     # #367EA6
$FarbeHell = [System.Drawing.Color]::FromArgb(237, 237, 237)    # #EDEDED

# ---------- Bild laden: ohne Dateisperre, Drehung beachten, Transparenz -> weiss ----------
function Lade-Bild {
    param([string]$Pfad)
    $bytes = [IO.File]::ReadAllBytes($Pfad)
    $strom = New-Object IO.MemoryStream(, $bytes)
    $roh = [System.Drawing.Image]::FromStream($strom)
    try {
        # Handyfotos: EXIF-Ausrichtung (0x0112) beachten
        if ($roh.PropertyIdList -contains 0x0112) {
            $o = [int]$roh.GetPropertyItem(0x0112).Value[0]
            $dreh = @{ 3 = 'Rotate180FlipNone'; 6 = 'Rotate90FlipNone'; 8 = 'Rotate270FlipNone' }
            if ($dreh.ContainsKey($o)) { $roh.RotateFlip([System.Drawing.RotateFlipType]$dreh[$o]) }
        }
        $flach = New-Object System.Drawing.Bitmap($roh.Width, $roh.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $g = [System.Drawing.Graphics]::FromImage($flach)
        $g.Clear([System.Drawing.Color]::White)
        $g.DrawImage($roh, 0, 0, $roh.Width, $roh.Height)
        $g.Dispose()
        return $flach
    } finally {
        $roh.Dispose()
        $strom.Dispose()
    }
}

function Waehle-Datei {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Logo der Schule auswählen'
    $dlg.Filter = 'Bilder (*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff)|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff'
    $dlg.Multiselect = $false
    # unsichtbares Besitzerfenster, damit die Auswahl VOR dem Installer erscheint
    $besitzer = New-Object System.Windows.Forms.Form
    $besitzer.TopMost = $true
    $besitzer.ShowInTaskbar = $false
    $besitzer.StartPosition = 'CenterScreen'
    $besitzer.Size = New-Object System.Drawing.Size(1, 1)
    $besitzer.Opacity = 0
    $besitzer.Show()
    $antwort = $dlg.ShowDialog($besitzer)
    $besitzer.Close()
    if ($antwort -ne [System.Windows.Forms.DialogResult]::OK) { return '' }
    return $dlg.FileName
}

# ---------- Zustand ----------
$script:Bild = $null
$script:Zoom = 1.0
$script:MinZoom = 1.0
$script:MaxZoom = 1.0
$script:OffX = 0.0
$script:OffY = 0.0
$script:Ziehen = $false
$script:Start = $null
$script:Ergebnis = 3
$script:ReglerIntern = $false

$LeinwandB = 720
$LeinwandH = 340
$RahmenX = [int](($LeinwandB - $ZielBreite) / 2)
$RahmenY = [int](($LeinwandH - $ZielHoehe) / 2)

function Begrenze-Achse {
    param([double]$Off, [double]$Laenge, [double]$Start, [double]$Fenster)
    if ($Laenge -le $Fenster) {
        # Bild kleiner als der Rahmen: frei verschiebbar, aber ganz im Rahmen (Rest weiss)
        if ($Off -lt $Start) { $Off = $Start }
        if ($Off + $Laenge -gt $Start + $Fenster) { $Off = $Start + $Fenster - $Laenge }
    } else {
        # Bild groesser als der Rahmen: muss ihn in dieser Richtung ganz bedecken
        if ($Off -gt $Start) { $Off = $Start }
        if ($Off + $Laenge -lt $Start + $Fenster) { $Off = $Start + $Fenster - $Laenge }
    }
    return $Off
}

function Begrenze {
    $script:OffX = Begrenze-Achse $script:OffX ($script:Bild.Width * $script:Zoom) $RahmenX $ZielBreite
    $script:OffY = Begrenze-Achse $script:OffY ($script:Bild.Height * $script:Zoom) $RahmenY $ZielHoehe
}

function Setze-Zoom {
    param([double]$Neu, [double]$UmX, [double]$UmY)
    if ($Neu -lt $script:MinZoom) { $Neu = $script:MinZoom }
    if ($Neu -gt $script:MaxZoom) { $Neu = $script:MaxZoom }
    # Bildpunkt unter (UmX, UmY) bleibt an seiner Stelle
    $bx = ($UmX - $script:OffX) / $script:Zoom
    $by = ($UmY - $script:OffY) / $script:Zoom
    $script:Zoom = $Neu
    $script:OffX = $UmX - $bx * $Neu
    $script:OffY = $UmY - $by * $Neu
    Begrenze
}

function Zoom-Zu-Regler { param([double]$z)
    if ($script:MaxZoom -le $script:MinZoom) { return 0 }
    $t = [Math]::Log($z / $script:MinZoom) / [Math]::Log($script:MaxZoom / $script:MinZoom)
    return [int][Math]::Round([Math]::Max(0, [Math]::Min(1, $t)) * 1000)
}
function Regler-Zu-Zoom { param([int]$w)
    return $script:MinZoom * [Math]::Pow($script:MaxZoom / $script:MinZoom, $w / 1000.0)
}

function Erzeuge-Ausschnitt {
    $aus = New-Object System.Drawing.Bitmap($ZielBreite, $ZielHoehe, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($aus)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $ziel = New-Object System.Drawing.RectangleF(([single]($script:OffX - $RahmenX)), ([single]($script:OffY - $RahmenY)), ([single]($script:Bild.Width * $script:Zoom)), ([single]($script:Bild.Height * $script:Zoom)))
    $g.DrawImage($script:Bild, $ziel)
    $g.Dispose()
    return $aus
}

# ---------- Fenster ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Logo zuschneiden  –  472 × 115 Pixel'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(760, 640)
$form.BackColor = $FarbeHell
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$form.KeyPreview = $true
$form.TopMost = $true
if ($Symbol -and (Test-Path -LiteralPath $Symbol)) { try { $form.Icon = New-Object System.Drawing.Icon($Symbol) } catch { } }

$kopf = New-Object System.Windows.Forms.Panel
$kopf.SetBounds(0, 0, 760, 62)
$kopf.BackColor = $FarbeDunkel
$form.Controls.Add($kopf)
$titel = New-Object System.Windows.Forms.Label
$titel.Text = 'Logo Ihrer Schule zuschneiden'
$titel.ForeColor = [System.Drawing.Color]::White
$titel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
$titel.SetBounds(20, 8, 700, 28)
$kopf.Controls.Add($titel)
$unter = New-Object System.Windows.Forms.Label
$unter.Text = 'Der blaue Rahmen ist genau 472 × 115 Pixel groß. Passen Sie das Bild darin an – freie Flächen werden weiß.'
$unter.ForeColor = [System.Drawing.Color]::FromArgb(220, 228, 235)
$unter.SetBounds(20, 36, 700, 20)
$kopf.Controls.Add($unter)

$leinwand = New-Object System.Windows.Forms.PictureBox
$leinwand.SetBounds(20, 76, $LeinwandB, $LeinwandH)
$leinwand.BackColor = [System.Drawing.Color]::FromArgb(47, 54, 61)
$leinwand.Cursor = [System.Windows.Forms.Cursors]::SizeAll
$form.Controls.Add($leinwand)

$hinweis = New-Object System.Windows.Forms.Label
$hinweis.Text = 'Zoomen: Regler oder Mausrad   ·   Verschieben: Bild mit gedrückter linker Maustaste ziehen'
$hinweis.ForeColor = $FarbeDunkel
$hinweis.SetBounds(20, 422, 720, 20)
$form.Controls.Add($hinweis)

$lblZoom = New-Object System.Windows.Forms.Label
$lblZoom.Text = 'Zoom'
$lblZoom.SetBounds(20, 450, 50, 24)
$form.Controls.Add($lblZoom)
$regler = New-Object System.Windows.Forms.TrackBar
$regler.SetBounds(70, 444, 670, 40)
$regler.Minimum = 0
$regler.Maximum = 1000
$regler.TickStyle = 'None'
$form.Controls.Add($regler)

$lblVor = New-Object System.Windows.Forms.Label
$lblVor.Text = 'Vorschau Logo.jpg (472 × 115):'
$lblVor.SetBounds(20, 490, 300, 20)
$form.Controls.Add($lblVor)
$vorschauFeld = New-Object System.Windows.Forms.PictureBox
$vorschauFeld.SetBounds(20, 512, $ZielBreite, $ZielHoehe)
$vorschauFeld.BackColor = [System.Drawing.Color]::White
$vorschauFeld.BorderStyle = 'FixedSingle'
$form.Controls.Add($vorschauFeld)

$warnung = New-Object System.Windows.Forms.Label
$warnung.ForeColor = [System.Drawing.Color]::FromArgb(122, 79, 0)
$warnung.SetBounds(505, 490, 240, 60)
$form.Controls.Add($warnung)

$btnAnders = New-Object System.Windows.Forms.Button
$btnAnders.Text = 'Anderes Bild …'
$btnAnders.SetBounds(505, 556, 235, 30)
$form.Controls.Add($btnAnders)
$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text = 'Übernehmen'
$btnOk.SetBounds(505, 594, 115, 32)
$btnOk.BackColor = $FarbeBlau
$btnOk.ForeColor = [System.Drawing.Color]::White
$btnOk.FlatStyle = 'Flat'
$form.Controls.Add($btnOk)
$btnAbbruch = New-Object System.Windows.Forms.Button
$btnAbbruch.Text = 'Abbrechen'
$btnAbbruch.SetBounds(625, 594, 115, 32)
$form.Controls.Add($btnAbbruch)
$form.AcceptButton = $btnOk
$form.CancelButton = $btnAbbruch

$script:VorschauBild = $null
function Aktualisiere {
    $leinwand.Invalidate()
    if ($script:VorschauBild) { $script:VorschauBild.Dispose() }
    $script:VorschauBild = Erzeuge-Ausschnitt
    $vorschauFeld.Image = $script:VorschauBild
}

function Uebernehme-Bild {
    param([string]$Pfad)
    try {
        $geladen = Lade-Bild -Pfad $Pfad
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show('Das Bild konnte nicht geöffnet werden:' + [Environment]::NewLine + $_.Exception.Message, 'Logo', 'OK', 'Warning')
        return $false
    }
    if ($script:Bild) { $script:Bild.Dispose() }
    $script:Bild = $geladen
    # kleinster Zoom: ganzes Bild passt in den Rahmen; groesster: deutlich ueber "Rahmen gefuellt"
    $passend = [Math]::Min($ZielBreite / $script:Bild.Width, $ZielHoehe / $script:Bild.Height)
    $fuellend = [Math]::Max($ZielBreite / $script:Bild.Width, $ZielHoehe / $script:Bild.Height)
    $script:MinZoom = $passend
    $script:MaxZoom = [Math]::Max([Math]::Max($fuellend * 4, $passend * 10), 1.0)
    $script:Zoom = $script:MinZoom
    $script:OffX = $RahmenX + ($ZielBreite - $script:Bild.Width * $script:Zoom) / 2
    $script:OffY = $RahmenY + ($ZielHoehe - $script:Bild.Height * $script:Zoom) / 2
    Begrenze
    $script:ReglerIntern = $true
    $regler.Value = 0
    $script:ReglerIntern = $false
    $warnung.Text = ('Bild: ' + $script:Bild.Width + ' × ' + $script:Bild.Height + ' Pixel')
    if ($script:Bild.Width -lt $ZielBreite -or $script:Bild.Height -lt $ZielHoehe) {
        $warnung.Text += [Environment]::NewLine + 'Kleiner als 472 × 115 – wird vergrößert und kann unscharf wirken.'
    }
    Aktualisiere
    return $true
}

$leinwand.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    if (-not $script:Bild) { return }
    $g.FillRectangle([System.Drawing.Brushes]::White, $RahmenX, $RahmenY, $ZielBreite, $ZielHoehe)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $ziel = New-Object System.Drawing.RectangleF(([single]$script:OffX), ([single]$script:OffY), ([single]($script:Bild.Width * $script:Zoom)), ([single]($script:Bild.Height * $script:Zoom)))
    $g.DrawImage($script:Bild, $ziel)
    # Ausserhalb des Rahmens abdunkeln
    $schatten = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 20, 24, 28))
    $g.FillRectangle($schatten, 0, 0, $LeinwandB, $RahmenY)
    $g.FillRectangle($schatten, 0, $RahmenY + $ZielHoehe, $LeinwandB, $LeinwandH - $RahmenY - $ZielHoehe)
    $g.FillRectangle($schatten, 0, $RahmenY, $RahmenX, $ZielHoehe)
    $g.FillRectangle($schatten, $RahmenX + $ZielBreite, $RahmenY, $LeinwandB - $RahmenX - $ZielBreite, $ZielHoehe)
    $schatten.Dispose()
    $stift = New-Object System.Drawing.Pen($FarbeBlau, 2)
    $g.DrawRectangle($stift, $RahmenX - 1, $RahmenY - 1, $ZielBreite + 1, $ZielHoehe + 1)
    $stift.Dispose()
    $schrift = New-Object System.Drawing.Font('Segoe UI', 9)
    $g.DrawString('472 × 115 px', $schrift, [System.Drawing.Brushes]::White, [single]$RahmenX, [single]($RahmenY + $ZielHoehe + 6))
    $schrift.Dispose()
})

$leinwand.Add_MouseDown({ param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $script:Ziehen = $true; $script:Start = $e.Location }
})
$leinwand.Add_MouseUp({ param($s, $e) $script:Ziehen = $false; Aktualisiere })
$leinwand.Add_MouseMove({ param($s, $e)
    if (-not $script:Ziehen -or -not $script:Bild) { return }
    $script:OffX += $e.X - $script:Start.X
    $script:OffY += $e.Y - $script:Start.Y
    $script:Start = $e.Location
    Begrenze
    $leinwand.Invalidate()
})
# Mausrad und Regler: Das Rad wirkt auf den Regler, der immer den Fokus hat
$regler.SmallChange = 25
$regler.LargeChange = 100
$regler.Add_ValueChanged({
    if (-not $script:Bild -or $script:ReglerIntern) { return }
    Setze-Zoom -Neu (Regler-Zu-Zoom $regler.Value) -UmX ($RahmenX + $ZielBreite / 2) -UmY ($RahmenY + $ZielHoehe / 2)
    Aktualisiere
})
$leinwand.Add_MouseEnter({ $form.ActiveControl = $regler })
$form.Add_Shown({ $form.ActiveControl = $regler })

$btnAnders.Add_Click({
    $p = Waehle-Datei
    if ($p) { [void](Uebernehme-Bild -Pfad $p) }
})
$btnAbbruch.Add_Click({ $script:Ergebnis = 3; $form.Close() })
$btnOk.Add_Click({
    if (-not $script:Bild) { return }
    try {
        $aus = Erzeuge-Ausschnitt
        $ordner = Split-Path -Parent $Ausgabe
        if ($ordner -and -not (Test-Path -LiteralPath $ordner)) { New-Item -ItemType Directory -Path $ordner -Force | Out-Null }
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
        $kodierung = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $kodierung.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]95)
        $aus.Save($Ausgabe, $codec, $kodierung)
        if ($Vorschau) { $aus.Save($Vorschau, [System.Drawing.Imaging.ImageFormat]::Bmp) }
        $aus.Dispose()
        $script:Ergebnis = 0
        $form.Close()
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show('Das Logo konnte nicht gespeichert werden:' + [Environment]::NewLine + $_.Exception.Message, 'Logo', 'OK', 'Error')
    }
})

# ---------- Start ----------
try {
    $erste = Waehle-Datei
    if (-not $erste) { exit 3 }
    if (-not (Uebernehme-Bild -Pfad $erste)) { exit 3 }
    [void]$form.ShowDialog()
    exit $script:Ergebnis
} catch {
    Merke-Fehler ($_.Exception.Message + [Environment]::NewLine + $_.InvocationInfo.PositionMessage)
    exit 2
}
