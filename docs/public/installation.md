# Installation and recovery

## Supported setup for this early community release

| Requirement | Current scope |
|---|---|
| Tested hardware | Google WiFi, ARMv7 / `arm_cortex-a7_neon-vfpv4` |
| Firmware | OpenWrt 25.12.x; device acceptance used 25.12.2 |
| Firewall | fw4 / nftables with socket and TProxy modules |
| LAN | `br-lan`, router `192.168.10.1/24` |
| RAM | 512 MB class recommended; balancing needs at least 224 MiB available |
| Storage | At least 256 MiB free overlay for managed core downloads |
| Build machine | Node 22.12+, npm, Git, OpenSSH, tar; Windows/Linux/macOS |
| SSH | Working noninteractive root authentication through a key/agent |

This is not a universal installer for every OpenWrt router. Core downloads are
currently ARMv7-specific and network policies contain the documented LAN subnet.
The installer refuses another architecture, firmware family or LAN layout and
never renumbers your LAN. Other hardware is unverified even if it passes preflight.

## Quick guided install

1. Keep local recovery access and download a normal OpenWrt configuration backup
   through LuCI. Configure an SSH key through LuCI/your SSH agent and verify that
   `ssh -o BatchMode=yes root@192.168.10.1 true` succeeds. The installer does not
   read or store your router password.
2. Run on your computer, **not on the router**:

   ```sh
   git clone https://github.com/its-hesam/gale-control.git
   cd gale-control
   npm ci
   npm run install:router -- --host root@192.168.10.1 --install-deps
   ```

3. Open `http://192.168.10.1/gale/` and sign in using the router root password.

`--install-deps` uses the router's configured official `apk` repositories. It does
not rewrite feeds. Without the flag, missing prerequisites are reported instead
of installed. Dependency downloads require working router Internet/DNS and feeds
that match its firmware/kernel.

To run a read-only check first:

```sh
npm run check:router -- --host root@192.168.10.1
```

Dependencies include ucode fs/digest/socket/ubus/uci modules, rpcd,
rpcd-mod-ucode, uhttpd-mod-ubus, curl/CA certificates, Lua/lyaml, ip-full,
nftables-json, kmod-nft-tproxy, kmod-nft-socket, unzip, Xray and sing-box.
The script checks actual modules, executables and storage before publishing.

The guided source installer is provided with read-only preflight and a guided in-place update verified on
the tested device. The versioned update/rollback path has live acceptance evidence;
a factory-clean install has not yet had a separate factory-reset acceptance run.

## First connection

1. In **Core Manager**, download and verify the managed core versions you need.
   Tested versions are Xray `26.9.30`, sing-box `1.14.4` and the separate Xray
   compatibility executable `25.12.8`.
2. Offline-activate your primary cores while disconnected. Stage Xray `25.12.8`
   without making it primary if your profiles need the compatibility adapter.
   Some advanced features require these exact managed versions and receipts.
3. In **Subscriptions**, add your own HTTPS URL and choose the correct User-Agent.
   Alternatively import a profile in **Servers → Import profiles & advanced configuration**.
4. Run native validation, then an HTTPS test. A validated configuration is not
   necessarily a reachable VPN server.
5. In **VPN Manager**, choose a strategy and primary server. Configure candidate
   servers for failover/balancing. Select Wi-Fi/LAN routing and boot protection as
   appropriate, then press **Connect network**.
6. Wait for **Network verified**. Check the live server, UDP diagnostic and a client
   browser. IPv6 requires a compatible provider and the all-LAN VPN policy; it is
   not enabled merely because a WireGuard profile contains an IPv6 address.

Fresh installs contain no subscriptions, credentials or provider configurations.
No VPN, routing interception or forwarding guard is enabled merely by installing
the panel. LuCI and SSH are retained. Existing management sessions may need login
again after rpcd reload/restart.

## Updates

From a newer checkout, use the same guided installer without `--install-deps`:

```sh
git pull --ff-only
npm ci
npm run install:router -- --host root@192.168.10.1
```

The code publisher stages checksummed files, validates ucode/shell entry points,
atomically switches the release pointer and commits after smoke checks. It keeps
the prior release for boot recovery. It does not restart VPN/network services.
Legacy first-install scripts in `scripts/` are historical tools, not update commands.

For an existing versioned installation, developers can publish directly:

```sh
# PowerShell
$env:GALE_SSH_TARGET = 'root@192.168.10.1'
node scripts/publish-release.mjs --activate
```

On POSIX shells use `GALE_SSH_TARGET=root@192.168.10.1 node scripts/publish-release.mjs --activate`.
An optional `GALE_ROUTER_URL` sets the management origin; otherwise it is derived
from the SSH hostname. HTTPS needs a certificate trusted by the build machine.

## Backup and return to ordinary routing

Use **Settings → Full recovery backup**, and save the recovery key separately.
The signed, unencrypted bundle contains Gale code, catalog, connection, policies,
six UCI configurations and SSH host identity. It is not a firmware/eMMC image and
does not bundle core executables. Restore requires the same device/compatible
firmware, the signing key and the required managed core versions.

The panel's **Disconnect** restores ordinary routing and disables its forwarding
guard. Local SSH fallback, on the router:

```sh
/usr/share/gale/network-guard-remove
/usr/share/gale/routing-rollback
```

Do not remove the recovery guard blindly during an interrupted restore; use the
documented transaction recovery and inspect status first. Physical power removal,
firmware imaging and multi-day soak are not claimed as completed acceptance.

## Troubleshooting

- **SSH authentication failed:** test SSH with `BatchMode=yes`; load the key in
  your agent. No password is accepted as an installer command-line argument.
- **Preflight rejected LAN/architecture:** this release is not compatible with
  that layout. The installer will not change your network to force compatibility.
- **Missing lyaml/socket:** use `--install-deps`, or install the named packages
  from matching official feeds. Do not use packages built for another kernel/ABI.
- **CORE_ARCH_UNSUPPORTED / FEATURE_CORE_REQUIRED:** managed downloads are ARMv7;
  advanced adapters require the documented managed version and verified receipt.
- **LuCI login expired:** rpcd publication can invalidate sessions; sign in again.
- **VPN healthy but no client Internet:** inspect LAN/UDP/guard status and competing
  routing managers. Do not assume a running process proves working interception.

## Day-to-day controls

Use [Smart Routing](smart-routing.md) for independent Wi-Fi band routes and Iran GeoIP bypass. Use [Settings](application-updates.md) for GitHub application updates and router status lights. Updating Gale is separate from firmware and VPN core updates.
