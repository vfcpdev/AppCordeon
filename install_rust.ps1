$ErrorActionPreference = 'Continue'
Write-Output "== winget version =="
winget --version
Write-Output "== winget list rustup =="
winget list Rustlang.Rustup 2>&1 | Out-String
Write-Output "== rustup install =="
winget install --id Rustlang.Rustup -e --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
