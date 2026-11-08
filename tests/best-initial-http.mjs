import assert from 'node:assert/strict';
let n=0;async function call(sid,obj,method,args={}){const r=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++n,method:'call',params:[sid,obj,method,args]})});const b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
const sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:300})).ubus_rpc_session;let started=false;
try{
 assert(!(await call(sid,'gale-connection','status')).active,'requires idle connection');
 let catalog=await call(sid,'gale-profiles','list');
 function fresh(c){return c.profiles.filter(p=>p.native_status==='passed'&&p.last_test?.ok&&c.observed_at-p.last_test.tested_at>=0&&c.observed_at-p.last_test.tested_at<=900).sort((a,b)=>a.last_test.latency_ms-b.last_test.latency_ms)}
 let candidates=fresh(catalog);
 if(candidates.length<2){for(const p of catalog.profiles.filter(p=>p.native_status==='passed'&&p.last_test?.ok).slice(0,6)){await call(sid,'gale-jobs','start',{kind:'benchmark',id:p.id,limit:1});let finished=false;for(let i=0;i<20;i++){await new Promise(r=>setTimeout(r,1000));let j=(await call(sid,'gale-jobs','status')).job;if(j.state==='complete'){finished=true;break}}assert(finished);catalog=await call(sid,'gale-profiles','list');candidates=fresh(catalog);if(candidates.length>=2)break}}
 assert(candidates.length>=2,'two fresh measured candidates unavailable');let best=candidates[0],other=candidates.at(-1);
 await call(sid,'gale-connection','connect',{id:other.id,mode:'best',pool:other.id+','+best.id,auto_connect:false});started=true;let passed=false;
 for(let i=0;i<40;i++){await new Promise(r=>setTimeout(r,1000));let s=await call(sid,'gale-connection','status');if(s.operation?.state==='failed')throw Error(s.operation.error);if(s.active&&s.running&&s.health?.ok){assert.equal(s.active.profile_id,best.id,'best mode did not select lowest fresh latency');passed=true;console.log(JSON.stringify({automatic_initial_best_selection:true,https_verified:true,latency_ms:Math.round(s.health.latency_ms),network_routing_active:s.network_routing_active}));break}}
 assert(passed,'best mode HTTPS not verified');
}finally{if(started)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy')}
