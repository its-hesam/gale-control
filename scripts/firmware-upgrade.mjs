import {createInterface} from 'node:readline/promises';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';

export function firmwareStatus(board){
 const r=board.release||{},v=r.version||'unknown';
 if(r.distribution!=='OpenWrt')throw Error(`Unsupported firmware: ${r.distribution||'unknown'} ${v}. Official OpenWrt is required.`);
 if(r.revision?.includes('SNAPSHOT')||!/^[0-9]+\.[0-9]+\.[0-9]+$/.test(v))throw Error(`Unsupported firmware: ${v}. Install a stable OpenWrt 25.12.x release manually.`);
 if(/^25\.12\./.test(v))return 'supported';
 if(/^24\.10\./.test(v))return 'upgrade';
 throw Error(`Unsupported firmware: OpenWrt ${v}; required: 25.12.x. Automatic migration is available only from 24.10.x. Use the device-specific OpenWrt upgrade guide; newer releases are never downgraded.`);
}
export async function confirmFirmware(message){
 if(!process.stdin.isTTY||!process.stdout.isTTY)throw Error('Firmware upgrade requires an interactive terminal and explicit Y approval.');
 const rl=createInterface({input:process.stdin,output:process.stdout});
 try{return (await rl.question(message+'\nType Y to upgrade, or Enter to cancel: ')).trim()==='Y';}finally{rl.close();}
}
export async function ensureFirmware({transport,reconnect,check=false,batch=false,confirm=confirmFirmware,fetcher=fetch,sleep=ms=>new Promise(r=>setTimeout(r,ms)),saveBackup,attempts=60}){
 const board=JSON.parse(await transport.exec('ubus call system board'));
 const status=firmwareStatus(board);
 if(status==='supported')return transport;
 if(!board.board_name||!board.release.target)throw Error('Cannot identify the router board and target; automatic upgrade stopped.');
 const description=`OpenWrt ${board.release.version} is unsupported; Gale requires 25.12.x. Device: ${board.model||board.board_name} (${board.release.target}).`;
 console.log(description);
 if(check||batch)throw Error('Firmware upgrade was not performed. Run the installer interactively without --check or --batch to review the upgrade.');
 // Check every existing installer platform prerequisite before offering a flash.
 await transport.exec('sh',`set -eu
grep -q "DISTRIB_ARCH='arm_cortex-a7_neon-vfpv4'" /etc/openwrt_release
test "$(uci -q get network.lan.device)" = br-lan
ip=$(uci -q get network.lan.ipaddr)
case "$ip" in 192.168.10.1/24) ;; 192.168.10.1) test "$(uci -q get network.lan.netmask)" = 255.255.255.0 ;; *) echo 'Unsupported LAN; no firmware changes made.' >&2; exit 1 ;; esac
command -v sysupgrade >/dev/null
command -v base64 >/dev/null
test -x /etc/init.d/rpcd; test -x /etc/init.d/uhttpd; test -x /etc/init.d/firewall
test "$(df -Pk /overlay | awk 'NR==2 {print $4}')" -ge 262144 || { echo 'Gale needs at least 256MiB free overlay; no firmware changes made.' >&2; exit 1; }
`);
 const response=await fetcher('https://sysupgrade.openwrt.org/json/v1/overview.json',{signal:AbortSignal.timeout(30000)});
 if(!response.ok)throw Error('Cannot retrieve official OpenWrt release metadata; no upgrade performed.');
 const overview=await response.json(),branch=overview.branches?.['25.12'];
 const target=(overview.latest||[]).find(v=>/^25\.12\.\d+$/.test(v));
 if(!target||!branch?.enabled||branch.targets?.[board.release.target]!=='arm_cortex-a7_neon-vfpv4')throw Error('No supported official 25.12 release for this target; upgrade manually.');
 if(!await confirm(`${description}\nUpgrade to ${target} using official Attended Sysupgrade? Internet/Wi-Fi will disconnect during reboot. Keep power connected and use Ethernet. Configuration backup will be saved locally; automatic firmware rollback is NOT guaranteed. Installed packages must pass the official build checks.`))throw Error('Firmware upgrade cancelled. No changes made.');
 const backup=await transport.exec('sh',`set -eu
umask 077
sysupgrade -b /tmp/gale-pre-upgrade.tar.gz
base64 /tmp/gale-pre-upgrade.tar.gz
`);
 const data=Buffer.from(backup.replace(/\s/g,''),'base64');
 if(data.length<2||data[0]!==31||data[1]!==139)throw Error('Invalid configuration backup; upgrade stopped.');
 if(saveBackup)await saveBackup(data);else{mkdirSync('.private',{recursive:true});const path=resolve('.private',`openwrt-backup-${Date.now()}.tar.gz`);writeFileSync(path,data,{mode:0o600,flag:'wx'});console.log('Configuration backup: '+path);}
 console.log('Preparing and validating firmware with owut; this can take several minutes.');
 console.log(await transport.exec('sh',`set -eu
if ! command -v owut >/dev/null; then opkg update; opkg install owut; fi
owut download --version-to ${target} --image /tmp/gale-firmware.bin
owut verify --image /tmp/gale-firmware.bin
sysupgrade -T /tmp/gale-firmware.bin
`,1800000));
 // Only the validated image is flashed. Never use -F, -n or --force.
 await transport.exec('sh',`set -eu
command -v nohup >/dev/null
nohup sh -c 'sleep 3; sysupgrade /tmp/gale-firmware.bin' >/tmp/gale-firmware-upgrade.log 2>&1 </dev/null &
echo 'Firmware flash scheduled. Waiting for reboot...'
`);
 await transport.close();
 for(let i=0;i<attempts;i++){
  await sleep(10000);let next;
  try{next=await reconnect();const after=JSON.parse(await next.exec('ubus call system board'));if(firmwareStatus(after)==='supported'&&after.board_name===board.board_name&&after.release.target===board.release.target){console.log('Firmware upgrade verified. Continuing Gale installation.');return next;}}
  catch(e){if(next)await next.close();next=null;if(/HOST IDENTIFICATION HAS CHANGED|host key|fingerprint|cancelled/i.test(e.message))throw e;}
  if(next)await next.close();
 }
 throw Error('Router did not return with verified OpenWrt 25.12.x within 10 minutes. Check the router locally, then rerun installation. Do not repeat a flash blindly.');
}
