#!/bin/sh
set -eu
stage=/tmp/gale-foundation-stage
test -f "$stage/dist/index.html"
# Fail before mutations when the official socket dependency is absent.
ucode -e 'import {create} from "socket"; if(type(create)!="function")exit(1);'
lua -e 'require("lyaml")'
test ! -e /usr/libexec/rpcd/gale-routing
test ! -e /etc/init.d/gale-route-watch
test ! -e /etc/init.d/gale-route-bridges
test ! -e /www/gale
test ! -e /usr/libexec/rpcd/gale-status
test ! -e /usr/share/rpcd/acl.d/gale-read.json
test ! -e /usr/share/gale
test ! -e /usr/libexec/rpcd/gale-profiles
test ! -e /usr/libexec/rpcd/gale-cores
test ! -e /usr/libexec/rpcd/gale-connection
test ! -e /etc/init.d/gale-tunnel
test ! -e /usr/libexec/rpcd/gale-jobs
test ! -e /usr/libexec/rpcd/gale-sources
mkdir -p /usr/libexec/rpcd
rollback() {
 rm -f /usr/libexec/rpcd/gale-status /usr/libexec/rpcd/gale-profiles /usr/libexec/rpcd/gale-sources /usr/libexec/rpcd/gale-jobs /usr/libexec/rpcd/gale-cores /usr/libexec/rpcd/gale-connection /etc/init.d/gale-tunnel /usr/libexec/rpcd/gale-routing /etc/init.d/gale-route-watch /etc/init.d/gale-route-bridges /etc/init.d/gale-network /usr/share/rpcd/acl.d/gale-read.json
 # Only this new installation path is removed; never touch /www or LuCI.
 if [ -d /www/gale ] && [ -f /www/gale/.gale-foundation ]; then rm -rf /www/gale; fi
 /etc/init.d/rpcd reload
}
trap rollback EXIT
touch "$stage/dist/.gale-foundation"
cp -R "$stage/dist" /www/gale
find /www/gale -type d -exec chmod 755 {} +
find /www/gale -type f -exec chmod 644 {} +
mkdir -p /usr/share/gale/lib /usr/share/gale/selftests
cp "$stage/router/lib/"*.uc /usr/share/gale/lib/
cp "$stage/router/selftests/"*.json /usr/share/gale/selftests/
for helper in network-guard-install network-guard-remove lan-launch capture benchmark source-scheduler batch-launch profile-task connection-launch active-probe verify-core core-download-launch unpack-core check-staged-core core-space connection-udp-launch routing-apply routing-rollback; do cp "$stage/router/$helper" "/usr/share/gale/$helper"; chmod 755 "/usr/share/gale/$helper"; done
for source in network-boot.uc prepare-network-guard.uc lan-worker.uc routing-prepare.uc batch-worker.uc connection-worker.uc connection-watch.uc core-download.uc connection-udp.uc udp-relay-request.uc routing-watch.uc routing-arm.uc; do cp "$stage/router/$source" "/usr/share/gale/$source"; done
cp "$stage/router/gale-tunnel.init" /etc/init.d/gale-tunnel
chmod 755 /etc/init.d/gale-tunnel
for service in gale-route-watch gale-route-bridges gale-network gale-core-recovery gale-monitor; do cp "$stage/router/$service.init" "/etc/init.d/$service"; chmod 755 "/etc/init.d/$service"; done
cp "$stage/router/performance-probe" "/usr/share/gale/performance-probe"
chmod 755 "/usr/share/gale/performance-probe"
cp "$stage/router/udp-benchmark-sample.uc" "/usr/share/gale/udp-benchmark-sample.uc"
chmod 644 "/usr/share/gale/udp-benchmark-sample.uc"
cp "$stage/router/yaml-to-json.lua" "/usr/share/gale/yaml-to-json.lua"
chmod 755 "/usr/share/gale/yaml-to-json.lua"
cp "$stage/router/core-upgrade-worker.uc" "/usr/share/gale/core-upgrade-worker.uc"
chmod 644 "/usr/share/gale/core-upgrade-worker.uc"
cp "$stage/router/core-upgrade-launch" "/usr/share/gale/core-upgrade-launch"
chmod 755 "/usr/share/gale/core-upgrade-launch"
cp "$stage/router/core-recover.uc" "/usr/share/gale/core-recover.uc"
chmod 644 "/usr/share/gale/core-recover.uc"
cp "$stage/router/routing-policy-prepare.uc" "/usr/share/gale/routing-policy-prepare.uc"
chmod 644 "/usr/share/gale/routing-policy-prepare.uc"
cp "$stage/router/routing-policy-apply" "/usr/share/gale/routing-policy-apply"
chmod 755 "/usr/share/gale/routing-policy-apply"
cp "$stage/router/routing-policy-worker.uc" "/usr/share/gale/routing-policy-worker.uc"
chmod 644 "/usr/share/gale/routing-policy-worker.uc"
cp "$stage/router/routing-policy-launch" "/usr/share/gale/routing-policy-launch"
chmod 755 "/usr/share/gale/routing-policy-launch"
cp "$stage/router/discovery-worker.uc" "/usr/share/gale/discovery-worker.uc"
chmod 644 "/usr/share/gale/discovery-worker.uc"
cp "$stage/router/discovery-launch" "/usr/share/gale/discovery-launch"
chmod 755 "/usr/share/gale/discovery-launch"
cp "$stage/router/source-scheduler" "/usr/share/gale/source-scheduler"
chmod 755 "/usr/share/gale/source-scheduler"
cp "$stage/router/profile-task" "/usr/share/gale/profile-task"
chmod 755 "/usr/share/gale/profile-task"
cp "$stage/router/batch-worker.uc" "/usr/share/gale/batch-worker.uc"
chmod 644 "/usr/share/gale/batch-worker.uc"
cp "$stage/router/connection-worker.uc" "/usr/share/gale/connection-worker.uc"
chmod 644 "/usr/share/gale/connection-worker.uc"
cp "$stage/router/connection-watch.uc" "/usr/share/gale/connection-watch.uc"
chmod 644 "/usr/share/gale/connection-watch.uc"
cp "$stage/router/network-boot.uc" "/usr/share/gale/network-boot.uc"
chmod 644 "/usr/share/gale/network-boot.uc"
cp "$stage/router/prepare-network-guard.uc" "/usr/share/gale/prepare-network-guard.uc"
chmod 644 "/usr/share/gale/prepare-network-guard.uc"
cp "$stage/router/routing-prepare.uc" "/usr/share/gale/routing-prepare.uc"
chmod 644 "/usr/share/gale/routing-prepare.uc"
cp "$stage/router/routing-arm.uc" "/usr/share/gale/routing-arm.uc"
chmod 644 "/usr/share/gale/routing-arm.uc"
cp "$stage/router/monitor-worker.uc" "/usr/share/gale/monitor-worker.uc"
chmod 644 "/usr/share/gale/monitor-worker.uc"
cp "$stage/router/routing-watch.uc" "/usr/share/gale/routing-watch.uc"
chmod 644 "/usr/share/gale/routing-watch.uc"
cp "$stage/router/ipv6-prepare.uc" "/usr/share/gale/ipv6-prepare.uc"
chmod 644 "/usr/share/gale/ipv6-prepare.uc"
cp "$stage/router/ipv6-apply" "/usr/share/gale/ipv6-apply"
chmod 755 "/usr/share/gale/ipv6-apply"
cp "$stage/router/ipv6-restore" "/usr/share/gale/ipv6-restore"
chmod 755 "/usr/share/gale/ipv6-restore"
cp "$stage/router/routing-apply" "/usr/share/gale/routing-apply"
chmod 755 "/usr/share/gale/routing-apply"
cp "$stage/router/routing-rollback" "/usr/share/gale/routing-rollback"
chmod 755 "/usr/share/gale/routing-rollback"
cp "$stage/router/benchmark" "/usr/share/gale/benchmark"
chmod 755 "/usr/share/gale/benchmark"
for source in /usr/share/gale/*.uc; do ucode -c -o /tmp/gale-compile-check "$source"; done
rm -f /tmp/gale-compile-check
for plugin in gale-profiles gale-sources gale-jobs gale-cores gale-connection gale-routing gale-discovery gale-backup gale-monitor; do
 ucode "$stage/router/$plugin" list >/dev/null
 cp "$stage/router/$plugin" "/usr/libexec/rpcd/$plugin"
 chmod 755 "/usr/libexec/rpcd/$plugin"
done
cp "$stage/router/gale-status" /usr/libexec/rpcd/gale-status
chmod 755 /usr/libexec/rpcd/gale-status
cp "$stage/router/gale-read.json" /usr/share/rpcd/acl.d/gale-read.json
/etc/init.d/gale-core-recovery enable
/etc/init.d/gale-monitor enable
/etc/init.d/gale-monitor start
/etc/init.d/rpcd reload
sleep 1
ubus -t 8 call gale-status status | jsonfilter -e '@.schema_version' | grep -qx 1
trap - EXIT
echo 'Installed Gale Foundation. Network, firewall, SSH and LuCI configuration untouched.'
