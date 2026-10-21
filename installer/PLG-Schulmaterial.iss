; ==============================================================
;   PLG PYTHA-Schulmaterial - Installer (Inno Setup 6)
;   Lizenz: MIT (siehe LICENSE)
;
;   Ablauf: Doppelklick -> kleines Fenster "Mit oder ohne Adminrechte?"
;     Mit  -> Windows fragt nach Adminrechten, volle Installation
;     Ohne -> Installation ohne Adminrechte (nur Material + Verknuepfung)
; ==============================================================

#define AppName      "PLG PYTHA-Schulmaterial"
#ifndef AppVersion
  #define AppVersion "3.0.0"
#endif
#define AppPublisher "Professionelle Lerngruppe PYTHA"
#define AppUrl       "https://github.com/wethlo/plg-pytha-schulmaterial"

[Setup]
AppId={{A68A3C20-16F6-4FB8-B32A-07AEFEC1131B}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
AppUpdatesURL={#AppUrl}/releases
AppCopyright=© 2023–2026 {#AppPublisher}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} – Installation
VersionInfoProductName={#AppName}
VersionInfoVersion={#AppVersion}
DefaultDirName={code:StandardOrdner}\{#AppName}
DisableWelcomePage=no
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
UsePreviousAppDir=yes
; 64-Bit-Modus: sonst landen Programm, cmd/PowerShell und Registry
; (HKLM\SOFTWARE -> WOW6432Node) in der 32-Bit-Welt, die PYTHA nicht sieht
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
OutputDir=..\ausgabe
OutputBaseFilename=PLG-PYTHA-Schulmaterial-Setup
SetupIconFile=..\assets\PLG.ico
UninstallDisplayIcon={app}\PLG.ico
UninstallDisplayName={#AppName}
WizardStyle=modern
WizardImageFile=..\assets\wizard-gross.bmp,..\assets\wizard-gross-200.bmp
WizardSmallImageFile=..\assets\wizard-klein.bmp,..\assets\wizard-klein-200.bmp
WizardImageStretch=no
InfoBeforeFile=..\texte\ueber-das-projekt.txt
ShowLanguageDialog=no
Compression=lzma2
SolidCompression=yes
CloseApplications=no
RestartIfNeededByRun=no

[Languages]
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[Messages]
de.PrivilegesRequiredOverrideTitle=PLG PYTHA-Schulmaterial
de.PrivilegesRequiredOverrideInstruction=Mit oder ohne Adminrechte installieren?
de.PrivilegesRequiredOverrideText1=Mit Adminrechten wird alles eingerichtet: Schulmaterial, PYTHA 26, Schuleinstellungen und tägliche Aktualisierung. Ohne Adminrechte nur das Schulmaterial und die Desktop-Verknüpfung.
de.PrivilegesRequiredOverrideAllUsersRecommended=&Mit Adminrechten (empfohlen)
de.PrivilegesRequiredOverrideCurrentUser=&Ohne Adminrechte (z. B. im Schulnetz)
de.WelcomeLabel1=Willkommen beim PYTHA-Schulmaterial
de.WelcomeLabel2=Die PYTHA-Schulbibliothek der Professionellen Lerngruppe – entwickelt von Clemens Kastner, Theo Weber, Ralf Sigmund und Ralf Huber.%n%nDieses Programm lädt das Schulmaterial aus einer Cloud auf diesen PC (ca. 400 MB, Internetverbindung nötig) und hält es auf Wunsch aktuell.
de.InfoBeforeLabel=Bitte lesen Sie die folgenden Informationen zum Projekt.
de.InfoBeforeClickLabel=Klicken Sie auf „Weiter“, um fortzufahren.
de.WizardInfoBefore=Über das Projekt
de.ReadyLabel1=Das Programm ist bereit. Bitte prüfen Sie Ihre Auswahl.
de.FinishedHeadingLabel=Fertig
de.ClickFinish=Klicken Sie auf „Fertigstellen“, um den Assistenten zu schließen.

[Files]
Source: "..\src\Schulmaterial-Update.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\Logo-Zuschnitt.ps1";      DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\Aktualisieren.cmd";       DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\Aktualisieren-still.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\PLG.ico";              DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE";                     DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion
; nur waehrend des Assistenten gebraucht (Logo zuschneiden)
Source: "..\src\Logo-Zuschnitt.ps1"; Flags: dontcopy
Source: "..\assets\PLG.ico";         Flags: dontcopy

[Icons]
Name: "{autodesktop}\PYTHA-Schulmaterial aktualisieren"; Filename: "{app}\Aktualisieren.cmd"; Parameters: "-Manuell"; WorkingDir: "{app}"; IconFilename: "{app}\PLG.ico"; Comment: "Holt neues PYTHA-Schulmaterial aus der Cloud"; Check: MitVerknuepfung
Name: "{autoprograms}\{#AppName}\PYTHA-Schulmaterial aktualisieren"; Filename: "{app}\Aktualisieren.cmd"; Parameters: "-Manuell"; WorkingDir: "{app}"; IconFilename: "{app}\PLG.ico"
Name: "{autoprograms}\{#AppName}\Schulmaterial-Ordner"; Filename: "{code:SchulOrdner}"
Name: "{autoprograms}\{#AppName}\{#AppName} entfernen"; Filename: "{uninstallexe}"; IconFilename: "{app}\PLG.ico"

[Run]
Filename: "{code:SchulOrdner}"; Description: "Schulmaterial-Ordner öffnen"; Flags: postinstall shellexec skipifsilent nowait unchecked

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\Schulmaterial-Update.ps1"" -Entfernen -EntferneRegistry"; Flags: runhidden waituntilterminated; RunOnceId: "Entfernen"

[UninstallDelete]
Type: files; Name: "{app}\einstellungen.ini"

[Code]
const
  SCHUL_KURZ = 'RV,OF,RZ,SHA,EM,ANDERE';
  LOGO_REL   = '13_Material\Logos\Logo.jpg';

var
  WartungSeite, SchulSeite, KompSeite, TransferSeite: TInputOptionWizardPage;
  LogoSeite, ZeitSeite: TWizardPage;
  LogoKnopf: TNewButton;
  LogoText: TNewStaticText;
  LogoBild: TBitmapImage;
  ZeitEdit: TNewEdit;
  AnmeldungBox: TNewCheckBox;
  VorherDa, OhneRueckfrage: Boolean;
  VorherSchule, VorherGeschuetzt: String;
  NeuesLogo: Boolean;

{ ---------- Hilfen ---------- }

function StandardOrdner(Param: String): String;
begin
  // wie autopf: mit Adminrechten "Programme", sonst %LOCALAPPDATA%\Programs
  if IsAdminInstallMode then
    Result := ExpandConstant('{commonpf}')
  else
    Result := ExpandConstant('{localappdata}') + '\Programs';
end;

function SchulOrdner(Param: String): String;
begin
  Result := GetEnv('PUBLIC') + '\PYTHA\Schulmaterial';
end;

function LogoZiel: String;
begin
  Result := SchulOrdner('') + '\' + LOGO_REL;
end;

function EinstellDatei: String;
begin
  Result := AddBackslash(WizardDirValue) + 'einstellungen.ini';
end;

function GewaehlteSchule: String;
var
  i, n: Integer;
  rest: String;
begin
  Result := 'ANDERE';
  rest := SCHUL_KURZ + ',';
  for i := 0 to 5 do
  begin
    n := Pos(',', rest);
    if SchulSeite.Values[i] then
    begin
      Result := Copy(rest, 1, n - 1);
      Exit;
    end;
    Delete(rest, 1, n);
  end;
end;

function SchulIndex(Kurz: String): Integer;
var
  i, n: Integer;
  rest: String;
begin
  Result := -1;
  rest := SCHUL_KURZ + ',';
  for i := 0 to 5 do
  begin
    n := Pos(',', rest);
    if CompareText(Copy(rest, 1, n - 1), Kurz) = 0 then
    begin
      Result := i;
      Exit;
    end;
    Delete(rest, 1, n);
  end;
end;

function Wartung: Integer;   { -1 = Erstinstallation, 0 aktualisieren, 1 aendern, 2 Logo, 3 entfernen }
begin
  Result := -1;
  if VorherDa then Result := WartungSeite.SelectedValueIndex;
end;

function MitVerknuepfung: Boolean;
begin
  Result := KompSeite.Values[4];
end;

function GueltigeZeit(T: String): Boolean;
var
  h, m: Integer;
begin
  Result := False;
  if (Length(T) <> 5) or (T[3] <> ':') then Exit;
  h := StrToIntDef(Copy(T, 1, 2), -1);
  m := StrToIntDef(Copy(T, 4, 2), -1);
  Result := (h >= 0) and (h <= 23) and (m >= 0) and (m <= 59);
end;

function PowerShell: String;
begin
  Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  if not FileExists(Result) then Result := 'powershell.exe';
end;

{ ---------- Start: Adminrechte erbitten, bei "Nein" ohne weiter ---------- }

function InitializeSetup: Boolean;
begin
  { Mit/ohne Adminrechte waehlt der Benutzer im Dialog von Inno Setup
    (PrivilegesRequiredOverridesAllowed=dialog). Ein Selbst-Neustart aus
    dem Skript ist in Inno Setup gesperrt. }
  Result := True;
  OhneRueckfrage := False;
  if IsAdminInstallMode then
    Log('Installation mit Adminrechten.')
  else
    Log('Installation ohne Adminrechte.');
end;

{ ---------- Seiten anlegen ---------- }

procedure LogoKnopfClick(Sender: TObject);
var
  Code: Integer;
  Skript, Aus, Vor, Ico, Meldung: String;
  Roh: AnsiString;
begin
  ExtractTemporaryFile('Logo-Zuschnitt.ps1');
  ExtractTemporaryFile('PLG.ico');
  Skript := ExpandConstant('{tmp}\Logo-Zuschnitt.ps1');
  Aus := ExpandConstant('{tmp}\Logo.jpg');
  Vor := ExpandConstant('{tmp}\Logo-Vorschau.bmp');
  Ico := ExpandConstant('{tmp}\PLG.ico');
  LogoKnopf.Enabled := False;
  try
    DeleteFile(Aus);
    if Exec(PowerShell, '-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + Skript + '" -Ausgabe "' + Aus + '" -Vorschau "' + Vor + '" -Symbol "' + Ico + '"',
            '', SW_SHOWNORMAL, ewWaitUntilTerminated, Code) then
    begin
      Log('Logo-Zuschnitt beendet mit Code ' + IntToStr(Code));
      if (Code = 0) and FileExists(Aus) then
      begin
        NeuesLogo := True;
        if FileExists(Vor) then LogoBild.Bitmap.LoadFromFile(Vor);
        LogoText.Caption := 'Das Logo ist zugeschnitten (472 × 115 Pixel) und wird als Logo.jpg gespeichert. Mit dem Knopf können Sie es erneut auswählen.';
      end
      else if Code <> 3 then
      begin
        Meldung := '';
        if LoadStringFromFile(Aus + '.fehler.txt', Roh) then Meldung := String(Roh);
        if Meldung = '' then
          Meldung := 'PowerShell wurde mit Code ' + IntToStr(Code) + ' beendet, ohne eine Meldung zu hinterlassen. ' +
            'Möglicherweise hat ein Virenscanner oder eine Richtlinie das Skript blockiert.';
        Log('Logo-Zuschnitt Fehler: ' + Meldung);
        MsgBox('Das Logo-Fenster konnte nicht richtig gestartet werden:' + #13#10#13#10 + Meldung, mbError, MB_OK);
      end;
    end else
      MsgBox('Das Zuschneide-Fenster konnte nicht gestartet werden (' + SysErrorMessage(Code) + ').', mbError, MB_OK);
  finally
    LogoKnopf.Enabled := True;
  end;
end;

procedure InitializeWizard;
var
  Hinweis, KompHinweis: String;
  L: TNewStaticText;
  i: Integer;
begin
  if IsAdminInstallMode then
    KompHinweis := 'Bitte wählen Sie, was auf diesem PC eingerichtet werden soll.'
  else
    KompHinweis := 'Ausgegraute Punkte benötigen Adminrechte.';
  { Farben passend zum PLG-Logo: Schiefergrau #414B55, Blau #367EA6 }
  WizardForm.MainPanel.Color := $00554B41;
  WizardForm.PageNameLabel.Font.Color := clWhite;
  WizardForm.PageDescriptionLabel.Font.Color := $00EDEDED;
  WizardForm.WelcomeLabel1.Font.Color := $00554B41;
  WizardForm.FinishedHeadingLabel.Font.Color := $00554B41;

  if IsAdminInstallMode then
    Hinweis := 'Installation MIT Adminrechten: Alle Funktionen sind verfügbar.'
  else
    Hinweis := 'Installation OHNE Adminrechte: Das Schulmaterial und eine Verknüpfung werden eingerichtet. ' +
               'PYTHA-Installation, Schuleinstellungen und tägliche Aktualisierung brauchen Adminrechte und entfallen.';
  WizardForm.WelcomeLabel2.Caption := WizardForm.WelcomeLabel2.Caption + #13#10#13#10 + Hinweis;

  { Vorherige Installation? }
  VorherDa := FileExists(EinstellDatei);
  VorherSchule := GetIniString('Einstellungen', 'Schule', '', EinstellDatei);
  VorherGeschuetzt := GetIniString('Einstellungen', 'Geschuetzt', '', EinstellDatei);

  WartungSeite := CreateInputOptionPage(wpInfoBefore, 'Bereits installiert',
    'Das PYTHA-Schulmaterial ist auf diesem PC schon eingerichtet.',
    'Was möchten Sie tun?', True, False);
  WartungSeite.Add('Aktualisieren bzw. reparieren (Einstellungen bleiben)');
  WartungSeite.Add('Schule oder Einstellungen ändern');
  WartungSeite.Add('Logo ändern (nur „Andere Schule“)');
  WartungSeite.Add('Deinstallieren');
  WartungSeite.SelectedValueIndex := 0;
  if CompareText(VorherSchule, 'ANDERE') <> 0 then WartungSeite.CheckListBox.ItemEnabled[2] := False;

  SchulSeite := CreateInputOptionPage(WartungSeite.ID, 'Schule',
    'An welcher Schule sind Sie?', 'Das Material wird passend zu Ihrer Schule geladen.', True, False);
  SchulSeite.Add('Gewerbliche Schule Ravensburg');
  SchulSeite.Add('Gewerblich-Technische Schule Offenburg');
  SchulSeite.Add('Berufsschulzentrum Radolfzell');
  SchulSeite.Add('Gewerbliche Schule Schwäbisch Hall');
  SchulSeite.Add('Emmendingen');
  SchulSeite.Add('Andere Schule (eigenes Logo hinterlegen)');
  i := SchulIndex(VorherSchule);
  if i < 0 then i := 0;
  SchulSeite.SelectedValueIndex := i;

  LogoSeite := CreateCustomPage(SchulSeite.ID, 'Logo Ihrer Schule',
    'Ihr Logo erscheint in den Schriftfeldern der PYTHA-Vorlagen.');
  L := TNewStaticText.Create(LogoSeite);
  L.Parent := LogoSeite.Surface;
  L.WordWrap := True;
  L.Width := LogoSeite.SurfaceWidth;
  L.Caption := 'Wählen Sie ein Bild Ihres Schullogos (JPG, PNG, BMP, GIF oder TIFF). Anschließend schneiden Sie es auf 472 × 115 Pixel zu. ' +
               'Es wird als Logo.jpg gespeichert und bei späteren Aktualisierungen nicht überschrieben.';
  LogoKnopf := TNewButton.Create(LogoSeite);
  LogoKnopf.Parent := LogoSeite.Surface;
  LogoKnopf.Caption := 'Logo auswählen und zuschneiden …';
  LogoKnopf.Top := L.Top + ScaleY(56);
  LogoKnopf.Width := ScaleX(240);
  LogoKnopf.Height := ScaleY(28);
  LogoKnopf.OnClick := @LogoKnopfClick;
  LogoBild := TBitmapImage.Create(LogoSeite);
  LogoBild.Parent := LogoSeite.Surface;
  LogoBild.Top := LogoKnopf.Top + LogoKnopf.Height + ScaleY(14);
  LogoBild.Width := LogoSeite.SurfaceWidth;
  LogoBild.Height := (LogoSeite.SurfaceWidth * 115) div 472;
  LogoBild.Stretch := True;
  LogoBild.BackColor := $00EDEDED;
  LogoText := TNewStaticText.Create(LogoSeite);
  LogoText.Parent := LogoSeite.Surface;
  LogoText.WordWrap := True;
  LogoText.Width := LogoSeite.SurfaceWidth;
  LogoText.Top := LogoBild.Top + LogoBild.Height + ScaleY(8);
  LogoText.Caption := 'Noch kein Logo ausgewählt – ohne Logo geht es nicht weiter.';
  if FileExists(LogoZiel) and (CompareText(VorherSchule, 'ANDERE') = 0) then
    LogoText.Caption := 'Ihr bisheriges Logo bleibt erhalten. Mit dem Knopf können Sie ein neues wählen.';

  KompSeite := CreateInputOptionPage(LogoSeite.ID, 'Komponenten',
    'Was soll eingerichtet werden?', KompHinweis, False, False);
  KompSeite.Add('Schulmaterial laden (immer)');
  KompSeite.Add('PYTHA 26 installieren, falls noch nicht vorhanden');
  KompSeite.Add('Schuleinstellungen (Transferdatei) eintragen');
  KompSeite.Add('Tägliche Aktualisierung einrichten');
  KompSeite.Add('Verknüpfung auf dem Desktop (mit PLG-Logo)');
  KompSeite.Values[0] := True;
  KompSeite.CheckListBox.ItemEnabled[0] := False;
  for i := 1 to 3 do
  begin
    if IsAdminInstallMode then
      KompSeite.Values[i] := True
    else begin
      KompSeite.Values[i] := False;
      KompSeite.CheckListBox.ItemEnabled[i] := False;
      KompSeite.CheckListBox.ItemCaption[i] := KompSeite.CheckListBox.ItemCaption[i] + '  (benötigt Adminrechte)';
    end;
  end;
  KompSeite.Values[4] := True;
  if VorherDa and IsAdminInstallMode then
  begin
    KompSeite.Values[1] := GetIniString('Einstellungen', 'PythaInstallieren', '1', EinstellDatei) = '1';
    KompSeite.Values[2] := GetIniString('Einstellungen', 'Registry', '1', EinstellDatei) = '1';
    KompSeite.Values[3] := GetIniString('Einstellungen', 'Automatik', '1', EinstellDatei) = '1';
  end;
  if VorherDa then
    KompSeite.Values[4] := GetIniString('Einstellungen', 'Verknuepfung', '1', EinstellDatei) = '1';

  TransferSeite := CreateInputOptionPage(KompSeite.ID, 'Schuleinstellungen',
    'Wann soll PYTHA die Schuleinstellungen (Transferdatei) übernehmen?',
    'Dabei ersetzt PYTHA die Einstellungen auf diesem PC durch die Vorgaben der Schule.', True, False);
  TransferSeite.Add('Bei jedem Start von PYTHA (empfohlen für Schüler- und Raum-PCs)');
  TransferSeite.Add('Einmal täglich beim ersten Start von PYTHA');
  TransferSeite.Add('Nicht übernehmen – eigene Einstellungen behalten');
  case StrToIntDef(GetIniString('Einstellungen', 'TransferWert', '2', EinstellDatei), 2) of
    2: TransferSeite.SelectedValueIndex := 0;
    1: TransferSeite.SelectedValueIndex := 1;
  else
    TransferSeite.SelectedValueIndex := 2;
  end;

  ZeitSeite := CreateCustomPage(TransferSeite.ID, 'Tägliche Aktualisierung',
    'Wann soll der PC neues Material holen? Das läuft unsichtbar im Hintergrund.');
  L := TNewStaticText.Create(ZeitSeite);
  L.Parent := ZeitSeite.Surface;
  L.Caption := 'Uhrzeit (z. B. 13:00):';
  L.Top := ScaleY(4);
  ZeitEdit := TNewEdit.Create(ZeitSeite);
  ZeitEdit.Parent := ZeitSeite.Surface;
  ZeitEdit.Left := ScaleX(110);
  ZeitEdit.Width := ScaleX(60);
  ZeitEdit.MaxLength := 5;
  ZeitEdit.Text := GetIniString('Einstellungen', 'Uhrzeit', '13:00', EinstellDatei);
  AnmeldungBox := TNewCheckBox.Create(ZeitSeite);
  AnmeldungBox.Parent := ZeitSeite.Surface;
  AnmeldungBox.Top := ScaleY(40);
  AnmeldungBox.Width := ZeitSeite.SurfaceWidth;
  AnmeldungBox.Caption := 'Zusätzlich bei jeder Anmeldung (für alle Benutzer dieses PCs)';
  AnmeldungBox.Checked := GetIniString('Einstellungen', 'BeiAnmeldung', '1', EinstellDatei) = '1';
  L := TNewStaticText.Create(ZeitSeite);
  L.Parent := ZeitSeite.Surface;
  L.WordWrap := True;
  L.Width := ZeitSeite.SurfaceWidth;
  L.Top := ScaleY(76);
  L.Caption := 'War der PC zur geplanten Zeit aus, wird die Aktualisierung beim nächsten Start nachgeholt. ' +
               'Ein eigenes Schullogo wird dabei nie überschrieben.';
end;

{ ---------- Welche Seiten zeigen? ---------- }

function ShouldSkipPage(PageID: Integer): Boolean;
var
  w: Integer;
begin
  Result := False;
  w := Wartung;
  if PageID = WartungSeite.ID then
    Result := not VorherDa
  else if PageID = SchulSeite.ID then
    Result := (w = 0) or (w = 2)
  else if PageID = LogoSeite.ID then
    Result := (w = 0) or ((w <> 2) and (GewaehlteSchule <> 'ANDERE'))
  else if PageID = KompSeite.ID then
    Result := (w = 0) or (w = 2)
  else if PageID = TransferSeite.ID then
    Result := (w = 0) or (w = 2) or (not IsAdminInstallMode) or (not KompSeite.Values[2])
  else if PageID = ZeitSeite.ID then
    Result := (w = 0) or (w = 2) or (not IsAdminInstallMode) or (not KompSeite.Values[3])
  else if PageID = wpInfoBefore then
    Result := VorherDa;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Code: Integer;
  Unins: String;
begin
  Result := True;
  if (CurPageID = WartungSeite.ID) and (Wartung = 3) then
  begin
    Unins := AddBackslash(WizardDirValue) + 'unins000.exe';
    if FileExists(Unins) then
      ShellExec('', Unins, '', '', SW_SHOWNORMAL, ewNoWait, Code)
    else
      MsgBox('Bitte über Windows-Einstellungen → Apps deinstallieren.', mbInformation, MB_OK);
    OhneRueckfrage := True;
    WizardForm.Close;
    Result := False;
  end
  else if CurPageID = LogoSeite.ID then
  begin
    if not NeuesLogo and not (FileExists(LogoZiel) and (CompareText(VorherSchule, 'ANDERE') = 0)) then
    begin
      MsgBox('Bitte wählen Sie zuerst ein Logo aus und schneiden Sie es zu.', mbInformation, MB_OK);
      Result := False;
    end;
  end
  else if CurPageID = ZeitSeite.ID then
  begin
    if not GueltigeZeit(Trim(ZeitEdit.Text)) then
    begin
      MsgBox('Bitte die Uhrzeit als Stunde:Minute eingeben, z. B. 13:00.', mbInformation, MB_OK);
      Result := False;
    end;
  end;
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if OhneRueckfrage then Confirm := False;
end;

function TransferWert: String;
begin
  case TransferSeite.SelectedValueIndex of
    0: Result := '2';
    1: Result := '1';
  else
    Result := '0';
  end;
end;

function SchulName: String;
begin
  Result := SchulSeite.CheckListBox.ItemCaption[SchulSeite.SelectedValueIndex];
end;

function JaNein(B: Boolean): String;
begin
  if B then Result := 'ja' else Result := 'nein';
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo,
  MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  S: String;
begin
  S := 'Schule:' + NewLine + Space + SchulName + NewLine + NewLine;
  if GewaehlteSchule = 'ANDERE' then
  begin
    if NeuesLogo then S := S + 'Logo:' + NewLine + Space + 'neues Logo.jpg (472 × 115)' + NewLine + NewLine
    else S := S + 'Logo:' + NewLine + Space + 'bisheriges Logo bleibt' + NewLine + NewLine;
  end;
  S := S + 'Zielordner:' + NewLine + Space + SchulOrdner('') + NewLine + NewLine;
  S := S + 'Einrichten:' + NewLine;
  S := S + Space + 'Schulmaterial laden: ja' + NewLine;
  S := S + Space + 'PYTHA 26 installieren (falls nötig): ' + JaNein(KompSeite.Values[1]) + NewLine;
  S := S + Space + 'Schuleinstellungen: ' + JaNein(KompSeite.Values[2]);
  if KompSeite.Values[2] then S := S + ' (Wert ' + TransferWert + ')';
  S := S + NewLine + Space + 'Tägliche Aktualisierung: ' + JaNein(KompSeite.Values[3]);
  if KompSeite.Values[3] then
  begin
    S := S + ' (' + Trim(ZeitEdit.Text) + ' Uhr';
    if AnmeldungBox.Checked then S := S + ', bei jeder Anmeldung';
    S := S + ')';
  end;
  S := S + NewLine + Space + 'Desktop-Verknüpfung: ' + JaNein(KompSeite.Values[4]) + NewLine;
  if not IsAdminInstallMode then
    S := S + NewLine + 'Hinweis: Ohne Adminrechte entfallen PYTHA-Installation,' + NewLine + Space + 'Schuleinstellungen und tägliche Aktualisierung.' + NewLine;
  S := S + NewLine + 'Beim Installieren öffnet sich ein Fenster, das den Download zeigt.';
  Result := S;
end;

{ ---------- Installation ---------- }

procedure SchreibeEinstellungen;
var
  D, Schule: String;
begin
  D := EinstellDatei;
  Schule := GewaehlteSchule;
  SetIniString('Einstellungen', 'Schule', Schule, D);
  SetIniString('Einstellungen', 'PythaInstallieren', Copy('01', Ord(KompSeite.Values[1]) + 1, 1), D);
  SetIniString('Einstellungen', 'Registry', Copy('01', Ord(KompSeite.Values[2]) + 1, 1), D);
  SetIniString('Einstellungen', 'TransferWert', TransferWert, D);
  SetIniString('Einstellungen', 'Automatik', Copy('01', Ord(KompSeite.Values[3]) + 1, 1), D);
  SetIniString('Einstellungen', 'Uhrzeit', Trim(ZeitEdit.Text), D);
  SetIniString('Einstellungen', 'BeiAnmeldung', Copy('01', Ord(AnmeldungBox.Checked) + 1, 1), D);
  SetIniString('Einstellungen', 'Verknuepfung', Copy('01', Ord(KompSeite.Values[4]) + 1, 1), D);
  if Schule = 'ANDERE' then
    SetIniString('Einstellungen', 'Geschuetzt', '13_Material/Logos/Logo.jpg', D)
  else
    SetIniString('Einstellungen', 'Geschuetzt', '', D);
end;

var
  ErgebnisText: String;

function Wert(Zeilen: TArrayOfString; Schluessel: String): String;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to GetArrayLength(Zeilen) - 1 do
    if Pos(Schluessel + '=', Zeilen[i]) = 1 then
      Result := Copy(Zeilen[i], Length(Schluessel) + 2, 9999);
end;

function Beschreibe(Teil, W: String): String;
begin
  Result := '';
  if W = '' then Exit;
  if W = 'keine-adminrechte' then Result := '• ' + Teil + ': übersprungen – benötigt Adminrechte'
  else if (W = 'ok') or (Copy(W, 1, 3) = 'ok:') then Result := '• ' + Teil + ': eingerichtet'
  else if W = 'vorhanden' then Result := '• ' + Teil + ': bereits installiert'
  else if W = 'installiert' then Result := '• ' + Teil + ': installiert'
  else if W = 'abgebrochen' then Result := '• ' + Teil + ': Installation beendet oder abgebrochen'
  else if W = 'keine-zip' then Result := '• ' + Teil + ': keine Transferdatei gefunden'
  else Result := '• ' + Teil + ': nicht erfolgreich (siehe Protokoll)';
  Result := Result + #13#10;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  Erg: String;
  Zeilen: TArrayOfString;
  M: String;
begin
  if CurStep <> ssPostInstall then Exit;
  if Wartung <> 0 then SchreibeEinstellungen
  else if not FileExists(EinstellDatei) then SchreibeEinstellungen;

  { Eigenes Logo vor dem Download ablegen - es ist geschuetzt und bleibt }
  if NeuesLogo and (GewaehlteSchule = 'ANDERE') then
  begin
    ForceDirectories(ExtractFileDir(LogoZiel));
    if not FileCopy(ExpandConstant('{tmp}\Logo.jpg'), LogoZiel, False) then
      MsgBox('Das Logo konnte nicht nach ' + LogoZiel + ' kopiert werden.', mbError, MB_OK);
  end;

  WizardForm.StatusLabel.Caption := 'Das Schulmaterial wird aus der Cloud geladen – siehe eigenes Fenster …';
  Erg := ExpandConstant('{tmp}\ergebnis.txt');
  DeleteFile(Erg);
  { ueber cmd.exe: aeussere Anfuehrungszeichen werden von /c entfernt }
  Exec(ExpandConstant('{cmd}'), '/c ""' + ExpandConstant('{app}\Aktualisieren.cmd') + '" -Einrichten -ErgebnisDatei "' + Erg + '""',
       ExpandConstant('{app}'), SW_SHOWNORMAL, ewWaitUntilTerminated, Code);

  ErgebnisText := '';
  if LoadStringsFromFile(Erg, Zeilen) then
  begin
    M := Wert(Zeilen, 'Material');
    if M = 'ok' then
      ErgebnisText := '• Schulmaterial: aktuell (' + Wert(Zeilen, 'Neu') + ' neu, ' + Wert(Zeilen, 'Erneuert') + ' erneuert)' + #13#10
    else if M = 'teilweise' then
      ErgebnisText := '• Schulmaterial: ' + Wert(Zeilen, 'Fehler') + ' Datei(en) fehlen noch – später erneut aktualisieren' + #13#10
    else
      ErgebnisText := '• Schulmaterial: NICHT geladen – ' + Wert(Zeilen, 'Meldung') + #13#10;
    ErgebnisText := ErgebnisText + Beschreibe('Schuleinstellungen', Wert(Zeilen, 'Registry'));
    ErgebnisText := ErgebnisText + Beschreibe('Tägliche Aktualisierung', Wert(Zeilen, 'Automatik'));
    ErgebnisText := ErgebnisText + Beschreibe('PYTHA 26', Wert(Zeilen, 'Pytha'));
  end else
    ErgebnisText := '• Das Ergebnis des Downloads ist unbekannt (Fenster vorzeitig geschlossen?).' + #13#10;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
    WizardForm.FinishedLabel.Caption :=
      'Ergebnis:' + #13#10 + ErgebnisText + #13#10 +
      'Aktualisieren können Sie jederzeit über „PYTHA-Schulmaterial aktualisieren“ auf dem Desktop oder im Startmenü.' + #13#10#13#10 +
      'Danke an die Professionelle Lerngruppe für die Schulbibliothek!';
  if CurPageID = wpFinished then
  begin
    WizardForm.FinishedLabel.AdjustHeight;
    WizardForm.RunList.Top := WizardForm.FinishedLabel.Top + WizardForm.FinishedLabel.Height + ScaleY(12);
  end;
end;

{ ---------- Deinstallation: Schulmaterial behalten? ---------- }

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Ordner: String;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  Ordner := GetEnv('PUBLIC') + '\PYTHA\Schulmaterial';
  if not DirExists(Ordner) then Exit;
  if UninstallSilent then Exit;
  if MsgBox('Soll der Ordner mit dem Schulmaterial erhalten bleiben?' + #13#10#13#10 + Ordner + #13#10#13#10 +
            'Ja = behalten (empfohlen), Nein = löschen', mbConfirmation, MB_YESNO or MB_DEFBUTTON1) = IDNO then
    DelTree(Ordner, True, True, True);
end;
