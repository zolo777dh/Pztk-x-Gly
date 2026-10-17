$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Install Node.js 22 or newer, then reopen PowerShell.'
}
& npm.cmd ci --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
& npm.cmd test
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }
& npm.cmd run package:win
if ($LASTEXITCODE -ne 0) { throw 'Windows packaging failed.' }
Write-Host 'Build ready: release\Pztk-x-Glyalith-0.1.0-Windows-x64.zip'
