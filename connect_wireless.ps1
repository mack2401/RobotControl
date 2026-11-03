param(
    [string]$PairAddress,
    [string]$PairCode,
    [string]$ConnectAddress
)

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    Write-Error "adb.exe not found at $adb"
    exit 1
}

if ($PairAddress -and $PairCode) {
    Write-Host "Pairing with $PairAddress using code $PairCode..." -ForegroundColor Cyan
    & $adb pair $PairAddress $PairCode
}

if ($ConnectAddress) {
    Write-Host "Connecting to $ConnectAddress..." -ForegroundColor Yellow
    & $adb connect $ConnectAddress
}

Write-Host "Connected devices:" -ForegroundColor Green
& $adb devices
