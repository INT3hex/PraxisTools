# Url to TI-Konnektor (nur mit Secunet getestet!)
$baseKonnektorUrl = "https://10.1.1.30:8500"


# Login
$uriLogin = $baseKonnektorUrl+"/rest/mgmt/ak/konten/login"
# Karten
$uriKarten = $baseKonnektorUrl+"/rest/mgmt/ak/dienste/karten"

# Credentials sicher abfragen
$creds = $Host.UI.PromptForCredential("QueryKonnektor", "Benutzer und Kennwort für Konnektorzugriff.", "", "")

$body = @{
    username = $creds.UserName
    password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($creds.Password))
} | ConvertTo-Json -Compress


# HTTP-Header für Login
$headers = @{
    "Accept"                = "application/json, text/plain, */*"
    "Origin"                = $baseKonnektorUrl
    "Referer"               = $baseKonnektorUrl+"/management/login"
    "Sec-Fetch-Dest"        = "empty"
    "Sec-Fetch-Mode"        = "cors"
    "Sec-Fetch-Site"        = "same-origin"
    "X-No-Session-Refresh"  = "true"
}

function convertTime($millis) {
    return [System.DateTimeOffset]::FromUnixTimeMilliseconds($millis).DateTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Query
Write-Host "Verbinde zum Konnektor via $baseKonnektorUrl"
try {
    # Konnektor-Login
    $responseLogin = Invoke-WebRequest -Uri $uriLogin `
                                       -Method POST `
                                       -Headers $headers `
                                       -ContentType "application/json" `
                                       -Body $body `
                                       -UseBasicParsing

    if ($responseLogin.StatusCode -eq 200 -or $responseLogin.StatusCode -eq 204) {
        Write-Host "Konnektor-Login erfolgreich" -ForegroundColor Green
        Write-Host "HTTP-Statuscode: $($responseLogin.StatusCode)"


        if ($responseLogin.Headers["Authorization"]) {
            Write-Host "Bearer-Token vorhanden"
            $bearerToken = $responseLogin.Headers["Authorization"]
            
            #
            $headers["Authorization"] = $bearerToken
            $headers["Referer"] = $baseKonnektorUrl+"/management/home/praxis/karten"
            $headers.Remove("Origin")
            $headers.Remove("X-No-Session-Refresh")
            $body = @{}

        # Konnektor-Query
        $response = Invoke-WebRequest -Uri $uriKarten `
                                       -Headers $headers `
                                       -UseBasicParsing
        $data = $response.Content | ConvertFrom-Json 
        
        # UnixTimestamps konvertieren
        foreach ($item in $data) {
            if ($item.insertTime) {
                $item.insertTime = Convert-UnixMillisToDateTime $item.insertTime
            }
            if ($item.expirationDate) {
                $item.expirationDate = Convert-UnixMillisToDateTime $item.expirationDate
            }
        }

        # Übersicht ausgeben
        $data | Out-GridView

        # finito

        } else {
            Write-Host "Kein Bearer-Token vorhanden" -ForegroundColor Red
        }

    }
    else {
        Write-Host "Konnektor-Login fehlgeschlagen mit Statuscode: $($responseLogin.StatusCode)" -ForegroundColor Red
        return
    }
}
catch {
    Write-Host "Fehler beim Login: $($_.Exception.Message)" -ForegroundColor Red
    return
}


