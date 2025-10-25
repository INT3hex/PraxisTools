param (
    [string]$baseKonnektorUrl,
    [string]$user,
    [string]$pass
)

# Url to TI-Konnektor (nur mit Secunet getestet!)
#$baseKonnektorUrl = ""
if ([string]::IsNullOrWhiteSpace($baseKonnektorUrl)) {
    $baseKonnektorUrl = Read-Host "Bitte Konnektor-URL in der Form   https://<IP-Adresse>:8500   eingeben"
}

# Login
$uriLogin = $baseKonnektorUrl+"/rest/mgmt/ak/konten/login"
# Karten
$uriKarten = $baseKonnektorUrl+"/rest/mgmt/ak/dienste/karten"
# ClientSysteme
$uriClientSysteme = $baseKonnektorUrl+"/rest/mgmt/ak/info/clientsysteme"

# Ignorieren von Zertifikatsprüfungen (da idR Private Certificate vom Konnektor)
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# 
if ($user -and $pass) {
    $password = ConvertTo-SecureString $pass -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($user, $password)
} else {
    # Credentials sicher über UI abfragen
    Write-Host "Credentials nicht angegeben -> abfragen..."
    $creds = $Host.UI.PromptForCredential("QueryKonnektor", "Benutzer und Kennwort für Konnektorzugriff.", "", "")
}

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

# Zeit umwandeln
function convertTime($millis) {
    return [System.DateTimeOffset]::FromUnixTimeMilliseconds($millis).DateTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Zertifikat analysieren
function Get-CertificateInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Base64Cert
    )

    # Zertifikat laden
    $certBytes = [Convert]::FromBase64String($Base64Cert)
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)

    # Parameter-OID extrahieren
    $rawParams = $certificate.PublicKey.EncodedParameters.RawData
    $hex = ($rawParams | ForEach-Object { $_.ToString("X2") }) -join " "

    # Kurven-/Algorithmusbezeichnung ermitteln
    $curveName = switch ($hex) {
        "06 08 2A 86 48 CE 3D 03 01 07" { "NIST secp256r1" }
        "06 05 2B 81 04 00 22"         { "NIST secp384r1" }
        "06 05 2B 81 04 00 23"         { "NIST secp521r1" }
        "06 09 2B 24 03 03 02 08 01 01 07" { "BrainpoolP256r1" }
        "06 09 2B 24 03 03 02 08 01 01 0B" { "BrainpoolP384r1" }
        "06 09 2B 24 03 03 02 08 01 01 0D" { "BrainpoolP512r1" }
        "05 00"                         { "NULL (RSA)" }           # RFC 5280
        "06 07 2A 86 48 CE 38 04 01"    { "DSA" }
        "06 07 2A 86 48 CE 38 04 03"    { "Diffie-Hellman" }
        default                        { "Unbekannt" }
    }

    # Objekt mit Zertifikatsinformationen zurückgeben - erstmal nur das nötigste
    return [PSCustomObject]@{
        #Subject             = $certificate.Subject
        #Issuer              = $certificate.Issuer
        #ValidFrom           = $certificate.NotBefore
        #ValidUntil          = $certificate.NotAfter        
        #PublicKeyAlgorithm  = $certificate.PublicKey.Oid.FriendlyName
        #AlgorithmOid        = $certificate.PublicKey.Oid.Value
        #ParameterOidHex     = $hex
        Curve                = $curveName
        Thumbprint           = $certificate.Thumbprint
    }
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

            # Konnektor-Query Karten
            $response = Invoke-WebRequest -Uri $uriKarten `
                                           -Headers $headers `
                                           -UseBasicParsing
            $data = $response.Content | ConvertFrom-Json 

            #
            $headers["Authorization"] = $bearerToken
            $headers["Referer"] = $baseKonnektorUrl+"/management/home/praxis/clientsysteme"
            $headers.Remove("Origin")
            $headers.Remove("X-No-Session-Refresh")
            $body = @{}

            # Konnektor-Query ClientSysteme
            $response = Invoke-WebRequest -Uri $uriClientSysteme `
                                           -Headers $headers `
                                           -UseBasicParsing
            $data2 = $response.Content | ConvertFrom-Json 

        
            # $data JSON ergänzen
            foreach ($item in $data) {
                # UnixTimestamps konvertieren
                if ($item.insertTime) {
                    $item.insertTime = convertTime $item.insertTime
                }
                if ($item.expirationDate) {
                    $item.expirationDate = convertTime $item.expirationDate
                }
                if ($item.eccCert) {
                $item.eccCert = Get-CertificateInfo -Base64Cert $item.eccCert
                }
                if ($item.rsaCert) {
                $item.rsaCert = Get-CertificateInfo -Base64Cert $item.rsaCert
                }
            }

            # $data2 JSON entpacken
            $flattened = foreach ($entry in $data2) {
                foreach ($cert in $entry.certificates) {
                    [PSCustomObject]@{
                    internalId       = $entry.internalId
                    clientSystemId   = $entry.clientSystemId
                    certInternalId   = $cert.internalId
                    #keystore         = $cert.keystore
                    #certificate      = $cert.certificate
                    filename         = $cert.filename
                    validity         = $cert.validity.valid
                    expirationDate   = convertTime $cert.validity.notAfter
                    cryptType        = $cert.cryptType
                    eccCurve         = $cert.eccCurve
                    }
                }
            }

        # Übersicht ausgeben
        #$data | Out-GridView
        # filtern - mit analysiertem Cert, ohne: eccCertState, rsaCertState
        $data | Select-Object cardHandle, cardTerminalHostname, cardTerminalID, cardTerminalMacAddress, slotNo, type, insertTime, commonName, iccsn, telematikID, nkCard, authCard, hasECCCert, hasRSACert, eccCert, rsaCert, version, expirationDate | Out-GridView -Title "Zertifikate"
        
        $flattened | Out-GridView -Title "Definierte Clientsysteme"

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
    Write-Host "Fehler beim Login/Datenabruf: $($_.Exception.Message)" -ForegroundColor Red
    return
}


