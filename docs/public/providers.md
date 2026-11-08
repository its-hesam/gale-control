# Providers and server collection

Providers is a catalog and acquisition workspace. It does not switch the active
VPN, enable new profiles, or execute scripts from repositories.

## Public repositories

Built-in adapters index these sources:

| Source | Branch and layout |
| --- | --- |
| [Config Collector](https://github.com/miladtahanian/Config-Collector) | `main`, `mixed_iran.txt` |
| [ConfigHub](https://github.com/heliataromi/ConfigHub) | `subscription`, country / protocol / format files |
| [Kamaji](https://github.com/shabane/kamaji) | `master`, `hub/` |
| [OpenRay](https://github.com/sakha1370/OpenRay) | `main`, `output/country/`, `output/kind/` and supported aggregate files |

1. Choose a provider and **Discover server lists** / **Update catalog**.
2. Filter files by country hint, protocol, format or path. Empty and oversized
   upstream files are shown with a reason instead of being offered as working lists.
3. Select up to five files and set the profile sample budget.
4. **Fetch selected files** uses the scanned commit. **Update & fetch new servers**
   first refreshes the catalog, then imports the selected paths from the new commit.
5. Review the added, duplicate, rejected and archived counts. Validate and test the
   imported configurations in Servers or Benchmark before connecting.

Country hints are upstream filename classifications, not verified endpoint locations.
Public nodes remain untrusted. A repository advertising a protocol does not prove
that it currently contains any nonempty files for that protocol.

Use **Add repository** for another public GitHub repository, branch or commit SHA,
and optional folder prefix. Adapters discover JSON, YAML, text, `.conf` and `.ovpn`
files; parsing capability is reported separately. Safe filenames, no symlink entries,
immutable commit URLs and bounded downloads are required. No upstream programs run.

Downloads try the router's normal public DNS/HTTPS path first. Fixed GitHub and
Surfshark origins can fall back through the already-running local VPN proxy when
router-origin DNS or HTTPS is blocked. TLS checks stay enabled, redirects are not
followed, and account credentials are never sent to public catalog endpoints.

## Surfshark

The adapter fetches the official public OpenVPN configuration archive and official
server-location catalog. Choose a location and TCP/UDP `.ovpn` file in Providers.
An active paid account and its **manual OpenVPN service credentials** are required
for a working connection. Save those under **OpenVPN service credentials**; this is
not the main account password. They are attached privately to imported OpenVPN
profiles and are never returned by status/profile APIs.

WireGuard key generation and account authorization happen in the
[official account portal](https://my.surfshark.com/). Import the resulting configuration
files into the Surfshark provider card. See the
[official WireGuard router guide](https://support.surfshark.com/hc/en-us/articles/6585805595666-How-to-set-up-a-manual-WireGuard-connection-on-a-router).

## Proton VPN

Proton Free and paid plans can export router configurations. Open the
[official Downloads portal](https://account.protonvpn.com/downloads), generate a
WireGuard configuration, download it, and import it into the Proton card.
OpenVPN exports and their separate service credentials are also accepted.
See [Proton's official WireGuard export instructions](https://protonvpn.com/support/wireguard-configurations).

**Automatic Proton account login / SRP / two-factor handling and automatic account
WireGuard generation are not implemented.** Surfshark main-account login is also
not implemented. The UI offers the actual supported official-portal workflow,
not an untested password form or an invented account API. No real paid account
credentials were available for provider handshake acceptance.

## Protocol and storage boundaries

VLESS, VMess and other supported proxy formats use the existing import adapters.
WireGuard and OpenVPN files can be imported and associated with a provider.
IKEv2, L2TP and unsupported formats can be retained as **private archives** when
fetched, but **have no Gale connection adapter**. An archive cannot be selected as
a working VPN profile. The original file can be downloaded from its provider card.

Limits: 20 saved provider entries, five files per job, 1 MiB per file, up to 200
profiles per file, 20 private archives, and the existing 2,000-profile / 8 MiB
catalog limit. Large plain/base64 link lists are sampled; JSON/YAML still need to
fit the parser's native limits. These caps protect a small router's memory.

Source selections, provider provenance, service credentials and private archives
are included in catalog/full backups. Backups are signed where applicable but
not encrypted; keep them private. Catalog cache metadata can be rebuilt by scanning.

## Checked on the device

All four built-in GitHub catalogs were scanned and real sample configurations
imported. Surfshark's 284-file public OpenVPN catalog and a sample download passed.
Repeated imports produced duplicates rather than duplicate profiles. Native parser,
credential-redaction and backup validation tests passed, and the real 223-profile /
five-provider catalog normalized without changing the network. This proves acquisition
and preservation, not universal public-server reliability or paid-account connectivity.
