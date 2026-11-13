# Proxy-only build

Build on Windows with stable Rust MSVC, C++ Build Tools and Windows SDK:
`cargo build --release --locked`.

Set AG_UPSTREAM_PROXY to your own HTTP CONNECT proxy URL at runtime.
A convenient Windows alternative is `./start-antigravity.ps1`: it asks for the
proxy once, saves it in ignored proxy.local.json and launches the local build
plus Antigravity. Pass -Tui for the terminal interface. No startup downloads.
A literal IP is required; authentication is unsupported. No endpoint is bundled.
Missing configuration fails closed. Destination port 443 only.

Run `target/release/ag_unlocker.exe --tui --inline` for TUI or use tui.ps1.
`--privacy-proxy` runs just the loopback CONNECT listener.
The local launcher does not download anything.

Disabled: bundled DNS/proxy providers, external DNS, direct fallback, exit
geolocation, background network probes, release fetching, hardware fingerprint.
TLS dependencies updated; CONNECT hosts validated and exact HTTP 200 required.
Legacy UI settings do not override the runtime proxy-only policy.

This is not a firewall for Google Antigravity and does not disable its updater
or telemetry. Proxy metadata remains visible. TLS interception must be disabled.
No complete-audit or zero-leakage guarantee is made. Remaining dependency
advisories flag unmaintained ttf-parser and Unix zbus/zvariant dependencies.
