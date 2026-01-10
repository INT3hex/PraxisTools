# Fingerprint des Konnektors/LDAP-Proxy ermitteln...
# Es wird ein Clientzertifikat für die Authentisierung benötigt!
function Get-LdapFingerprint {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Konnektor,

        [Parameter(Mandatory = $true)]
        [string]$CertPath,

        [Parameter(Mandatory = $true)]
        [string]$CertPassword
    )

    # Zertifikatsprüfung ignorieren (optional)
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    # Client-Zertifikat laden
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $cert.Import($CertPath, $CertPassword, "DefaultKeySet")
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $certCollection.Add($cert)

    # TCP-Verbindung
    $tcp = New-Object Net.Sockets.TcpClient($Konnektor, 636)    # LDAPS Port
    $ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, ({ $true }))

    Write-Host "Verbinde mit Konnektor..."
    # TLS-Handshake mit Client-Zertifikat
    $ssl.AuthenticateAsClient(
        $Konnektor,
        $certCollection,
        [System.Security.Authentication.SslProtocols]::Tls12,
        $false
    )

    # Serverzertifikat auslesen
    $serverCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)

    # SHA256-Fingerprint
    $fingerprint = [System.BitConverter]::ToString($serverCert.GetCertHash("SHA256")).Replace("-", "")

    Write-Host "LDAP Fingerprint: $fingerprint"
}

Get-LdapFingerprint `
    -Konnektor (Read-Host "Bitte IP oder Hostname des Konnektors (LDAP-Proxy) eingeben") `
    -CertPath (Read-Host "Bitte Pfad zu Clientzertifikat eingeben") `
    -CertPassword (Read-Host "Bitte Passwort zu Clientzertifikat eingeben")

