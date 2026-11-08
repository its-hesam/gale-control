import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';import {readFileSync,writeFileSync} from 'node:fs';
assert(process.argv.includes('--owner-approved'),'Requires explicit approval for the live core rollback acceptance');
function ssh(command,input){let r=spawnSync('ssh',['-o','BatchMode=yes','-o','ConnectTimeout=5','root@192.168.10.1',command],{input,encoding:'utf8',timeout:30000});assert.equal(r.status,0,'SSH_OPERATION_FAILED');return r.stdout;}
const stateScript=`import {readfile,stat} from 'fs';import {sha256} from 'digest';import {connect} from 'ubus';function canonical(v){if(type(v)=='object'){let o={};for(let k in sort(keys(v)))o[k]=canonical(v[k]);return o;}if(type(v)=='array')return map(v,canonical);return v;}let s=connect().call('gale-connection','status',{}),store=json(readfile('/etc/gale/state.json')),owned={};for(let id,p in store.profiles){let m={};for(let f in ['native_status','native_core','native_core_version','native_error','native_checked_at','enabled','last_test','last_performance','last_udp_test','handshake_status'])if(exists(p,f))m[f]=p[f];owned[id]=m;}print({metadata_hash:sha256(sprintf('%J',canonical(owned))),store_hash:sha256(sprintf('%J',canonical(json(readfile('/etc/gale/state.json'))))),registry_hash:sha256(readfile('/etc/gale/cores.json')),running:s.running,healthy:s.health?.ok,guard:s.routing?.persistent_guard_active,routing:s.routing?.active,checked_at:s.health?.checked_at,pending:!!stat('/etc/gale/core-upgrade.pending'),job:(()=>{try{return json(readfile('/tmp/gale-core-upgrade/job.json')||'null');}catch(e){return null;}})()});`;
const before=JSON.parse(ssh('ucode -',stateScript));assert(before.running&&before.healthy&&before.guard&&before.routing&&!before.pending);
ssh('cat >/tmp/gale-core-fault-watchdog',readFileSync('router/core-fault-watchdog'));ssh('chmod 700 /tmp/gale-core-fault-watchdog');
const privateBefore=JSON.parse(ssh('cat /etc/gale/state.json'));
writeFileSync('.private/core-fault-before.json',JSON.stringify({before,profiles:Object.fromEntries(Object.entries(privateBefore.profiles).map(([id,p])=>[id,Object.fromEntries(['native_status','native_core','native_core_version','native_error','native_checked_at','enabled','last_test','last_performance','last_udp_test','handshake_status'].filter(k=>k in p).map(k=>[k,p[k]]))]))}));
const began=Math.floor(Date.now()/1000);
ssh('sh',`set -eu
umask 077
mkdir -p /tmp/gale-core-upgrade
test ! -f /etc/gale/core-upgrade.pending
printf '{"id":"sing-box","version":"1.13.12"}\n' >/tmp/gale-core-upgrade/request.json
touch /tmp/gale-core-upgrade/fault-test.armed
nohup /tmp/gale-core-fault-watchdog </dev/null >/dev/null 2>&1 &
GALE_UPGRADE_FAULT=after_activation /usr/bin/ucode /usr/share/gale/core-upgrade-worker.uc </dev/null >/tmp/gale-core-upgrade/fault-test.log 2>&1 &
echo "$!" >/tmp/gale-core-upgrade/fault-test.pid
`);
let after=null;
for(let i=0;i<65;i++){await new Promise(r=>setTimeout(r,2000));try{after=JSON.parse(ssh('ucode -',stateScript));}catch{continue;}if(after.job?.state==='rolled_back'&&after.healthy&&after.checked_at>=began&&after.routing&&!after.pending)break;if(after.job?.state==='recovery_required')break;}
const privateAfter=JSON.parse(ssh('cat /etc/gale/state.json'));function canonical(v){if(Array.isArray(v))return v.map(canonical);if(v&&typeof v==='object')return Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])]));return v;}const changedProfileFields={};for(const [id,p] of Object.entries(privateBefore.profiles)){const q=privateAfter.profiles[id]||{};for(const f of new Set([...Object.keys(p),...Object.keys(q)]))if(JSON.stringify(canonical(p[f]))!==JSON.stringify(canonical(q[f])))changedProfileFields[f]=(changedProfileFields[f]||0)+1;}
const result={changed_profile_field_counts:changedProfileFields,scope:'real_core_activation_failure',injected_after_activation:true,rolled_back:after?.job?.state==='rolled_back',expected_error:after?.job?.error==='INJECTED_AFTER_ACTIVATION',registry_restored:after?.registry_hash===before.registry_hash,catalog_restored:after?.metadata_hash===before.metadata_hash,full_catalog_unchanged:after?.store_hash===before.store_hash,fresh_https:!!after?.healthy&&after.checked_at>=began,LAN_active:!!after?.routing,guard_active:!!after?.guard,pending:!!after?.pending};
writeFileSync('docs/core-fault-result.json',JSON.stringify(result,null,2));console.log(result);
if(result.rolled_back&&result.fresh_https&&!result.pending)ssh('rm -f /tmp/gale-core-upgrade/fault-test.armed');
assert(result.rolled_back&&result.expected_error&&result.registry_restored&&result.catalog_restored&&result.fresh_https&&result.LAN_active&&result.guard_active&&!result.pending,'LIVE_ROLLBACK_ACCEPTANCE_FAILED');
