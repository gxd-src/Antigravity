# Local build only; no downloads.
$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'target\release\ag_unlocker.exe'
if (-not $env:AG_UPSTREAM_PROXY) { throw 'Set AG_UPSTREAM_PROXY first.' }
if (-not (Test-Path -LiteralPath $exe)) { throw 'Run cargo build --release --locked first.' }
Start-Process -FilePath $exe -ArgumentList '--tui', '--inline' -Wait -NoNewWindow
