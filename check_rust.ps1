$ErrorActionPreference = 'Continue'
Write-Output "== cargo =="
if (Test-Path "$env:USERPROFILE\.cargo\bin\cargo.exe") { Write-Output "cargo: FOUND" } else { Write-Output "cargo: MISSING" }
Write-Output "== rustup dir =="
if (Test-Path "$env:USERPROFILE\.cargo") { Get-ChildItem "$env:USERPROFILE\.cargo\bin" -Name -ErrorAction SilentlyContinue } else { Write-Output "no .cargo dir" }
