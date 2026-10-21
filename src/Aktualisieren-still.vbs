' Startet die Aktualisierung unsichtbar (fuer die Aufgabenplanung).
' Teil von "PLG PYTHA-Schulmaterial" - Lizenz: MIT
Option Explicit
Dim fso, ordner, befehl
Set fso = CreateObject("Scripting.FileSystemObject")
ordner = fso.GetParentFolderName(WScript.ScriptFullName)
befehl = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ordner & "\Schulmaterial-Update.ps1"" -Leise"
CreateObject("WScript.Shell").Run befehl, 0, False
