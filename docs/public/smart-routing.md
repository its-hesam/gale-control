# Smart Routing, Wi-Fi and Iran GeoIP

Open **Smart Routing**. Choose a default, configure each Wi-Fi band, add optional
IPv4 device exceptions, then **Save draft → confirm → Apply saved policy**.
The network must already be connected in VPN Manager. Merely editing fields or
saving a draft does not change traffic.

## Independent Wi-Fi routes

Each available LAN access-point band supports **Follow network default**, **VPN
tunnel**, **Direct internet**, or **Block internet**. For example, select VPN on
2.4 GHz and Direct on 5 GHz. All LAN APs on that band share the choice; WAN station
interfaces are excluded. SSIDs, passwords and LAN addresses are not changed.
Ethernet follows the network default. IPv4 device exceptions have higher priority.

Gale marks packets at the access point's nftables ingress hook before the shared
LAN bridge. The same classifier handles IPv4 and IPv6. Device IP exceptions remain
IPv4-only: with IPv6 tunneling enabled, remove them before applying Wi-Fi / GeoIP
policies, or disable IPv6 tunneling. The UI blocks this unsupported combination.

Direct routes intentionally bypass VPN protection. During boot/recovery, the
persistent guard blocks unknown traffic until classification is restored, so direct
devices may temporarily lose access too. Existing connections and DNS NAT state may
need to expire/reconnect after policy changes or roaming between bands. With no
direct IPv6 WAN, a direct band may have only working IPv4 internet.

## Iran direct list

The upstream is [Chocolate4U/Iran-v2ray-rules](https://github.com/chocolate4u/Iran-v2ray-rules).
**Update GeoIP list** resolves the `release` branch to an immutable commit, downloads
`geoip-lite.dat` and its SHA-256 file from that same commit, verifies the digest,
and extracts only `geoip:ir`. It does not execute upstream code.

Enable **Bypass VPN for Iran IPs**, save and apply. The rule changes VPN-selected
Iran destination IP ranges to direct; blocked devices remain blocked. This feature
matches destination IPs, including IPv6. It does **not** implement geosite/domain
matching or claim that every Iranian domain uses an Iranian IP.

Updating the downloaded list does not alter active rules. Save and apply to activate
the latest verified list. Upstream data retains its own GPL-3.0 license and source
attribution; it is fetched at runtime and is not bundled into Gale's MIT source.

## Evidence and boundaries

- IPv4 and IPv6 packets were tested through a real Linux bridge in isolated
  namespaces: direct band succeeds, VPN without an engine fails closed, GeoIP
  exceptions bypass, blocked band cannot reach the destination.
- A physical 2.4 GHz Windows client changed to direct egress and back to VPN;
  independent timed restoration and SSH were retained.
- Physical 5 GHz client roaming and a direct WAN with native IPv6 were not tested.
- This controls internet routing. Both AP bands remain in the same LAN and can
  communicate locally; it does not create guest-network isolation.
