import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
function ssh(command,input,timeout=15000){const r=spawnSync('ssh',['-o','BatchMode=yes','-o','ConnectTimeout=5','root@192.168.10.1',command],{input,encoding:'utf8',timeout,maxBuffer:1024*1024});assert.equal(r.status,0,r.stderr||'SSH_FAILED');return r.stdout;}
function call(object,method,args={}){const r=JSON.parse(ssh(`/usr/libexec/rpcd/${object} call ${method}`,JSON.stringify(args)));assert(!r.error,r.error);return r;}
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function healthy(mode,id,seconds=45){const end=Date.now()+seconds*1000;while(Date.now()<end){const s=call('gale-connection','status');if(s.operation?.state==='failed')throw Error(s.operation.error);if(s.running&&s.health?.ok&&s.active?.mode===mode&&(!id||s.active.profile_id===id)&&s.health.profile_id===s.active.profile_id&&s.health.checked_at>=s.active.started_at&&s.routing?.active)return s;await wait(2000);}throw Error('MODE_HEALTH_TIMEOUT');}
async function httpsBurst(count){const results=await Promise.allSettled(Array.from({length:count},async(_,i)=>{const r=await fetch(`https://www.gstatic.com/generate_204?gale_acceptance=${i}`,{headers:{Connection:'close'},signal:AbortSignal.timeout(12000)});assert.equal(r.status,204);await r.arrayBuffer();}));return {requested:count,passed:results.filter(x=>x.status==='fulfilled').length};}
const req=JSON.parse(ssh('cat /etc/gale/acceptance-stage/request.json'));
const primary=call('gale-profiles','benchmark',{id:req.primary});assert(primary.result?.ok,'PRIMARY_PREFLIGHT_FAILED');
const backup=call('gale-profiles','benchmark',{id:req.backup});assert(backup.result?.ok,'BACKUP_PREFLIGHT_FAILED');
const best=primary.result.latency_ms<=backup.result.latency_ms?req.primary:req.backup;
const policy=JSON.stringify({health_interval:5,probe_interval:30,min_hold:30,failures:2,improvement_percent:20});
const args={id:req.primary,pool:[req.primary,req.backup].join(','),pool_scope:'selected',auto_connect:true,lan:false,policy};
const report={started_at:new Date().toISOString(),scope:'all_LAN_IPv4_real_modes',best:null,failover:null,balanced:null,restored:false};
let armed=false;
try{
 ssh('sh',`set -eu
umask 077
root=/etc/gale/acceptance-stage
test ! -f "$root/armed"
for name in config.json binary active sidecars sidecar-1.json sidecar-2.json binary-1 binary-2; do
 if [ -f "/etc/gale/runtime/$name" ]; then cp "/etc/gale/runtime/$name" "$root/runtime/$name"; else rm -f "$root/runtime/$name"; fi
done
touch "$root/armed"
nohup /bin/sh -c 'sleep 300; /usr/share/gale/acceptance-restore' </dev/null >/dev/null 2>&1 &
`);armed=true;
 call('gale-connection','connect',{...args,mode:'best'});await healthy('best',best);report.best={initial_matches_fresh_measurements:true,...await httpsBurst(2)};console.log(JSON.stringify({phase:'best',result:report.best}));
 call('gale-connection','connect',{...args,mode:'failover'});await healthy('failover',req.primary);
 ssh('nft -f /etc/gale/acceptance-stage/block.nft');const begin=Date.now();
 await healthy('failover',req.backup,100);ssh('nft delete table inet gale_acceptance');report.failover={automatic_switch:true,observed_recovery_ms:Date.now()-begin,...await httpsBurst(2)};console.log(JSON.stringify({phase:'failover',result:report.failover}));
 call('gale-connection','connect',{...args,mode:'balanced'});await healthy('balanced',null,60);
 function stats(){const output=ssh('/usr/share/gale/managed/xray/26.9.30/core api statsquery --server=127.0.0.1:17894 -pattern outbound');const parsed=JSON.parse(output.slice(output.indexOf('{'))),totals={};for(const item of parsed.stat||[]){const m=/outbound>>>member-(\d)>>>/.exec(item.name);if(m)totals[m[1]]=(totals[m[1]]||0)+Number(item.value);}return totals;}
 const before=stats(),burst=await httpsBurst(12),after=stats();report.balanced={...burst,member_1_bytes_delta:(after['1']||0)-(before['1']||0),member_2_bytes_delta:(after['2']||0)-(before['2']||0),counter_scope:'includes_engine_observatory'};assert(report.balanced.member_1_bytes_delta>0&&report.balanced.member_2_bytes_delta>0,'MEMBER_TRAFFIC_NOT_OBSERVED');console.log(JSON.stringify({phase:'balanced',result:report.balanced}));
}catch(e){report.error=/^[A-Z0-9_]+$/.test(e.message)?e.message:'MODE_ACCEPTANCE_FAILED';console.log(JSON.stringify({phase:'failed',error:report.error}));}
finally{if(armed){ssh('/usr/share/gale/acceptance-restore',undefined,20000);await healthy(req.original.mode||'manual',req.original.profile_id,45);report.restored=true;report.restore_https=await httpsBurst(2);}report.finished_at=new Date().toISOString();writeFileSync('docs/mode-acceptance-result.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));}
if(report.error||!report.restored||report.balanced?.passed!==12)process.exitCode=1;
