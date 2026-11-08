# Benchmark and Core Manager

## Benchmark

Choose one of three separate test plans:

| Plan | What it measures | Budget |
| --- | --- | --- |
| Native validation | Selected engine accepts the configuration schema | Up to 50 profiles, offline |
| HTTPS latency | A real HTTPS request through the profile | Up to 50 profiles, sequential |
| Speed & UDP quality | Bounded download/upload plus UDP DNS reply samples and jitter | Up to five profiles, about 1.3 MiB each |

Filter by protocol or name, select individual profiles or use the filtered eligible
set, choose a limit and start. Live job progress shows processed, passed/failed and
error counts. Stop requests finish the current check before cancelling the rest.
The shared test worker runs one profile at a time. Tests do not apply LAN routes.

Fresh HTTPS means a successful recorded sample no older than 15 minutes. Results
carry timestamps; old results are not displayed as present availability. UDP loss
is the loss of sampled DNS responses, not a general Internet packet-loss metric.
Throughput samples are bounded measurements, not guaranteed line speed.

Profiles no longer listed by their source are excluded from automatic filtered
selection. They can still be selected manually for a test if native validation passed.
Source retirement and a currently running connection are different facts.

Advanced profile import, TLS overrides and prior diagnostics remain available under
the expandable advanced section. Explicit profile selections were tested against
the real router with HTTPS and throughput/UDP samples, while the active connection
generation stayed unchanged.

## Core Manager

The former **Updates** navigation item is now **Core Manager**. Application updates
remain in Settings; core versions are managed here.

- **Download & verify** stages a selected official Xray or sing-box version, checks
  GitHub's archive SHA-256, and preserves the OpenWrt-packaged executables.
- Managed engine cards distinguish current, previous and staged versions and expose
  their binary fingerprints. Independent publisher signatures are not verified.
- **Apply with recovery** reviews a live upgrade before the existing native/connection
  transaction runs. A failed upgrade restores the previous state.
- **Activate offline / Restore previous** require the VPN to be disconnected and
  invalidate profile validation as required by the existing backend.
- **Run native checks** uses fixed offline fixtures; it does not create a tunnel.
- **System package inventory** is separate from managed application versions. A
  package's presence and protocol labels do not prove a successful provider connection.

The existing offline fixture checks passed on the router. No actual core version
was changed just to test the redesigned page.
