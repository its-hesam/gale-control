import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const versioned=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','test -f /etc/gale/releases.json'],{encoding:'utf8'});if(versioned.status===0)throw new Error('Versioned installation: use node scripts/publish-release.mjs --activate');
const r=spawnSync('tar',['-czf','-','dist','router'],{maxBuffer:8*1024*1024});if(r.status!==0)throw new Error('Archive failed');
const transfer=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','test -f /www/gale/.gale-foundation && mkdir -p /tmp/gale-foundation-stage && tar -xzf - -C /tmp/gale-foundation-stage'],{input:r.stdout});if(transfer.status!==0)throw new Error('Stage failed');
const script=`set -eu
test -f /www/gale/.gale-foundation
test ! -f /etc/gale/routing-test/armed
umask 077
set -- /www/gale /usr/share/gale/lib /usr/share/gale/selftests /usr/libexec/rpcd/gale-status /usr/share/rpcd/acl.d/gale-read.json
for candidate in /usr/share/gale/* /usr/libexec/rpcd/gale-profiles /usr/libexec/rpcd/gale-sources /usr/libexec/rpcd/gale-jobs /usr/libexec/rpcd/gale-cores /usr/libexec/rpcd/gale-connection /usr/libexec/rpcd/gale-routing /etc/init.d/gale-tunnel /etc/init.d/gale-route-watch /etc/init.d/gale-route-bridges /etc/init.d/gale-network; do
 if [ -f "$candidate" ]; then set -- "$@" "$candidate"; fi
done
tar -czf /root/gale-last-good-code.tgz "$@" 2>/dev/null
restore_code() { tar -xzf /root/gale-last-good-code.tgz -C /; /etc/init.d/rpcd reload; }
trap restore_code EXIT
mkdir -p /usr/share/gale/selftests
mkdir -p /usr/share/gale/lib
for helper in network-guard-install network-guard-remove lan-launch connection-udp-launch routing-apply routing-rollback connection-launch active-probe verify-core core-download-launch unpack-core check-staged-core core-space; do cp "/tmp/gale-foundation-stage/router/$helper" "/usr/share/gale/$helper"; chmod 755 "/usr/share/gale/$helper"; done
cp /tmp/gale-foundation-stage/router/gale-network.init /etc/init.d/gale-network
chmod 755 /etc/init.d/gale-network
cp /tmp/gale-foundation-stage/router/network-boot.uc /usr/share/gale/network-boot.uc
cp /tmp/gale-foundation-stage/router/prepare-network-guard.uc /usr/share/gale/prepare-network-guard.uc
cp /tmp/gale-foundation-stage/router/lan-worker.uc /usr/share/gale/lan-worker.uc
cp /tmp/gale-foundation-stage/router/routing-prepare.uc /usr/share/gale/routing-prepare.uc
cp /tmp/gale-foundation-stage/router/connection-udp.uc /usr/share/gale/connection-udp.uc
cp /tmp/gale-foundation-stage/router/udp-relay-request.uc /usr/share/gale/udp-relay-request.uc
cp /tmp/gale-foundation-stage/router/routing-watch.uc /usr/share/gale/routing-watch.uc
cp /tmp/gale-foundation-stage/router/routing-arm.uc /usr/share/gale/routing-arm.uc
cp /tmp/gale-foundation-stage/router/gale-route-watch.init /etc/init.d/gale-route-watch
cp /tmp/gale-foundation-stage/router/gale-route-bridges.init /etc/init.d/gale-route-bridges
chmod 755 /etc/init.d/gale-route-watch /etc/init.d/gale-route-bridges
cp /tmp/gale-foundation-stage/router/connection-worker.uc /usr/share/gale/connection-worker.uc
cp /tmp/gale-foundation-stage/router/connection-watch.uc /usr/share/gale/connection-watch.uc
cp /tmp/gale-foundation-stage/router/gale-tunnel.init /etc/init.d/gale-tunnel
chmod 755 /etc/init.d/gale-tunnel
cp /tmp/gale-foundation-stage/router/core-download.uc /usr/share/gale/core-download.uc
cp /tmp/gale-foundation-stage/router/lib/*.uc /usr/share/gale/lib/
for source in /usr/share/gale/*.uc; do ucode -c -o /tmp/gale-compile-check "$source"; done
rm -f /tmp/gale-compile-check
cp /tmp/gale-foundation-stage/router/capture /usr/share/gale/capture
chmod 755 /usr/share/gale/capture
cp /tmp/gale-foundation-stage/router/benchmark /usr/share/gale/benchmark
chmod 755 /usr/share/gale/benchmark
cp /tmp/gale-foundation-stage/router/source-scheduler /usr/share/gale/source-scheduler
chmod 755 /usr/share/gale/source-scheduler
cp /tmp/gale-foundation-stage/router/profile-task /usr/share/gale/profile-task
chmod 755 /usr/share/gale/profile-task
cp /tmp/gale-foundation-stage/router/batch-launch /usr/share/gale/batch-launch
cp /tmp/gale-foundation-stage/router/batch-worker.uc /usr/share/gale/batch-worker.uc
chmod 755 /usr/share/gale/batch-launch
cp /tmp/gale-foundation-stage/router/selftests/*.json /usr/share/gale/selftests/
cp -R /tmp/gale-foundation-stage/dist/. /www/gale/
find /www/gale -type d -exec chmod 755 {} +
find /www/gale -type f -exec chmod 644 {} +
ucode /tmp/gale-foundation-stage/router/gale-status list >/dev/null
cp /tmp/gale-foundation-stage/router/gale-status /usr/libexec/rpcd/gale-status
chmod 755 /usr/libexec/rpcd/gale-status
ucode /tmp/gale-foundation-stage/router/gale-profiles list >/dev/null
cp /tmp/gale-foundation-stage/router/gale-profiles /usr/libexec/rpcd/gale-profiles
chmod 755 /usr/libexec/rpcd/gale-profiles
ucode /tmp/gale-foundation-stage/router/gale-sources list >/dev/null
cp /tmp/gale-foundation-stage/router/gale-sources /usr/libexec/rpcd/gale-sources
chmod 755 /usr/libexec/rpcd/gale-sources
ucode /tmp/gale-foundation-stage/router/gale-jobs list >/dev/null
cp /tmp/gale-foundation-stage/router/gale-jobs /usr/libexec/rpcd/gale-jobs
chmod 755 /usr/libexec/rpcd/gale-jobs
ucode /tmp/gale-foundation-stage/router/gale-connection list >/dev/null
cp /tmp/gale-foundation-stage/router/gale-connection /usr/libexec/rpcd/gale-connection
chmod 755 /usr/libexec/rpcd/gale-connection
ucode /tmp/gale-foundation-stage/router/gale-routing list >/dev/null
cp /tmp/gale-foundation-stage/router/gale-routing /usr/libexec/rpcd/gale-routing
chmod 755 /usr/libexec/rpcd/gale-routing
ucode /tmp/gale-foundation-stage/router/gale-cores list >/dev/null
cp /tmp/gale-foundation-stage/router/gale-cores /usr/libexec/rpcd/gale-cores
chmod 755 /usr/libexec/rpcd/gale-cores
cp /tmp/gale-foundation-stage/router/gale-read.json /usr/share/rpcd/acl.d/gale-read.json
/etc/init.d/rpcd reload
sleep 2
ubus list gale-profiles | grep -qx gale-profiles
ubus list gale-connection | grep -qx gale-connection
trap - EXIT
`;
const update=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','sh'],{input:script,encoding:'utf8'});if(update.status!==0)throw new Error(update.stderr);console.log('Foundation assets and ACL updated');

const features=spawnSync(process.execPath,['scripts/update-features.mjs'],{stdio:'inherit'});if(features.status!==0)throw new Error('Feature installation failed');
