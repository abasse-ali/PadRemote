# Active ou desactive le lancement de PadRemote a l'ouverture de session (sans fenetre).
param([switch]$Disable)

$ErrorActionPreference = 'Stop'
$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'PadRemote.lnk'

if ($Disable) {
    if (Test-Path $lnk) { Remove-Item $lnk -Force }
    Write-Host 'Demarrage automatique desactive.'
    exit 0
}

$pyw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*WindowsApps*' } | Select-Object -First 1).Source
if (-not $pyw) {
    $py = (Get-Command python.exe -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*WindowsApps*' } | Select-Object -First 1).Source
    if ($py) { $pyw = Join-Path (Split-Path $py) 'pythonw.exe' }
}
if (-not $pyw -or -not (Test-Path $pyw)) {
    Write-Host 'pythonw.exe introuvable : installez Python depuis python.org.'
    exit 1
}

$server = Join-Path (Split-Path $PSScriptRoot) 'server\padremote.py'
$shell = New-Object -ComObject WScript.Shell
$s = $shell.CreateShortcut($lnk)
$s.TargetPath = $pyw
$s.Arguments = "`"$server`" --no-browser"
$s.WorkingDirectory = Split-Path $server
$s.Description = 'PadRemote - serveur pour iPhone'
$s.Save()

Write-Host "Demarrage automatique active ($lnk)."
Write-Host 'PadRemote se lancera en arriere-plan a chaque ouverture de session.'
