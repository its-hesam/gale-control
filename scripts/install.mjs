import {connectSSH} from './ssh-transport.mjs';
import {publishRelease} from './publish-release.mjs';
import {pathToFileURL} from 'node:url';import {resolve} from 'node:path';
import {mkdirSync} from 'node:fs';
import assert from 'node:assert/strict';
export async function install(args=process.argv.slice(2),{connector=connectSSH}={}){

if(args.includes('--help')){console.log('Gale guided installer\nnode scripts/install.mjs --host root@192.168.10.1 [--check] [--install-deps] [--password | --batch]\nSupports the documented ARMv7/OpenWrt25.12/br-lan192.168.10.0/24 setup.\n--check is read-only. Installing does not activate VPN routing.\nPassword fallback is automatic; --password forces a hidden password prompt. --batch disables prompts.');return;}
for(let i=0;i<args.length;i++){if(args[i]==='--host'){i++;continue;}assert(['--check','--install-deps','--password','--batch'].includes(args[i]),'Unknown option. Use --help for supported flags.');}
const host=args.includes('--host')?args[args.indexOf('--host')+1]:process.env.GALE_SSH_TARGET||'root@192.168.10.1';assert(/^root@[A-Za-z0-9][A-Za-z0-9.-]*$/.test(host||''),'Use --host root@hostname or root@IPv4');
const origin=process.env.GALE_ROUTER_URL||'http://'+host.slice(5);const url=new URL(origin);assert(['http:','https:'].includes(url.protocol)&&!url.username&&!url.password&&!url.search&&!url.hash&&url.pathname==='/','Invalid GALE_ROUTER_URL');
if(args.includes('--password')&&args.includes('--batch'))throw Error('Choose either --password or --batch.');
const transport=await connector(host,{auth:args.includes('--password')?'password':args.includes('--batch')?'batch':'auto'}),ssh=(command,input)=>transport.exec(command,input,300000);
try{
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
console.log((await ssh('sh',platform)).trim());
if(args.includes('--install-deps')&&!args.includes('--check')){
 const packages='ucode ucode-mod-fs ucode-mod-digest ucode-mod-socket ucode-mod-ubus ucode-mod-uci rpcd rpcd-mod-ucode uhttpd uhttpd-mod-ubus curl ca-bundle lua lyaml ip-full nftables-json kmod-nft-tproxy kmod-nft-socket unzip xray-core sing-box';
 console.log((await ssh('sh',`set -eu\nif command -v apk >/dev/null; then apk update; apk add ${packages}; else echo 'This installer expects apk on OpenWrt25.12.' >&2; exit 1; fi\n`)).trim());
}
console.log((await ssh('sh',`set -eu
for tool in curl lua ip nft tar sha256sum unzip timeout; do command -v "$tool" >/dev/null || { echo "Missing $tool; rerun with --install-deps or install documented dependencies." >&2; exit 1; }; done
ucode -e 'import {create} from "socket";import {sha256} from "digest";import {connect} from "ubus";if(type(create)!="function"||type(sha256)!="function"||type(connect)!="function")exit(1);'
lua -e 'require("lyaml")'
test -x /usr/bin/xray; test -x /usr/bin/sing-box
test -d /sys/module/nft_tproxy; test -d /sys/module/nft_socket
test "$(df -Pk /overlay | awk 'NR==2 {print $4}')" -ge 262144 || { echo 'At least256MiB free overlay is required.' >&2; exit 1; }
echo 'Dependencies passed. No routing changes applied.'
`)).trim());
if(args.includes('--check')){console.log('Read-only preflight complete. Run without --check to install/update Gale.');return;}
const configFiles='/etc/config/network /etc/config/firewall /etc/config/wireless /etc/config/dhcp /etc/config/dropbear /etc/config/uhttpd';const before=await ssh('sha256sum '+configFiles);
await ssh('sh',`set -eu
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
mkdirSync('.private',{recursive:true});await publishRelease({transport,target:host,routerUrl:url.origin,activate:true});
await ssh('sh',`set -eu
/etc/init.d/gale-core-recovery enable
/etc/init.d/gale-monitor enable
/etc/init.d/gale-monitor start
/usr/share/gale/install-scheduler
rm -f /etc/gale/install-pending
sync
`);
assert.equal(await ssh('sha256sum '+configFiles),before,'Standard configuration hashes changed; inspect before continuing.');
console.log('Installed: '+url.origin+'/gale/\nAll six standard configuration files unchanged. LuCI and SSH retained.\nImport your own subscription, configure managed cores in Core Manager, then explicitly connect.');

}finally{await transport.close();}
}
if(process.argv[1]&&pathToFileURL(resolve(process.argv[1])).href===import.meta.url)await install().catch(e=>{console.error("Installation failed: "+e.message);process.exitCode=1;});
