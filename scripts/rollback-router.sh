#!/bin/sh
set -eu
# Removes only the additive Foundation installation. No configuration restore.
test -f /www/gale/.gale-foundation
test ! -f /etc/gale/core-upgrade.pending
test ! -f /etc/gale/acceptance-stage/armed
if [ -f /etc/gale/network-options.json ] || [ -f /usr/share/nftables.d/chain-pre/forward/40-gale-guard.nft ]; then /usr/share/gale/network-guard-remove; fi
# Restore the temporary network before stopping its proxy or removing APIs.
if [ -f /etc/gale/routing-test/armed ]; then /usr/share/gale/routing-rollback; fi
for service in gale-route-watch gale-route-bridges gale-network gale-monitor gale-core-recovery gale-release-recovery; do
 if [ -x "/etc/init.d/$service" ]; then "/etc/init.d/$service" disable; "/etc/init.d/$service" stop; fi
done
if [ -x /etc/init.d/gale-tunnel ]; then /etc/init.d/gale-tunnel disable; /etc/init.d/gale-tunnel stop; fi
rm -f /etc/gale/runtime/active
if [ -d /tmp/gale-discovery ]; then touch /tmp/gale-discovery/cancel; fi
# Ask active batch to stop before removing its API.
if [ -d /tmp/gale-batch ]; then touch /tmp/gale-batch/cancel; fi
rm -f /usr/libexec/rpcd/gale-discovery /usr/libexec/rpcd/gale-backup /usr/libexec/rpcd/gale-monitor /etc/init.d/gale-monitor /etc/init.d/gale-core-recovery /usr/libexec/rpcd/gale-status /usr/libexec/rpcd/gale-profiles /usr/libexec/rpcd/gale-sources /usr/libexec/rpcd/gale-jobs /usr/libexec/rpcd/gale-cores /usr/libexec/rpcd/gale-connection /etc/init.d/gale-tunnel /usr/libexec/rpcd/gale-routing /etc/init.d/gale-route-watch /etc/init.d/gale-route-bridges /etc/init.d/gale-network /usr/share/rpcd/acl.d/gale-read.json
directory=$(mktemp -d /tmp/gale-cron-XXXXXX)
crontab -l >"$directory/original" 2>/dev/null || true
sed '/# gale-source-scheduler$/d' "$directory/original" >"$directory/new"
crontab "$directory/new"
rm -f "$directory/original" "$directory/new"
rmdir "$directory"
rm -f /usr/share/gale/selftests/xray-direct.json /usr/share/gale/selftests/sing-box-direct.json /usr/share/gale/selftests/xray-xhttp-reality.json
rm -rf /www/gale
/etc/init.d/rpcd reload
echo 'Foundation removed; existing network and LuCI retained.'
echo 'Private /etc/gale data and legacy boot migration state preserved.'
