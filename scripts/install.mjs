import {spawnSync} from 'node:child_process';
import {readFileSync,mkdirSync} from 'node:fs';
import assert from 'node:assert/strict';
const args=process.argv.slice(2);
if(args.includes('--help')){console.log('Gale guided installer\nnode scripts/install.mjs --host root@192.168.10.1 [--check] [--install-deps]\nSupports the documented ARMv7/OpenWrt25.12/br-lan192.168.10.0/24 setup.\n--check is read-only. Installing does not activate VPN routing.');process.exit(0);}
for(let i=0;i<args.length;i++){if(args[i]==='--host'){i++;continue;}assert(['--check','--install-deps'].includes(args[i]),'Unknown option: '+args[i]);}
const host=args.includes('--host')?args[args.indexOf('--host')+1]:process.env.GALE_SSH_TARGET||'root@192.168.10.1';assert(/^root@[A-Za-z0-9][A-Za-z0-9.-]*$/.test(host||''),'Use --host root@hostname or root@IPv4');
const origin=process.env.GALE_ROUTER_URL||'http://'+host.slice(5);const url=new URL(origin);assert(['http:','https:'].includes(url.protocol)&&!url.username&&!url.password&&!url.search&&!url.hash&&url.pathname==='/','Invalid GALE_ROUTER_URL');
function ssh(command,input){let r=spawnSync('ssh',['-o','BatchMode=yes','-o','ConnectTimeout=5',host,command],{input,encoding:'utf8',timeout:300000,maxBuffer:2*1024*1024});if(r.status!==0)throw Error((r.stderr||r.stdout||'SSH failed').trim());return r.stdout;}
const platform=`set -eu
test "$(id -u)" = 0
command -v ucode >/dev/null
grep -q "DISTRIB_ARCH='arm_cortex-a7_neon-vfpv4'" /etc/openwrt_release || { echo 'Supported architecture: arm_cortex-a7_neon-vfpv4' >&2; exit 1; }
grep -q "DISTRIB_RELEASE='25.12" /etc/openwrt_release || { echo 'Supported firmware: OpenWrt25.12.x' >&2; exit 1; }
address=$(uci -q get network.lan.ipaddr)
case "$address" in 192.168.10.1/24) ;; 192.168.10.1) test "$(uci -q get network.lan.netmask)" = 255.255.255.0 ;; *) echo 'Current release requires LAN192.168.10.1/24; installer never renumbers your LAN.' >&2; exit 1 ;; esac
test "$(uci -q get network.lan.device)" = br-lan
test -x /etc/init.d/rpcd; test -x /etc/init.d/uhttpd; test -x /etc/init.d/firewall
test ! -e /etc/gale || test -f /etc/gale/releases.json || test -f /etc/gale/install-pending || { echo 'Unversioned Gale data exists. Preserve it and migrate manually.' >&2; exit 1; }
echo 'Platform and LAN preflight passed.'
`;
console.log(ssh('sh',platform).trim());
if(args.includes('--install-deps')&&!args.includes('--check')){
 const packages='ucode ucode-mod-fs ucode-mod-digest ucode-mod-socket ucode-mod-ubus ucode-mod-uci rpcd rpcd-mod-ucode uhttpd uhttpd-mod-ubus curl ca-bundle lua lyaml ip-full nftables-json kmod-nft-tproxy kmod-nft-socket unzip xray-core sing-box';
 console.log(ssh('sh',`set -eu\nif command -v apk >/dev/null; then apk update; apk add ${packages}; else echo 'This installer expects apk on OpenWrt25.12.' >&2; exit 1; fi\n`).trim());
}
console.log(ssh('sh',`set -eu
for tool in curl lua ip nft tar sha256sum unzip timeout; do command -v "$tool" >/dev/null || { echo "Missing $tool; rerun with --install-deps or install documented dependencies." >&2; exit 1; }; done
ucode -e 'import {create} from "socket";import {sha256} from "digest";import {connect} from "ubus";if(type(create)!="function"||type(sha256)!="function"||type(connect)!="function")exit(1);'
lua -e 'require("lyaml")'
test -x /usr/bin/xray; test -x /usr/bin/sing-box
test -d /sys/module/nft_tproxy; test -d /sys/module/nft_socket
test "$(df -Pk /overlay | awk 'NR==2 {print $4}')" -ge 262144 || { echo 'At least256MiB free overlay is required.' >&2; exit 1; }
echo 'Dependencies passed. No routing changes applied.'
`).trim());
if(args.includes('--check')){console.log('Read-only preflight complete. Run without --check to install/update Gale.');process.exit(0);}
const configFiles='/etc/config/network /etc/config/firewall /etc/config/wireless /etc/config/dhcp /etc/config/dropbear /etc/config/uhttpd';const before=ssh('sha256sum '+configFiles);
ssh('sh',`set -eu
umask 077
mkdir -p /etc/gale /usr/share/gale
chmod 700 /etc/gale
if [ ! -f /etc/gale/releases.json ]; then
 touch /etc/gale/install-pending
 if [ ! -f /etc/gale/state.json ]; then printf '%s\\n' '{"schema_version":1,"profiles":{},"sources":{},"security":{"allow_insecure":false}}' >/etc/gale/state.json; fi
 if [ ! -f /etc/gale/routing-draft.json ]; then printf '%s\\n' '{"default_action":"vpn","lan_cidr":"192.168.10.0/24","rules":[],"applied":false}' >/etc/gale/routing-draft.json; fi
 sync
fi
`);
mkdirSync('.private',{recursive:true});const env={...process.env,GALE_SSH_TARGET:host,GALE_ROUTER_URL:url.origin};let result=spawnSync(process.execPath,['scripts/publish-release.mjs','--activate'],{stdio:'inherit',env});assert.equal(result.status,0,'Publication failed; preserve /etc/gale and rerun this installer.');
ssh('sh',`set -eu
/etc/init.d/gale-core-recovery enable
/etc/init.d/gale-monitor enable
/etc/init.d/gale-monitor start
/usr/share/gale/install-scheduler
rm -f /etc/gale/install-pending
sync
`);
assert.equal(ssh('sha256sum '+configFiles),before,'Standard configuration hashes changed; inspect before continuing.');
console.log('Installed: '+url.origin+'/gale/\nAll six standard configuration files unchanged. LuCI and SSH retained.\nImport your own subscription, configure managed cores in Updates, then explicitly connect.');
