# Security and private data

Gale uses the router's existing OpenWrt root session. Use a strong router password
and keep management access on your trusted LAN. The installer does not modify
your password, SSH configuration or LuCI configuration. Do not expose `/ubus` or
the management panel to the public Internet.

Never attach raw VPN configurations, subscription URLs, recovery bundles, signing
keys, SSH host keys or `/etc/config/wireless` to an issue. Use the panel's redacted
diagnostics export, then review the file before sharing it. Recovery exports are
signed but **not encrypted** and contain private data. Keep the signing key apart
from the backup. `.private/` and local device reports are excluded from Git.

Native validation checks configuration syntax. It does not prove a provider is
reachable, trustworthy, private or compatible with every transport option.
Disabling certificate verification is an explicit per-profile/global decision;
fresh installs default to strict TLS behavior.

Core archives are downloaded from official GitHub releases and checked against
the official SHA-256 digest before extraction/execution. Independent publisher
signatures are not verified. Gale releases use checksummed immutable directories
and recovery pointers, not a signed OpenWrt package feed.

Only one application should manage transparent routing at a time. Installation
does not uninstall or disable PassWall, v2rayA or other applications. The installer
does not flash firmware and does not enable VPN routing by itself.

Application updates accept only stable versioned assets from its-hesam/gale-control. GitHub release asset SHA-256 and the internal file manifest are checked over HTTPS; independent publisher signatures are not verified. Wi-Fi direct routes and enabled Iran GeoIP exceptions intentionally bypass the VPN guard while classification is active. Wi-Fi band routing does not isolate clients on the shared LAN.
