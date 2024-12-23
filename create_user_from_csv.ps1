# Variablen für die Domain und Dateipfade definieren
$domain = "intern.dynamite-medical.de" # Hier die Domain eintragen
$csvDateiPfad = "C:\edv\create_user_from_csv.csv"  # Pfad zur CSV-Datei anpassen
$logDateiPfad = "C:\edv\create_user_from_csv.log" # Pfad zur Protokolldatei anpassen

# Logfunktion zur Protokollierung von Ereignissen
function Schreibe-Log {
    param (
        [string]$Nachricht,
        [string]$Ebene = "INFO"
    )
    $Zeitstempel = Get-Date -Format "dd.MM.yyyy HH:mm:ss" # Deutsches Zeitformat
    "$Zeitstempel [$Ebene] - $Nachricht" | Out-File -FilePath $logDateiPfad -Append -Encoding utf8
}

# Protokollmarkierung für neuen Importlauf
Schreibe-Log "==============================================================================================="
Schreibe-Log "  ____ ____ ____ ____ ___ ____    _  _ ____ ____ ____    ____ ____ ____ _  _    ____ ____ _  _ "
Schreibe-Log "  |    |__/ |___ |__|  |  |___    |  | [__  |___ |__/    |___ |__/ |  | |\/|    |    [__  |  | "
Schreibe-Log "  |___ |  \ |___ |  |  |  |___    |__| ___] |___ |  \    |    |  \ |__| |  |    |___ ___]  \/  "
Schreibe-Log ""
Schreibe-Log "==============================================================================================="

# Überprüfen, ob erforderliches Modul installiert ist
if (-Not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Schreibe-Log "FEHLER: Das Active Directory Modul ist nicht installiert." "FEHLER"
    Exit
}

# Importieren des Active Directory Moduls
try {
    Import-Module ActiveDirectory
    Schreibe-Log "Active Directory Modul erfolgreich geladen."
} catch {
    Schreibe-Log "FEHLER: Konnte Active Directory Modul nicht laden. $_" "FEHLER"
    Exit
}

# Prüfen, ob die CSV-Datei existiert
if (-Not (Test-Path $csvDateiPfad)) {
    Schreibe-Log "CSV-Datei nicht gefunden: $csvDateiPfad" "FEHLER"
    Exit
}

# CSV-Datei einlesen
try {
    $benutzerListe = Import-Csv -Path $csvDateiPfad -Delimiter ";"
    $gesamtBenutzer = ($benutzerListe | Measure-Object).Count
    Schreibe-Log "CSV-Datei erfolgreich geladen. Anzahl der Benutzer: $gesamtBenutzer"

    if ($gesamtBenutzer -eq 0) {
        Schreibe-Log "Keine Benutzer in der CSV-Datei gefunden." "WARNUNG"
        Exit
    }
} catch {
    Schreibe-Log "Konnte CSV-Datei nicht einlesen. $_" "FEHLER"
    Exit
}

# Zähler initialisieren
$gesamtzahl = 0
$ouZaehler = @{}
$fehlerBenutzer = 0

# Benutzererstellungsschleife
foreach ($benutzer in $benutzerListe) {
    try {
        # Benutzerparameter aus CSV auslesen
        $Benutzername = $benutzer.Benutzername
        $Vorname = $benutzer.Vorname
        $Nachname = $benutzer.Nachname
        $Passwort = $benutzer.Passwort
        $OU = $benutzer.OU  # Organisationseinheit

        # OU-Zähler aktualisieren
        if (-Not $ouZaehler.ContainsKey($OU)) {
            $ouZaehler[$OU] = 0
        }

        # Zusätzliche Attribute aus CSV auslesen
        $DisplayName = $benutzer.DisplayName
        $Description = $benutzer.Description
        $Office = $benutzer.PhysicalDeliveryOfficeName
        $Phone = $benutzer.TelephoneNumber
        $Mail = $benutzer.Mail
        $Homepage = $benutzer.WWWHomePage
        $Street = $benutzer.StreetAddress
        $City = $benutzer.L
        $PostalCode = $benutzer.PostalCode
        $Country = $benutzer.CountryCode
        $Title = $benutzer.Title
        $Department = $benutzer.Department
        $Company = $benutzer.Company
        $PasswortGueltigkeit = [int]$benutzer.PasswortGueltigkeit # Anzahl der Tage oder 0 für kein Ablauf
        $KontoAktiv = [bool]::Parse($benutzer.KontoAktiv) # Konto aktiv oder inaktiv

        Schreibe-Log "Starte Erstellung für Benutzer: $Benutzername (Vorname: $Vorname, Nachname: $Nachname, OU: $OU)"

        # Benutzer erstellen
        New-ADUser -SamAccountName $Benutzername `
                   -UserPrincipalName "$Benutzername@$domain" `
                   -GivenName $Vorname `
                   -Surname $Nachname `
                   -Name "$Vorname $Nachname" `
                   -Path $OU `
                   -DisplayName $DisplayName `
                   -Description $Description `
                   -Office $Office `
                   -OfficePhone $Phone `
                   -EmailAddress $Mail `
                   -HomePage $Homepage `
                   -StreetAddress $Street `
                   -City $City `
                   -PostalCode $PostalCode `
                   -Country $Country `
                   -Title $Title `
                   -Department $Department `
                   -Company $Company `
                   -AccountPassword (ConvertTo-SecureString $Passwort -AsPlainText -Force) `
                   -Enabled $KontoAktiv

        # Passwortablaufdatum setzen
        if ($PasswortGueltigkeit -eq 0) {
            Set-ADUser -Identity $Benutzername -PasswordNeverExpires $true
            Schreibe-Log "Passwort läuft nicht ab für Benutzer: $Benutzername"
        } else {
            $PasswortAblauf = (Get-Date).AddDays($PasswortGueltigkeit).ToString("dd.MM.yyyy")
            Set-ADUser -Identity $Benutzername -PasswordNeverExpires $false -AccountExpirationDate $PasswortAblauf
            Schreibe-Log "Passwortablauf gesetzt auf $PasswortAblauf für Benutzer: $Benutzername"
        }

        # Zähler aktualisieren
        $gesamtzahl++
        $ouZaehler[$OU]++

        # Protokollieren, dass der Benutzer erfolgreich erstellt wurde
        Schreibe-Log "Benutzer erfolgreich erstellt: $Benutzername, Vorname: $Vorname, Nachname: $Nachname, OU: $OU"

    } catch {
        Schreibe-Log "Fehler beim Erstellen des Benutzers: $($benutzer.Benutzername). Fehler: $_" "FEHLER"
        $fehlerBenutzer++
    }
}

# Zusammenfassung protokollieren
Schreibe-Log "Benutzerimport abgeschlossen. Insgesamt erstellt: $gesamtzahl von $gesamtBenutzer Benutzer(n). Fehler: $fehlerBenutzer."
foreach ($ou in $ouZaehler.Keys) {
    Schreibe-Log "OU $ou`: $($ouZaehler[$ou]) Benutzer erstellt."
}
