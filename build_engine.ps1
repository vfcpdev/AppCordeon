$ErrorActionPreference = 'Continue'
$env:Path = "C:\Users\vfcp1\.cargo\bin;" + $env:Path
Set-Location d:\Documents\SideProjects\AppCordeon\acordeon_engine
Write-Output "== build release =="
cmd /c "cargo build --release 2>&1"
Write-Output "== exit: $LASTEXITCODE =="
Write-Output "== artifacts =="
if (Test-Path "target\release\acordeon_engine.dll") {
    Get-Item "target\release\acordeon_engine.dll" | Select-Object FullName, Length | Format-List
} else {
    Get-ChildItem "target\release" -Filter "*.dll" -ErrorAction SilentlyContinue | Select-Object FullName, Length | Format-List
}
