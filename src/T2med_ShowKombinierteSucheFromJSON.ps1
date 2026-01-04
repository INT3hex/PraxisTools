# Analyse von exportierten komb. Suchen
param(
    [string]$jsonPath
)

if (-not $jsonPath -or $jsonPath.Trim() -eq "") {
    $jsonPath = Read-Host "Bitte JSON-Datei mit kombinierten Suchen angeben"
}

$json = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host ""
Write-Host "==================================================="
Write-Host "Kurzübersicht aller enthaltenen kombinierten Suchen"
Write-Host "==================================================="

foreach ($k in $json.inhalt) {
    $line = "$($k.bezeichnung), $($k.objectId), Revision $($k.revision)"
    Write-Host $line
}