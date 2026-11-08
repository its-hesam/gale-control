import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';import {writeFileSync} from 'node:fs';
assert(process.argv.includes('--owner-approved'),'Requires authorization for temporary routing changes.');
let serial=0,sid='';const delay=ms=>new Promise(r=>setTimeout(r,ms));
function ssh(command,input){let r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',command],{input,encoding:'utf8',timeout:25000});assert.equal(r.status,0,r.stderr||'SSH_FAILED');return r.stdout;}
async function rpc(object,method,args={}){let b=await(await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(15000),body:JSON.stringify({jsonrpc:'2.0',id:++serial,method:'call',params:[sid||'0'.repeat(32),object,method,args]})})).json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1];}
function publicIP(){let r=spawnSync('curl.exe',['-4','--silent','--show-error','--max-time','12','https://api.ipify.org'],{encoding:'utf8',timeout:14000});assert.equal(r.status,0,'HTTPS_EGRESS_FAILED');assert(/^\d+\.\d+\.\d+\.\d+$/.test(r.stdout.trim()),'BAD_EGRESS_RESPONSE');return r.stdout.trim();}
const wlan=spawnSync('netsh',['wlan','show','interfaces'],{encoding:'utf8'}).stdout;const band=/Band\s*:\s*2\.4 GHz/.test(wlan)?'2g':/Band\s*:\s*5 GHz/.test(wlan)?'5g':null;assert(band,'Requires a Windows Wi-Fi client on 2.4 or 5 GHz.');
sid=(await rpc('session','login',{username:'root',password:'',timeout:900})).ubus_rpc_session;let before=await rpc('gale-routing','status');assert(before.applied);assert(before.draft.default_action==='vpn'&&before.draft.rules.every(r=>r.action==='vpn'),'Test requires an all-VPN baseline.');
ssh('sh',`set -eu
umask 077
test ! -e /tmp/gale-smart-owner-test
mkdir /tmp/gale-smart-owner-test
cp /etc/gale/routing-draft.json /tmp/gale-smart-owner-test/draft
cp /etc/gale/routing-active.json /tmp/gale-smart-owner-test/active
cp /etc/gale/routing-test/rules.nft /tmp/gale-smart-owner-test/rules.nft
cp /usr/share/nftables.d/chain-pre/forward/40-gale-guard.nft /tmp/gale-smart-owner-test/forward.nft
cp /usr/share/nftables.d/chain-pre/input/40-gale-guard.nft /tmp/gale-smart-owner-test/input.nft
touch /tmp/gale-smart-owner-test/armed
`);
const restore=`#!/bin/sh
set -eu
root=/tmp/gale-smart-owner-test
test -e "$root/armed" || exit 0
cp "$root/forward.nft" /usr/share/nftables.d/chain-pre/forward/40-gale-guard.nft
cp "$root/input.nft" /usr/share/nftables.d/chain-pre/input/40-gale-guard.nft
/sbin/fw4 reload >/dev/null
{ printf 'delete table inet gale_preview\\n'; cat "$root/rules.nft"; } >"$root/restore.nft"
nft -f "$root/restore.nft"
cp "$root/draft" /etc/gale/routing-draft.json
cp "$root/active" /etc/gale/routing-active.json
cp "$root/active" /etc/gale/routing-test/draft.json
cp "$root/rules.nft" /etc/gale/routing-test/rules.nft
rm "$root/armed"
`;
ssh('cat >/tmp/gale-smart-owner-test/restore',restore);ssh("nohup sh -c 'sleep 120; sh /tmp/gale-smart-owner-test/restore' </dev/null >/dev/null 2>&1 &");
async function apply(wifi){await rpc('gale-routing','save_draft',{default_action:'vpn',rules:'[]',wifi:JSON.stringify(wifi),iran_direct:false});let s=await rpc('gale-routing','status');await rpc('gale-routing','apply_draft',{confirmed:true,revision:s.draft_revision});for(let i=0;i<30;i++){await delay(1000);s=await rpc('gale-routing','status');if(s.operation?.state==='applied')return;assert(!['failed','interrupted'].includes(s.operation?.state),s.operation?.error);}throw Error('POLICY_TIMEOUT');}
let report={client_band:band,watchdog_seconds:120};try{let baseline=publicIP();await apply({'2g':band==='2g'?'direct':'vpn','5g':band==='5g'?'direct':'vpn'});assert.notEqual(publicIP(),baseline,'DIRECT_EGRESS_UNCHANGED');report.physical_WiFi_direct_egress_proven=true;assert.equal(ssh('echo ok').trim(),'ok');report.SSH_retained=true;await apply({'2g':'vpn','5g':'vpn'});assert.equal(publicIP(),baseline,'VPN_EGRESS_NOT_RESTORED');report.physical_WiFi_VPN_egress_proven=true;}finally{ssh('sh /tmp/gale-smart-owner-test/restore');report.original_policy_restored=true;assert((await rpc('gale-connection','status')).routing.active);writeFileSync('docs/smart-policy-live.json',JSON.stringify(report,null,2));console.log(report);}
