import assert from 'node:assert/strict';
let sequence=0;async function call(sid,obj,method,args={}){const r=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,obj,method,args]})});const b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
const sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:600})).ubus_rpc_session;
let started=false;
try{
 const before=await call(sid,'gale-connection','status');assert(!before.active,'requires idle connection');
 const profiles=(await call(sid,'gale-profiles','list')).profiles;
 const primary=profiles.find(p=>p.protocol==='ss'&&p.native_status==='passed'),backup=profiles.find(p=>p.protocol==='vmess'&&p.native_status==='passed');assert(primary&&backup);
 await call(sid,'gale-connection','connect',{id:primary.id,mode:'failover',pool:[primary.id,backup.id].join(','),auto_connect:false});started=true;
 let passed=false,last='';
 for(let i=0;i<150;i++){
  await new Promise(r=>setTimeout(r,2000));const s=await call(sid,'gale-connection','status');
  const phase=s.active?.profile_id===backup.id?'backup':s.active?'primary':s.operation?.state;
  if(phase!==last){console.log(JSON.stringify({phase,failures:s.health?.consecutive_failures??0}));last=phase}
  if(phase==='backup'&&s.running&&s.health?.ok){passed=true;console.log(JSON.stringify({real_failover_https:true,latency_ms:Math.round(s.health.latency_ms),network_routing_active:s.network_routing_active}));break}
  if(s.operation?.state==='failed')throw Error(s.operation.error);
 }
 assert(passed,'real failover not observed within test budget');
}finally{if(started)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy')}
