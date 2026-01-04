# Extrahieren von exportierten komb. Suchen
param(
    [string]$jsonPath
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# JSON-Datei laden
param(
    [string]$jsonPath
)

if (-not $jsonPath -or $jsonPath.Trim() -eq "") {
    $jsonPath = Read-Host "Bitte JSON-Datei mit kombinierten Suchen angeben"
}

$json = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

# -----------------------------
# GUI-Forms erstellen
# -----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kombinierte Suchen Übersicht"
$form.Size = New-Object System.Drawing.Size(900,600)
$form.StartPosition = "CenterScreen"

# Checkboxen erzeugen
$list = New-Object System.Windows.Forms.CheckedListBox
$list.Location = New-Object System.Drawing.Point(10,10)
$list.Size = New-Object System.Drawing.Size(860,480)
$list.CheckOnClick = $true

# Einträge hinzufügen
foreach ($k in $json.inhalt) {
    $display = "$($k.bezeichnung)  |  $($k.objectId)  |  Revision $($k.revision)"
    $list.Items.Add($display) | Out-Null
}

$form.Controls.Add($list)

# Button
$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "Auswahl exportieren"
$btnExport.Location = New-Object System.Drawing.Point(10,500)
$btnExport.Size = New-Object System.Drawing.Size(200,40)

$form.Controls.Add($btnExport)


# Export
$btnExport.Add_Click({

    $selected = New-Object System.Collections.ArrayList

    for ($i = 0; $i -lt $list.Items.Count; $i++) {
        if ($list.GetItemChecked($i)) {
            $selected.Add($json.inhalt[$i]) | Out-Null
        }
    }

    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Keine Einträge ausgewählt.")
        return
    }

    $exportObj = [PSCustomObject]@{
        version = $json.version
        inhalt  = $selected
    }

    $jsonText = $exportObj | ConvertTo-Json -Depth 20 -Compress
   
    $exportPath = "Export.json"
    #Set-Content -Path $exportPath -Value $jsonText -Encoding utf8
    $utf8 = New-Object System.Text.UTF8Encoding($false) 
    [System.IO.File]::WriteAllText($exportPath, $jsonText, $utf8)

    # nochmals kurz testen... 
    $jsonText = Get-Content $exportPath -Raw
    $jsonText | ConvertFrom-Json | Out-Null
    Write-Host "JSON ist gültig."


    [System.Windows.Forms.MessageBox]::Show("Exportiert nach $exportPath")
})







# Starte GUI
$form.Add_Shown({ $form.Activate() })
[System.Windows.Forms.Application]::Run($form)
