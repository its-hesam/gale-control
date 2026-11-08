import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
let sequence=0;async function call(sid,obj,method,args={}){const r=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,obj,method,args]})});const b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
const sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:180})).ubus_rpc_session;let started=false;
try{
 assert(!(await call(sid,'gale-connection','status')).active,'requires idle connection');
 const profiles=(await call(sid,'gale-profiles','list')).profiles.filter(p=>p.native_status==='passed'&&p.last_test?.ok).slice(0,2);assert.equal(profiles.length,2);
 await call(sid,'gale-connection','connect',{id:profiles[0].id,mode:'balanced',pool:profiles.map(p=>p.id).join(','),auto_connect:false});started=true;
 let healthy=false;for(let i=0;i<45;i++){await new Promise(r=>setTimeout(r,2000));const s=await call(sid,'gale-connection','status');if(s.operation?.state==='failed')throw Error(s.operation.error);if(s.running&&s.health?.ok){healthy=true;break}}assert(healthy,'balanced HTTPS did not pass');
 const script=`set -eu
for port in 17901 17902; do
 code=$(curl --disable --silent --proxy '' --noproxy '' --socks5-hostname 127.0.0.1:$port --proto '=https' --max-time 12 --output /dev/null --write-out '%{http_code}' https://www.gstatic.com/generate_204)
 test "$code" = 204
 echo "member HTTPS 204"
done
for number in 1 2 3 4; do
 code=$(curl --disable --silent --proxy '' --noproxy '' --socks5-hostname 127.0.0.1:17890 --proto '=https' --max-time 12 --output /dev/null --write-out '%{http_code}' https://www.gstatic.com/generate_204)
 test "$code" = 204
done
/usr/share/gale/managed/xray/26.9.30/core api statsquery --server=127.0.0.1:17894 -pattern 'outbound>>>member-'
`;
 const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','sh'],{input:script,encoding:'utf8',timeout:90000});assert.equal(r.status,0,r.stderr);const start=r.stdout.indexOf('{');const stats=JSON.parse(r.stdout.slice(start));
 for(const member of ['member-1','member-2'])assert(stats.stat.some(s=>s.name.includes(member)&&Number(s.value)>0),'missing member traffic');
 console.log(JSON.stringify({balanced_proxy_https:true,members_verified:2,dispatcher_https_requests:4,both_member_counters_positive:true,network_routing_active:false}));
}finally{if(started)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy')}
