# Application updates and status lights

## Update Gale from Settings

Use **Settings → Gale application updates → Check for updates**. Stable GitHub
releases from [its-hesam/gale-control](https://github.com/its-hesam/gale-control/releases)
are offered when their semantic version is newer than the installed application.
Choose **Download & install** to start. VPN cores are managed separately in Updates.

The router downloads `gale-control.tar.gz` from the fixed repository and verifies
its size and the SHA-256 digest supplied by GitHub's release API. It rejects unsafe
tar paths, links, special files and unsupported package versions, verifies the
internal file manifest and plugin entry points, then uses the existing atomic
release transaction. This is digest verification over HTTPS, not an independent
publisher signature. Trust in the repository and GitHub account remains required.

Profiles, subscriptions, Wi-Fi settings and active network rules are preserved.
The application pointer changes; firmware is not flashed. rpcd reload can require
a fresh login. The previous release is retained and the stable boot recovery anchor
returns to the last committed release if activation is interrupted. Failed health
checks trigger immediate application rollback. A check/update needs GitHub HTTPS
reachability, at least 64 MiB free application storage and 32 MiB free `/tmp`.

Keep a full backup and recovery key before upgrades. If an update is interrupted,
use local SSH to inspect `/tmp/gale-app-update/job.json` and `/etc/gale/releases.json`.
The existing recovery command can be run on the router:

```sh
/etc/init.d/gale-release-recovery start
/etc/init.d/rpcd reload
```

Publishers bump `package.json`, update the lockfile, commit, and push a matching
`v0.x.y` tag. The release workflow tests and builds the code, creates the application
package and checksum, and publishes the GitHub release. GitHub then supplies the
release asset digest consumed by the updater. Do not replace an existing version's
assets; publish a new version.

## Router status lights

Under **Settings → Router status lights**, enable VPN indicators and select a
detected LED for each state. Google WiFi has independent RGB channels:

| State | Default mapping |
| --- | --- |
| Verified VPN network routing | Green, steady |
| Starting connection | Blue, blinking when the timer trigger exists |
| Disconnected or unhealthy | Red, steady |

The worker reads real connection/routing health every two seconds. The first
enable captures the selected LEDs' brightness, triggers and timer delays. Disable
and save to restore them. Colors are hardware-dependent; one LED can represent
several states. Kernel boot indicators may briefly override application behavior.
Google WiFi's blinking, red, green and original-state restoration were checked on
hardware. The feature does not change the router's UCI system LED configuration.
