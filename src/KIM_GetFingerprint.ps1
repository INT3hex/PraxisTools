# Fingerprint eines KIM-Clientmoduls ermitteln...
function Get-LdapFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$KIMmodul
    )

$tcp = New-Object Net.Sockets.TcpClient($KIMmodul, 465)  # 465 ist der TLS Port
$ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, ({ $true }))
$ssl.AuthenticateAsClient($KIMmodul)
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
$fingerprint = [System.BitConverter]::ToString($cert.GetCertHash("SHA256")).Replace("-", "") # SHA256-Fingerprint

Write-Host "KIM-Clientmodul-Fingerprint: $fingerprint"
}

Get-LdapFingerprint `
    -KIMmodul (Read-Host "Bitte IP oder Hostname des KIM-Clientmoduls eingeben")

