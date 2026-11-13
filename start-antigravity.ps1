# Local files only. No downloads, installers or system-wide proxy changes.
param([switch]$Tui, [string]$Proxy, [string]$AntigravityPath)
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'proxy.local.json'
$exe = Join-Path $PSScriptRoot 'target\release\ag_unlocker.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Build first: cargo build --release --locked' }
if (-not $Proxy) { $Proxy = $env:AG_UPSTREAM_PROXY }
if (-not $Proxy -and (Test-Path -LiteralPath $configPath)) {
    $Proxy = (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).proxy
}
if (-not $Proxy) {
    $Proxy = Read-Host 'Your HTTP CONNECT proxy (http://IP:PORT, no credentials)'
    $saveConfig = $true
}
$uri = $null
$ip = $null
if (-not [Uri]::TryCreate($Proxy, [UriKind]::Absolute, [ref]$uri) -or
    $uri.Scheme -ne 'http' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
    $uri.AbsolutePath -ne '/' -or $uri.Port -lt 1 -or
    -not [Net.IPAddress]::TryParse($uri.DnsSafeHost, [ref]$ip)) {
    throw 'Supported: http://IP:PORT without credentials. HTTPS/SOCKS are not supported.'
}
if ($saveConfig) {
    @{proxy=$Proxy} | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding ascii
}
$env:AG_UPSTREAM_PROXY = $Proxy
Remove-Item Env:\ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
Remove-Item Env:\NODE_OPTIONS -ErrorAction SilentlyContinue
if ($Tui) {
    Start-Process -FilePath $exe -ArgumentList '--tui','--inline' -Wait -NoNewWindow
    return
}
if (-not $AntigravityPath) {
    $AntigravityPath = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'
}
if (-not (Test-Path -LiteralPath $AntigravityPath)) {
    throw 'Antigravity is not installed at the default location. Specify -AntigravityPath.'
}
# Apply only the two known same-length client changes, with an exact backup.
$binary = Join-Path (Split-Path $AntigravityPath -Parent) 'resources\bin\language_server.exe'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Unsupported installation: Language Server missing.' }
$encoding = [Text.Encoding]::GetEncoding(28591)
$original = [IO.File]::ReadAllBytes($binary)
$text = $encoding.GetString($original)
if ($text.Contains('ineligible') -or $text.Contains('https_proxy')) {
    $install = Split-Path $AntigravityPath -Parent
    if (Get-Process Antigravity,language_server -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$install\*" }) {
        throw 'Close Antigravity before the first launch so its Language Server can be patched.'
    }
    if (-not $text.Contains('ineligible') -and -not $text.Contains('inexigible')) { throw 'Unknown binary: refusing patch.' }
    $backup = "$binary.original.$((Get-FileHash -LiteralPath $binary).Hash).bak"
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $binary -Destination $backup }
    $patched = $encoding.GetBytes($text.Replace('ineligible','inexigible').Replace('https_proxy','AG_LS_PROXY'))
    if ($patched.Length -ne $original.Length) { throw 'Patch size mismatch.' }
    [IO.File]::WriteAllBytes("$binary.local.tmp", $patched)
    Move-Item -LiteralPath "$binary.local.tmp" -Destination $binary -Force
} elseif (-not $text.Contains('inexigible')) { throw 'Unknown binary: no supported patch signature.' }
$active = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 53129 -State Listen -ErrorAction SilentlyContinue
$marker = Join-Path $PSScriptRoot 'listener.local.json'
if ($active) {
    $owner = Get-Process -Id $active[0].OwningProcess
    if ($owner.Path -ne $exe -or -not (Test-Path $marker)) { throw 'Port 53129 belongs to an unrecognized listener.' }
    $saved = Get-Content $marker -Raw | ConvertFrom-Json
    if ($saved.pid -ne $owner.Id -or $saved.proxy -ne $Proxy) { throw 'Listener configuration changed. Stop the old listener before restarting.' }
} else {
    $child = Start-Process -FilePath $exe -ArgumentList '--privacy-proxy' -WindowStyle Hidden -PassThru
    $ready = $false
    for ($i=0; $i -lt 50; $i++) {
        $bound = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 53129 -State Listen -ErrorAction SilentlyContinue
        if ($bound -and $bound[0].OwningProcess -eq $child.Id) { $ready=$true; break }
        $child.Refresh()
        if ($child.HasExited) { break }
        Start-Sleep -Milliseconds 100
    }
    if (-not $ready) { Stop-Process -Id $child.Id -ErrorAction SilentlyContinue; throw 'Local proxy did not start.' }
    @{pid=$child.Id;proxy=$Proxy} | ConvertTo-Json | Set-Content $marker -Encoding ascii
}
$env:HTTP_PROXY = 'http://127.0.0.1:53129'
$env:HTTPS_PROXY = $env:HTTP_PROXY
$env:AG_LS_PROXY = $env:HTTP_PROXY
$env:NO_PROXY = 'localhost,127.0.0.1,::1'
Start-Process -FilePath $AntigravityPath -ArgumentList '--proxy-server=http://127.0.0.1:53129','--proxy-bypass-list=localhost;127.0.0.1;[::1]'
